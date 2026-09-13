package com.doorworkflow.controller;

import com.doorworkflow.dto.request.LoginRequest;
import com.doorworkflow.dto.response.LoginResponse;
import com.doorworkflow.entity.User;
import com.doorworkflow.enums.UserRole;
import com.doorworkflow.repository.UserRepository;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.MediaType;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.MockMvc;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
public class AuthIntegrationTest {

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private UserRepository userRepository;

    @Autowired
    private PasswordEncoder passwordEncoder;

    @Autowired
    private ObjectMapper objectMapper;

    private User activeUser;
    private User inactiveUser;

    @BeforeEach
    void setUp() {
        userRepository.deleteAll();
        activeUser = User.builder()
                .name("Active User")
                .email("active@example.com")
                .password(passwordEncoder.encode("password123"))
                .role(UserRole.MANAGER)
                .isActive(true)
                .build();
        inactiveUser = User.builder()
                .name("Inactive User")
                .email("inactive@example.com")
                .password(passwordEncoder.encode("password123"))
                .role(UserRole.WORKER)
                .isActive(false)
                .build();
        userRepository.save(activeUser);
        userRepository.save(inactiveUser);
    }

    @Test
    void loginSuccess_returnsTokenAndUserInfo() throws Exception {
        LoginRequest request = new LoginRequest();
        request.setEmail(activeUser.getEmail());
        request.setPassword("password123");
        mockMvc.perform(post("/api/auth/login")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(request)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.token").isString())
                .andExpect(jsonPath("$.userId").value(activeUser.getId().toString()))
                .andExpect(jsonPath("$.name").value(activeUser.getName()))
                .andExpect(jsonPath("$.role").value(activeUser.getRole().name()));
    }

    @Test
    void loginInvalidPassword_returns401() throws Exception {
        LoginRequest request = new LoginRequest();
        request.setEmail(activeUser.getEmail());
        request.setPassword("wrongPassword");
        mockMvc.perform(post("/api/auth/login")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(request)))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.status").value(401));
    }

    @Test
    void loginUnknownEmail_returns401() throws Exception {
        LoginRequest request = new LoginRequest();
        request.setEmail("unknown@example.com");
        request.setPassword("password123");
        mockMvc.perform(post("/api/auth/login")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(request)))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.status").value(401));
    }

    @Test
    void loginInactiveUser_returns401() throws Exception {
        LoginRequest request = new LoginRequest();
        request.setEmail(inactiveUser.getEmail());
        request.setPassword("password123");
        mockMvc.perform(post("/api/auth/login")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(request)))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.status").value(401));
    }

    @Test
    void rbacAdminAccess() throws Exception {
        // create admin user
        User admin = User.builder()
                .name("Admin")
                .email("admin@example.com")
                .password(passwordEncoder.encode("adminPass"))
                .role(UserRole.ADMIN)
                .isActive(true)
                .build();
        userRepository.save(admin);
        // login admin
        String token = obtainJwt(admin.getEmail(), "adminPass");
        // admin can access admin endpoint
        mockMvc.perform(get("/api/admin/test")
                        .header("Authorization", "Bearer " + token))
                .andExpect(status().isOk())
                .andExpect(content().string("admin ok"));
        // admin cannot access manager endpoint (should be forbidden)
        mockMvc.perform(get("/api/manager/test")
                        .header("Authorization", "Bearer " + token))
                .andExpect(status().isForbidden());
    }

    @Test
    void rbacManagerAccess() throws Exception {
        String token = obtainJwt(activeUser.getEmail(), "password123");
        // manager can access manager endpoint
        mockMvc.perform(get("/api/manager/test")
                        .header("Authorization", "Bearer " + token))
                .andExpect(status().isOk())
                .andExpect(content().string("manager ok"));
        // manager cannot access admin endpoint
        mockMvc.perform(get("/api/admin/test")
                        .header("Authorization", "Bearer " + token))
                .andExpect(status().isForbidden());
    }

    @Test
    void rbacWorkerAccess() throws Exception {
        // create worker user
        User worker = User.builder()
                .name("Worker")
                .email("worker@example.com")
                .password(passwordEncoder.encode("workerPass"))
                .role(UserRole.WORKER)
                .isActive(true)
                .build();
        userRepository.save(worker);
        String token = obtainJwt(worker.getEmail(), "workerPass");
        mockMvc.perform(get("/api/worker/test")
                        .header("Authorization", "Bearer " + token))
                .andExpect(status().isOk())
                .andExpect(content().string("worker ok"));
        // worker cannot access manager endpoint
        mockMvc.perform(get("/api/manager/test")
                        .header("Authorization", "Bearer " + token))
                .andExpect(status().isForbidden());
    }

    @Test
    void deactivatedUserJwtRejected() throws Exception {
        String token = obtainJwt(activeUser.getEmail(), "password123");
        // deactivate user
        activeUser.setIsActive(false);
        userRepository.save(activeUser);
        // attempt to access protected endpoint
        mockMvc.perform(get("/api/manager/test")
                        .header("Authorization", "Bearer " + token))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.status").value(401));
    }

    private String obtainJwt(String email, String rawPassword) throws Exception {
        LoginRequest request = new LoginRequest();
        request.setEmail(email);
        request.setPassword(rawPassword);
        String response = mockMvc.perform(post("/api/auth/login")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(request)))
                .andExpect(status().isOk())
                .andReturn()
                .getResponse()
                .getContentAsString();
        LoginResponse loginResponse = objectMapper.readValue(response, LoginResponse.class);
        return loginResponse.getToken();
    }
}
