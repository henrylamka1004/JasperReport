create or replace procedure SP_DWH_HOUSEKEEP_PARTITION
is
tableName  varchar2(100);
dateColumn  varchar2(20);
functionType  number;
dateformat varchar2(20);
dateType number;

temptableName varchar2(100);
histtableName  varchar2(100);
oactivePartition varchar2(20);
nactivePartition varchar2(20);
countPartition varchar2(20);
ohistPartition varchar2(20);
nhistPartition varchar2(20);
validPartition varchar2(20);
last_date date;
next_date varchar2(100);
now_date varchar2(100);

str_sql varchar2(1000);
str_currentTime varchar2(10);

v_sql varchar2(4000);
count_sql varchar2(1000);
query_sql varchar2(4000);

str_release_date varchar2(20);
str_min_date varchar2(100);

log_sql varchar2(4000);
start_time date;
end_time date;
seq_id number(12);
duration_min varchar2(200);
delete_record_count number:=0;
remark_detail varchar2(1000):=null;
min_date_int number;
data_min_date varchar2(50):=null;
run_status varchar2(20):='running';
housekeep_indicator varchar2(1);
date_release_date date;

total_del_row number := 0;

BEGIN
	-- read the config file.
	declare cursor get_param is select table_name,date_col,date_format,date_type,housekeep_indicator from dwh_housekeep_partition_config order by table_id;
	BEGIN
		open get_param;
		LOOP
			BEGIN
				fetch get_param into tableName,dateColumn,dateformat,dateType,housekeep_indicator;
				EXIT WHEN get_param%notfound;
				dateformat:=upper(dateformat);
				if housekeep_indicator='Y' then
					BEGIN
						select REPLACE(PARTITION_NAME,'YR_','') INTO countPartition
						from user_tab_partitions 
						where table_name=tableName and partition_position = (select MAX(PARTITION_POSITION)-1 from user_tab_partitions where table_name=tableName);
						select to_char(sysdate,'YYYYMM') INTO now_date from dual;
						
						WHILE (TO_NUMBER(countPartition) - TO_NUMBER(now_date)) < 2
						LOOP
							select TO_DATE(REPLACE(PARTITION_NAME,'YR_',''),'YYYYMM') INTO last_date
							from user_tab_partitions 
							where table_name=tableName and partition_position = (select MAX(PARTITION_POSITION)-1 from user_tab_partitions where table_name=tableName);
							select TO_CHAR(TRUNC(ADD_MONTHS(last_date, 2),'MM'),'YYYYMMDD') INTO next_date from dual;
							SELECT 'YR_' || TO_CHAR(TRUNC(ADD_MONTHS(last_date, 1),'MM'),'YYYYMM') INTO nactivePartition FROM DUAL;
								
							if dateType=0 then
								query_sql := 'ALTER TABLE ' || tableName || ' SPLIT PARTITION YR_ALL AT (' ||next_date|| ') INTO (PARTITION ' ||nactivePartition|| ' , PARTITION YR_ALL)';
								execute immediate query_sql;
							elsif dateType=1 then
								query_sql := 'ALTER TABLE ' || tableName || ' SPLIT PARTITION YR_ALL AT (TO_DATE(' || next_date || ',''YYYYMMDD'')) INTO (PARTITION ' ||nactivePartition|| ' , PARTITION YR_ALL)';
								execute immediate query_sql;
							elsif dateType=2 then
								query_sql := 'ALTER TABLE ' || tableName || ' SPLIT PARTITION YR_ALL AT (' || next_date || ') INTO (PARTITION ' ||nactivePartition|| ' , PARTITION YR_ALL)';
								execute immediate query_sql;
							end if;
							
								
							select REPLACE(PARTITION_NAME,'YR_','') INTO countPartition
							from user_tab_partitions 
							where table_name=tableName and partition_position = (select MAX(PARTITION_POSITION)-1 from user_tab_partitions where table_name=tableName);
						END LOOP;
					END;
				END IF;
			END;
		END LOOP;
		close get_param;
	END;
	declare cursor get_param is select table_name,date_col,date_format,date_type,housekeep_indicator from dwh_housekeep_partition_config order by table_id;
	BEGIN
		open get_param;
		LOOP
			BEGIN
				fetch get_param into tableName,dateColumn,dateformat,dateType,housekeep_indicator;
				EXIT WHEN get_param%notfound;
				dateformat:=upper(dateformat);
				if housekeep_indicator='Y' then
				BEGIN
					run_status:='running';
					start_time:=sysdate;
					execute immediate 'select seq_housekeep_partition_log.nextval from dual' into seq_id;
					log_sql:='insert into DWH_housekeep_partition_log(seq,table_name,start_time,run_status) values ('||seq_id||','''||tableName||''',to_date('''||to_char(start_time,'yyyy-MM-dd hh24:mi:ss')||''',''yyyy-MM-dd hh24:mi:ss''), ''' || run_status || ''')';
					execute immediate log_sql;
					commit;
						
					select to_char(sysdate,'YYYYMM') INTO now_date from dual;
						
					select REPLACE(PARTITION_NAME,'YR_','') INTO validPartition
					from user_tab_partitions 
					where table_name=tableName and partition_position = 1;
					
					SELECT HIST_TABLE_NAME INTO histtableName
					FROM HIST_NEW_TAB_NAME_CONFIG
					WHERE NEW_TABLE_NAME=tableName;
				
					SELECT TEM_TABLE_NAME INTO temptableName
					FROM HIST_NEW_TAB_NAME_CONFIG
					WHERE NEW_TABLE_NAME=tableName;
					
					if MONTHS_BETWEEN(TO_DATE(now_date,'YYYYMM'),TO_DATE(validPartition)) > 36 then
						while MONTHS_BETWEEN(TO_DATE(now_date,'YYYYMM'),TO_DATE(validPartition)) <= 36
						LOOP		
							SELECT PARTITION_NAME INTO oactivePartition
							FROM USER_TAB_PARTITIONS 
							WHERE TABLE_NAME=tableName AND PARTITION_POSITION=1;
							
							SELECT PARTITION_NAME INTO ohistPartition
							FROM USER_TAB_PARTITIONS 
							WHERE TABLE_NAME=histtableName AND PARTITION_POSITION=1;
													
							str_sql := 'select min(' || dateColumn ||') from ' || histtableName || ' partition('|| ohistPartition ||')';
							execute immediate str_sql into str_min_date;
							if str_min_date is not null then
								data_min_date := str_min_date;
							else
								data_min_date:=null;
							end if;
							select TO_DATE(REPLACE(oactivePartition,'YR_',''),'YYYYMM') INTO last_date FROM DUAL;
							select TO_CHAR(TRUNC(ADD_MONTHS(last_date, 1),'MM'),'YYYYMMDD') INTO next_date from dual;
							
							--split and drop
							if dateType=0 then
								query_sql := 'ALTER TABLE ' || histtableName || ' SPLIT PARTITION YR_ALL AT (' || next_date|| ') INTO (PARTITION ' ||oactivePartition|| ' , PARTITION YR_ALL)';
								execute immediate query_sql;
							elsif dateType=1 then
								query_sql := 'ALTER TABLE ' || histtableName || ' SPLIT PARTITION YR_ALL AT (TO_DATE(' || next_date || ',''YYYYMMDD'')) INTO (PARTITION ' ||oactivePartition|| ' , PARTITION YR_ALL)';
								execute immediate query_sql;
							elsif dateType=2 then
								query_sql := 'ALTER TABLE ' || histtableName || ' SPLIT PARTITION YR_ALL AT (' || next_date || ') INTO (PARTITION ' ||oactivePartition|| ' , PARTITION YR_ALL)';
								execute immediate query_sql;
							end if;
	
							query_sql := 'ALTER TABLE ' || tableName|| ' EXCHANGE PARTITION ' || oactivePartition ||' WITH TABLE ' || temptableName ||' WITHOUT VALIDATION';
							execute immediate query_sql;
							query_sql := 'ALTER TABLE ' || histtableName|| ' EXCHANGE PARTITION ' || oactivePartition ||' WITH TABLE ' || temptableName ||' WITHOUT VALIDATION';
							execute immediate query_sql;
							query_sql := 'ALTER TABLE ' || tableName || ' DROP PARTITION ' || oactivePartition;
							execute immediate query_sql;
							
							IF LENGTH(REPLACE(ohistPartition,'YR_','')) = 4 then
								if substr(oactivePartition, -2) = '12' then
									count_sql := 'SELECT COUNT(1) FROM ' || histtableName || ' PARTITION(' || ohistPartition || ')';
									execute immediate count_sql into delete_record_count;
									query_sql := 'ALTER table ' || histtableName || ' drop partition ' || ohistPartition;
									execute immediate query_sql;
								else
									null;
								end if;
							elsif LENGTH(REPLACE(ohistPartition,'YR_','')) = 6 then
								count_sql := 'SELECT COUNT(1) FROM ' || histtableName || ' PARTITION(' || ohistPartition || ')';
								execute immediate count_sql into delete_record_count;
								query_sql := 'ALTER table ' || histtableName || ' drop partition ' || ohistPartition;
								execute immediate query_sql;
							else
								null;
							end if;
							
							FOR i IN(
							select INDEX_NAME 
							FROM DBA_INDEXES WHERE table_name = histtableName
							)
							LOOP
								query_sql := 'ALTER INDEX ' || i.INDEX_NAME || ' REBUILD PARTITION ' || oactivePartition;
								execute immediate query_sql;
								query_sql := 'ALTER INDEX ' || i.INDEX_NAME || ' REBUILD PARTITION YR_ALL';
								execute immediate query_sql;
							END LOOP;
						END LOOP;
						
						select TO_DATE(REPLACE(PARTITION_NAME,'YR_',''),'YYYYMM') INTO last_date
						from user_tab_partitions 
						where table_name=tableName and partition_position = (select MAX(PARTITION_POSITION)-3 from user_tab_partitions where table_name=tableName);
						SELECT 'YR_' || TO_CHAR(TRUNC(ADD_MONTHS(last_date, 1),'MM'),'YYYYMM') INTO nactivePartition FROM DUAL;
						
						
						FOR i IN(
							select INDEX_NAME 
							FROM DBA_INDEXES WHERE table_name = tableName
						)
						LOOP
							query_sql := 'ALTER INDEX ' || i.INDEX_NAME || ' REBUILD PARTITION ' || nactivePartition;
							execute immediate query_sql;
							dbms_stats.gather_index_stats(ownname => 'BOCIPRD',indname =>i.INDEX_NAME,granularity=>'partition',partname=>nactivePartition);
						END LOOP;
						dbms_stats.gather_table_stats(ownname => 'BOCIPRD',tabname => tableName, granularity=>'partition',partname=>nactivePartition);
						
						select TO_DATE(REPLACE(PARTITION_NAME,'YR_',''),'YYYYMM') INTO last_date
						from user_tab_partitions 
						where table_name=tableName and partition_position = (select MAX(PARTITION_POSITION)-2 from user_tab_partitions where table_name=tableName);
						SELECT 'YR_' || TO_CHAR(TRUNC(ADD_MONTHS(last_date, 1),'MM'),'YYYYMM') INTO nactivePartition FROM DUAL;
						
						FOR i IN(
							select INDEX_NAME 
							FROM DBA_INDEXES WHERE table_name = tableName
						)
						LOOP
							query_sql := 'ALTER INDEX ' || i.INDEX_NAME || ' REBUILD PARTITION ' || nactivePartition;
							execute immediate query_sql;
							dbms_stats.gather_index_stats(ownname => 'BOCIPRD',indname =>i.INDEX_NAME,granularity=>'partition',partname=>nactivePartition);
						END LOOP;
						dbms_stats.gather_table_stats(ownname => 'BOCIPRD',tabname => tableName, granularity=>'partition',partname=>nactivePartition);
						
						select TO_DATE(REPLACE(PARTITION_NAME,'YR_',''),'YYYYMM') INTO last_date
						from user_tab_partitions 
						where table_name=tableName and partition_position = (select MAX(PARTITION_POSITION)-1 from user_tab_partitions where table_name=tableName);
						SELECT 'YR_' || TO_CHAR(TRUNC(ADD_MONTHS(last_date, 1),'MM'),'YYYYMM') INTO nactivePartition FROM DUAL;
						
						FOR i IN(
							select INDEX_NAME 
							FROM DBA_INDEXES WHERE table_name = tableName
						)
						LOOP
							query_sql := 'ALTER INDEX ' || i.INDEX_NAME || ' REBUILD PARTITION ' || nactivePartition;
							execute immediate query_sql;
							query_sql := 'ALTER INDEX ' || i.INDEX_NAME || ' REBUILD PARTITION YR_ALL';
							execute immediate query_sql;
							dbms_stats.gather_index_stats(ownname => 'BOCIPRD',indname =>i.INDEX_NAME,granularity=>'partition',partname=>nactivePartition);
							dbms_stats.gather_index_stats(ownname => 'BOCIPRD',indname =>i.INDEX_NAME,granularity=>'partition',partname=>'YR_ALL');
						END LOOP;
						dbms_stats.gather_table_stats(ownname => 'BOCIPRD',tabname => tableName, granularity=>'partition',partname=>nactivePartition);
						dbms_stats.gather_table_stats(ownname => 'BOCIPRD',tabname => tableName, granularity=>'partition',partname=>'YR_ALL');
						
						select TO_DATE(REPLACE(PARTITION_NAME,'YR_',''),'YYYYMM') INTO last_date
						from user_tab_partitions 
						where table_name=tableName and partition_position = (select MAX(PARTITION_POSITION)-1 from user_tab_partitions where table_name=histtableName);

					end if;
					run_status:='finished';
					remark_detail := null;
					exception when others then
						remark_detail:=SUBSTR(SQLERRM,1,1000);
						run_status:='failed';
					END;
					
					end_time:=sysdate;
					duration_min:=round(to_number((end_time-start_time)*24*60),2)||'';
					if instr(duration_min,'.',1,1)=1 then
						duration_min:='0'||duration_min;
					end if;
					log_sql:='update DWH_housekeep_partition_log set run_status = ''' || run_status ||''' ,del_duration_min='''||duration_min||''',delete_record_count='|| delete_record_count ||',data_min_date='''||data_min_date||''',end_time=to_date('''||to_char(end_time,'yyyy-MM-dd hh24:mi:ss')||''',''yyyy-MM-dd hh24:mi:ss'') where seq='||seq_id||'';
					execute immediate log_sql;
					UPDATE DWH_housekeep_partition_log set remark=remark_detail where seq=seq_id;
					commit;
				end if;
        
			END;			
		END LOOP;
		close get_param;
	END;
END;