package com.doorworkflow.config;

import com.doorworkflow.entity.User;
import com.doorworkflow.enums.UserRole;
import com.doorworkflow.repository.UserRepository;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.event.EventListener;
import org.springframework.context.annotation.Profile;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Component;
import org.springframework.boot.context.event.ApplicationReadyEvent;

/**
 * Seeds a development admin user if it does not already exist.
 * This component is active only under the {@code development} profile.
 */
@Profile("development")
@Component
public class DevAdminSeeder {

    private final UserRepository userRepository;
    private final PasswordEncoder passwordEncoder;

    @Value("${DEV_ADMIN_EMAIL:admin@dev.local}")
    private String adminEmail;

    @Value("${DEV_ADMIN_PASSWORD:admin123}")
    private String adminPassword;

    public DevAdminSeeder(UserRepository userRepository, PasswordEncoder passwordEncoder) {
        this.userRepository = userRepository;
        this.passwordEncoder = passwordEncoder;
    }

    @EventListener(ApplicationReadyEvent.class)
    public void seedAdmin() {
        // Check if admin already exists
        if (userRepository.findByEmail(adminEmail).isPresent()) {
            return; // Idempotent - do nothing if already present
        }
        User admin = User.builder()
                .name("Development Admin")
                .email(adminEmail)
                .password(passwordEncoder.encode(adminPassword))
                .role(UserRole.ADMIN)
                .isActive(true)
                .build();
        userRepository.save(admin);
    }
}
