package com.example.validator;

import java.io.File;
import java.io.FileInputStream;
import java.io.InputStream;
import java.io.IOException;
import java.nio.file.Files;
import java.time.format.DateTimeFormatter;
import java.time.LocalDateTime;
import java.util.LinkedHashMap;
import java.util.Map;
import java.util.Properties;
import java.util.logging.*;

public class ValidatorMain {

    private static Logger logger;

    public static void main(String[] args) {
        if (args.length < 1) {
            System.err.println("Usage: java -jar validator.jar <path/to/validator.properties>");
            System.exit(2);
        }

        String propPath = args[0];
        Properties props = new Properties();
        try (InputStream in = new FileInputStream(propPath)) {
            props.load(in);
            System.out.println("Loaded properties from: " + propPath);
        } catch (IOException e) {
            System.err.println("Failed to load properties file: " + e.getMessage());
            System.exit(2);
        }

        // Determine logging destination.
        // Preferred: log.dir -> create timestamped file inside this dir
        // Fallback: log.file -> use exact path
        // Final fallback: ./logs with timestamped filename
        String logDirProp = props.getProperty("log.dir", null);
        String logFileProp = props.getProperty("log.file", null);

        File logFile = null;
        if (logDirProp != null && !logDirProp.trim().isEmpty()) {
            File logDir = new File(logDirProp);
            if (!logDir.exists()) {
                try {
                    Files.createDirectories(logDir.toPath());
                } catch (IOException ex) {
                    System.err.println("Failed to create log directory: " + ex.getMessage());
                    // fallback to other options
                    logDir = null;
                }
            }
            if (logDirProp != null) {
                String timestamp = LocalDateTime.now().format(DateTimeFormatter.ofPattern("yyyyMMdd_HHmmss"));
                logFile = new File(logDirProp, "validator_" + timestamp + ".log");
            }
        }

        if (logFile == null && logFileProp != null && !logFileProp.trim().isEmpty()) {
            logFile = new File(logFileProp);
            File parent = logFile.getParentFile();
            if (parent != null && !parent.exists()) {
                try {
                    Files.createDirectories(parent.toPath());
                } catch (IOException ex) {
                    System.err.println("Failed to create parent directory for log.file: " + ex.getMessage());
                }
            }
        }

        if (logFile == null) {
            // final fallback to ./logs with timestamp
            String timestamp = LocalDateTime.now().format(DateTimeFormatter.ofPattern("yyyyMMdd_HHmmss"));
            File fallbackDir = new File("./logs");
            if (!fallbackDir.exists()) {
                try {
                    Files.createDirectories(fallbackDir.toPath());
                } catch (IOException ex) {
                    // ignore
                }
            }
            logFile = new File(fallbackDir, "validator_" + timestamp + ".log");
        }

        try {
            setupLogger(logFile);
            logger.info("Validation started; properties: " + propPath);
        } catch (IOException ex) {
            System.err.println("Failed to setup file logger: " + ex.getMessage());
            // fallback to console logger
            setupConsoleLogger();
            logger = Logger.getLogger("MFVTValidator");
            logger.severe("Proceeding with console-only logging because file logger failed.");
        }

        logger.info("Logging to: " + logFile.getAbsolutePath());

        // Known entity property keys (ordered)
        Map<String, String> entities = new LinkedHashMap<>();
        entities.put("marcBib", "marcBib");
        entities.put("marcHolding", "marcHolding");
        entities.put("items", "items");
        entities.put("patrons", "patrons");
        entities.put("loans", "loans");
        entities.put("vendors", "vendors");

        boolean anyFailure = false;

        for (Map.Entry<String, String> e : entities.entrySet()) {
            String entityName = e.getKey();
            String propKey = e.getValue();
            String path = props.getProperty(propKey, "").trim();
            if (path == null || path.isEmpty()) {
                logger.warning("No input configured for entity '" + entityName + "' (property: " + propKey + "). Skipping.");
                continue;
            }
            logger.info("Validating entity '" + entityName + "' using file: " + path);
            boolean ok = validateEntity(entityName, path, props);
            if (ok) {
                logger.info("Validation PASSED for entity: " + entityName);
            } else {
                logger.severe("Validation FAILED for entity: " + entityName);
                anyFailure = true;
            }
        }

        logger.info("Full validation finished. Any failures: " + anyFailure);
        System.exit(anyFailure ? 1 : 0);
    }

    private static void setupLogger(File logFile) throws IOException {
        logger = Logger.getLogger("MFVTValidator");
        logger.setUseParentHandlers(false);

        // Remove existing handlers
        Handler[] old = logger.getHandlers();
        for (Handler h : old) {
            logger.removeHandler(h);
        }

        // File handler (append)
        FileHandler fh = new FileHandler(logFile.getAbsolutePath(), true);
        fh.setFormatter(new SimpleFormatter());
        fh.setLevel(Level.ALL);
        logger.addHandler(fh);

        // Console handler for operator visibility
        ConsoleHandler ch = new ConsoleHandler();
        ch.setLevel(Level.INFO);
        logger.addHandler(ch);

        logger.setLevel(Level.INFO);
    }

    private static void setupConsoleLogger() {
        logger = Logger.getLogger("MFVTValidator");
        logger.setUseParentHandlers(false);
        for (Handler h : logger.getHandlers()) logger.removeHandler(h);
        ConsoleHandler ch = new ConsoleHandler();
        ch.setLevel(Level.INFO);
        logger.addHandler(ch);
        logger.setLevel(Level.INFO);
    }

    /**
     * Replace this stub with your real validation logic.
     * Return true for success, false for failure.
     */
    private static boolean validateEntity(String entityName, String filePath, Properties props) {
        logger.info("Starting validation for " + entityName + " with file " + filePath);
        File f = new File(filePath);
        if (!f.exists()) {
            logger.severe("Input file does not exist: " + filePath);
            return false;
        }

        try {
            // TODO: integrate your validation classes here, e.g.:
            // MyValidator validator = new MyValidator(props);
            // ValidationResult result = validator.validateEntity(entityName, filePath);
            // logger.info(result.summary());
            // return result.isSuccess();

            // Placeholder behavior (simulate work)
            Thread.sleep(200); // simulate processing
            logger.fine("Placeholder checks done for " + entityName);
            return true;
        } catch (InterruptedException ex) {
            logger.severe("Validation interrupted for " + entityName + ": " + ex.getMessage());
            Thread.currentThread().interrupt();
            return false;
        } catch (Exception ex) {
            logger.severe("Unexpected error validating " + entityName + ": " + ex.toString());
            return false;
        }
    }
}
