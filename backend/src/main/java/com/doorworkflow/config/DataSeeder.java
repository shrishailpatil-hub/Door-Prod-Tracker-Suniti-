package com.doorworkflow.config;

import com.doorworkflow.entity.User;
import com.doorworkflow.enums.UserRole;
import com.doorworkflow.repository.UserRepository;
import org.springframework.boot.CommandLineRunner;
import org.springframework.stereotype.Component;
import org.springframework.security.crypto.password.PasswordEncoder;

@Component
public class DataSeeder implements CommandLineRunner {

    private static final String ADMIN_EMAIL = "shrishailpatil5656@gmail.com";
    private static final String ADMIN_PASSWORD = "Shri@2005";
    private static final String ADMIN_NAME = "Shrishail Patil";

    private final UserRepository userRepository;
    private final PasswordEncoder passwordEncoder;

    public DataSeeder(UserRepository userRepository, PasswordEncoder passwordEncoder) {
        this.userRepository = userRepository;
        this.passwordEncoder = passwordEncoder;
    }

    @Override
    public void run(String... args) throws Exception {
        // Ensure ADMIN user exists
        if (!userRepository.findByEmail(ADMIN_EMAIL).isPresent()) {
            User admin = User.builder()
                    .name(ADMIN_NAME)
                    .email(ADMIN_EMAIL)
                    .password(passwordEncoder.encode(ADMIN_PASSWORD))
                    .role(UserRole.ADMIN)
                    .isActive(true)
                    .build();
            userRepository.save(admin);
            System.out.println("[DataSeeder] Created initial ADMIN user: " + ADMIN_EMAIL);
        }

        // Ensure default MANAGER user exists
        final String MANAGER_EMAIL = "manager@suniti.com";
        final String MANAGER_PASSWORD = "Manager@123"; // simple test password
        final String MANAGER_NAME = "Test Manager";
        if (!userRepository.findByEmail(MANAGER_EMAIL).isPresent()) {
            User manager = User.builder()
                    .name(MANAGER_NAME)
                    .email(MANAGER_EMAIL)
                    .password(passwordEncoder.encode(MANAGER_PASSWORD))
                    .role(UserRole.MANAGER)
                    .isActive(true)
                    .build();
            userRepository.save(manager);
            System.out.println("[DataSeeder] Created default MANAGER user: " + MANAGER_EMAIL);
        }

        // Ensure default WORKER user exists
        final String WORKER_EMAIL = "worker@suniti.com";
        final String WORKER_PASSWORD = "Worker@123"; // simple test password
        final String WORKER_NAME = "Test Worker";
        if (!userRepository.findByEmail(WORKER_EMAIL).isPresent()) {
            User worker = User.builder()
                    .name(WORKER_NAME)
                    .email(WORKER_EMAIL)
                    .password(passwordEncoder.encode(WORKER_PASSWORD))
                    .role(UserRole.WORKER)
                    .isActive(true)
                    .build();
            userRepository.save(worker);
            System.out.println("[DataSeeder] Created default WORKER user: " + WORKER_EMAIL);
        }
    }
}
