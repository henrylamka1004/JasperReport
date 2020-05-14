/*
 * To change this license header, choose License Headers in Project Properties.
 * To change this template file, choose Tools | Templates
 * and open the template in the editor.
 */

import java.io.*;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.SQLException;
import java.util.*;
import net.sf.jasperreports.engine.JRDataSource;
import net.sf.jasperreports.engine.JREmptyDataSource;
import net.sf.jasperreports.engine.JRException;
import net.sf.jasperreports.engine.JasperCompileManager;
import net.sf.jasperreports.engine.JasperFillManager;
import net.sf.jasperreports.engine.JasperPrint;
import net.sf.jasperreports.engine.JasperReport;
import net.sf.jasperreports.engine.design.JasperDesign;
import net.sf.jasperreports.engine.export.JRCsvExporter;
import net.sf.jasperreports.engine.export.JRPdfExporter;
import net.sf.jasperreports.engine.xml.JRXmlLoader;
import net.sf.jasperreports.export.SimpleExporterInput;
import net.sf.jasperreports.export.SimpleOutputStreamExporterOutput;
import net.sf.jasperreports.export.SimpleWriterExporterOutput;
import net.sf.jasperreports.view.JasperViewer;


public class Demotest {

    /**
     * @param args the command line arguments
     */
    static Properties readconfig(String configpath) throws FileNotFoundException, IOException{
        FileReader reader = new FileReader(configpath);
        Properties p = new Properties();
        p.load(reader);
        reader.close();
        System.out.println(p);
        System.out.println("FINISH READING CONFIG");
        return p;
    }
        
    static Connection connection(String driver_url, String db_url, String db_username, String db_pwd){
        Connection con = null;
        try{
            System.out.println("TRY TO CONNECT DB");
            Class.forName(driver_url);
            con = DriverManager.getConnection(db_url,db_username,db_pwd);
            System.out.println("DB CONNECTED");     
        }
        
        catch(ClassNotFoundException | SQLException ex){
            System.out.println(ex.getMessage());
            System.out.println("FAIL TO CONNECT DB");
        }
        return con;
    }      
    
    static void pdf(JasperPrint jasperPrint, String path) throws JRException{
        JRPdfExporter exporter = new JRPdfExporter();
        exporter.setExporterInput(new SimpleExporterInput(jasperPrint));
        exporter.setExporterOutput(new SimpleOutputStreamExporterOutput(path));
        exporter.exportReport();
        System.out.println("PDF created");
    }
    static void csv(JasperPrint jasperPrint, String path) throws JRException{
        JRCsvExporter exporter = new JRCsvExporter();
        exporter.setExporterInput(new SimpleExporterInput(jasperPrint));
        exporter.setExporterOutput(new SimpleWriterExporterOutput(path));
        exporter.exportReport();
        System.out.println("CSV created");
    }
    

    public static void main(String[] args) throws JRException, IOException {
        
        Properties p = readconfig("config.properties");
        
        String JRXML_file = p.getProperty("FILE_NAME") + ".jrxml";
        Path JRXML_PATH = Paths.get(p.getProperty("PATH")).resolve(JRXML_file);
        String output_file = p.getProperty("FILE_NAME") + "." + p.getProperty("OUTPUTFILE_FORMAT");
        Path output_PATH = Paths.get(p.getProperty("PATH")).resolve(output_file);
        System.out.println(output_file);
        System.out.println(JRXML_PATH);
        
        InputStream input = new FileInputStream(new File(JRXML_PATH.toString()));
        JasperDesign jasperDesign = JRXmlLoader.load(input);
        JasperReport jasperReport = JasperCompileManager.compileReport(jasperDesign);
        
        
        if(p.getProperty("DRIVER_URL").isEmpty()){                  
            JRDataSource jrDataSource = new JREmptyDataSource();
//            List<FillData> listItems = new ArrayList<FillData>();
//            FillData data1 = new FillData();
//            FillData data2 = new FillData();
//            FillData data3 = new FillData();
//            data1.setid(1);data1.setfreight("aaa");data1.setaddress("aaa");
//            data2.setid(2);data2.setfreight("bbb");data2.setaddress("bbb");
//            data3.setid(3);data3.setfreight("ccc");data3.setaddress("ccc");
//            listItems.add(data1);listItems.add(data2);listItems.add(data3);
//            JRBeanCollectionDataSource itemsJRBean = new JRBeanCollectionDataSource(listItems);
//            Map<String, Object> parameters = new HashMap<String, Object>();
//            parameters.put("Parameter1", itemsJRBean);
            
            JasperPrint jasperPrint = JasperFillManager.fillReport(jasperReport, null, jrDataSource);
//            JasperViewer.viewReport(jasperPrint);
            if(output_file.contains(".pdf")){pdf(jasperPrint, output_PATH.toString());
            } else csv(jasperPrint, output_PATH.toString());
          
            
        } else{
            Connection con = connection(p.getProperty("DRIVER_URL"), p.getProperty("DB_URL"), p.getProperty("DB_USERNAME"), p.getProperty("DB_PWD"));
            JasperPrint jasperPrint = JasperFillManager.fillReport(jasperReport, null, con);
            if(output_file.contains(".pdf")){pdf(jasperPrint, output_PATH.toString());
            } else csv(jasperPrint, output_PATH.toString());
        }
        
        // TODO code application logic here
    }
    
}
