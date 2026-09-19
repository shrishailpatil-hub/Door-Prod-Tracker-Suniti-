package com.doorworkflow.config;

import com.google.auth.oauth2.GoogleCredentials;
import com.google.firebase.FirebaseApp;
import com.google.firebase.FirebaseOptions;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

import java.io.IOException;
import java.io.InputStream;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;

/**
 * Configures the Firebase Admin SDK.
 *
 * The service‑account credentials are loaded from the file path supplied in the
 * {@code FIREBASE_SERVICE_ACCOUNT_PATH} environment variable. This allows the
 * credentials to be mounted at runtime (e.g., as a secret volume in a container)
 * without bundling them into the JAR.
 *
 * If the variable is not set or the file cannot be read, the bean returns
 * {@code null} and push notifications are disabled – the application still starts
 * normally.
 */
@Configuration
public class FirebaseConfig {
    private static final Logger log = LoggerFactory.getLogger(FirebaseConfig.class);

    @Bean
    public FirebaseApp firebaseApp() {
        String credentialPath = System.getenv("FIREBASE_SERVICE_ACCOUNT_PATH");
        if (credentialPath == null || credentialPath.isBlank()) {
            log.warn("Environment variable FIREBASE_SERVICE_ACCOUNT_PATH is not set; Firebase messaging disabled.");
            return null;
        }
        Path path = Paths.get(credentialPath);
        if (!Files.isRegularFile(path) || !Files.isReadable(path)) {
            log.warn("Firebase service account file not found or unreadable at '{}' ; Firebase messaging disabled.", credentialPath);
            return null;
        }
        try (InputStream serviceAccount = Files.newInputStream(path)) {
            GoogleCredentials credentials = GoogleCredentials.fromStream(serviceAccount);
            FirebaseOptions options = FirebaseOptions.builder()
                    .setCredentials(credentials)
                    .build();
            return FirebaseApp.initializeApp(options);
        } catch (IOException e) {
            log.error("Failed to initialize FirebaseApp from path '{}'", credentialPath, e);
            return null;
        }
    }
}
