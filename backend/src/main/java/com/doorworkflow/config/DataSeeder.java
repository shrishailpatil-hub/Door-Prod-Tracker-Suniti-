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
        if (userRepository.findByEmail(ADMIN_EMAIL).isPresent()) {
            return;
        }
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
}
