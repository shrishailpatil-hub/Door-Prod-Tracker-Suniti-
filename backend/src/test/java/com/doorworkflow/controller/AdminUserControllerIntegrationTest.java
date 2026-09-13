package com.doorworkflow.controller;

import com.doorworkflow.config.TestRestTemplateConfig;
import org.springframework.context.annotation.Import;
import com.doorworkflow.dto.request.CreateUserRequest;
import com.doorworkflow.dto.request.UpdateUserRequest;
import com.doorworkflow.dto.request.UpdateUserStatusRequest;
import com.doorworkflow.dto.response.UserResponse;
import com.doorworkflow.entity.User;
import com.doorworkflow.enums.UserRole;
import com.doorworkflow.repository.UserRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Nested;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.web.client.TestRestTemplate;
import org.springframework.boot.test.web.server.LocalServerPort;
import org.springframework.core.ParameterizedTypeReference;
import org.springframework.http.*;
import org.springframework.security.crypto.password.PasswordEncoder;

import java.util.List;
import java.util.Map;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
@Import(TestRestTemplateConfig.class)
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
class AdminUserControllerIntegrationTest {

    @LocalServerPort
    private int port;

    @Autowired
    private TestRestTemplate restTemplate;

    @Autowired
    private UserRepository userRepository;

    @Autowired
    private PasswordEncoder passwordEncoder;

    private String adminToken;
    private String adminEmail = System.getenv().getOrDefault("DEV_ADMIN_EMAIL", "admin@dev.local");
    private String adminPassword = System.getenv().getOrDefault("DEV_ADMIN_PASSWORD", "admin123");

    private String baseUrl() {
        return "http://localhost:" + port + "/api";
    }

    private String login(String email, String password) {
        var loginRequest = Map.of("email", email, "password", password);
        ResponseEntity<Map> resp = restTemplate.postForEntity(baseUrl() + "/auth/login", loginRequest, Map.class);
        assertThat(resp.getStatusCode()).isEqualTo(HttpStatus.OK);
        return (String) resp.getBody().get("token");
    }

    @BeforeEach
    void setUp() {
        // Clean all users and recreate admin for deterministic tests
        userRepository.deleteAll();
        var admin = User.builder()
                .name("admin")
                .email(adminEmail)
                .password(passwordEncoder.encode(adminPassword))
                .role(UserRole.ADMIN)
                .isActive(true)
                .build();
        userRepository.save(admin);
        adminToken = login(adminEmail, adminPassword);
    }

    private HttpHeaders authHeaders(String token) {
        HttpHeaders headers = new HttpHeaders();
        headers.setBearerAuth(token);
        headers.setContentType(MediaType.APPLICATION_JSON);
        return headers;
    }

    @Test
    @DisplayName("1. Create user successfully")
    void createUser_success() {
        var request = new CreateUserRequest("John Doe", "john@example.com", "password123", UserRole.WORKER);
        HttpEntity<CreateUserRequest> entity = new HttpEntity<>(request, authHeaders(adminToken));
        ResponseEntity<UserResponse> response = restTemplate.exchange(baseUrl() + "/admin/users", HttpMethod.POST, entity, UserResponse.class);
        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.OK);
        UserResponse body = response.getBody();
        assertThat(body).isNotNull();
        assertThat(body.id()).isNotNull();
        assertThat(body.name()).isEqualTo("John Doe");
        assertThat(body.email()).isEqualTo("john@example.com");
        assertThat(body.role()).isEqualTo(UserRole.WORKER);
        assertThat(body.isActive()).isTrue();
        User saved = userRepository.findById(body.id()).orElseThrow();
        assertThat(passwordEncoder.matches("password123", saved.getPassword())).isTrue();
        assertThat(saved.getPassword()).doesNotContain("password123");
    }

    @Test
    @DisplayName("2. Duplicate email returns 409")
    void createUser_duplicateEmail() {
        var req1 = new CreateUserRequest("A", "dup@example.com", "pass1234", UserRole.MANAGER);
        HttpEntity<CreateUserRequest> e1 = new HttpEntity<>(req1, authHeaders(adminToken));
        restTemplate.exchange(baseUrl() + "/admin/users", HttpMethod.POST, e1, UserResponse.class);
        var req2 = new CreateUserRequest("B", "dup@example.com", "otherpass", UserRole.WORKER);
        HttpEntity<CreateUserRequest> e2 = new HttpEntity<>(req2, authHeaders(adminToken));
        ResponseEntity<String> resp = restTemplate.exchange(baseUrl() + "/admin/users", HttpMethod.POST, e2, String.class);
        assertThat(resp.getStatusCode()).isEqualTo(HttpStatus.CONFLICT);
    }

    @Test
    @DisplayName("3. Validation failures return 400")
    void createUser_validationFailures() {
        var missingName = Map.of("email", "v1@example.com", "password", "pass1234", "role", "WORKER");
        HttpEntity<Map<String, String>> ent1 = new HttpEntity<>(missingName, authHeaders(adminToken));
        ResponseEntity<String> r1 = restTemplate.exchange(baseUrl() + "/admin/users", HttpMethod.POST, ent1, String.class);
        assertThat(r1.getStatusCode()).isEqualTo(HttpStatus.BAD_REQUEST);
        var badEmail = Map.of("name", "X", "email", "not-an-email", "password", "pass1234", "role", "WORKER");
        HttpEntity<Map<String, String>> ent2 = new HttpEntity<>(badEmail, authHeaders(adminToken));
        ResponseEntity<String> r2 = restTemplate.exchange(baseUrl() + "/admin/users", HttpMethod.POST, ent2, String.class);
        assertThat(r2.getStatusCode()).isEqualTo(HttpStatus.BAD_REQUEST);
        var missingPass = Map.of("name", "X", "email", "v2@example.com", "role", "WORKER");
        HttpEntity<Map<String, String>> ent3 = new HttpEntity<>(missingPass, authHeaders(adminToken));
        ResponseEntity<String> r3 = restTemplate.exchange(baseUrl() + "/admin/users", HttpMethod.POST, ent3, String.class);
        assertThat(r3.getStatusCode()).isEqualTo(HttpStatus.BAD_REQUEST);
        var shortPass = Map.of("name", "X", "email", "v3@example.com", "password", "short", "role", "WORKER");
        HttpEntity<Map<String, String>> ent4 = new HttpEntity<>(shortPass, authHeaders(adminToken));
        ResponseEntity<String> r4 = restTemplate.exchange(baseUrl() + "/admin/users", HttpMethod.POST, ent4, String.class);
        assertThat(r4.getStatusCode()).isEqualTo(HttpStatus.BAD_REQUEST);
        var missingRole = Map.of("name", "X", "email", "v4@example.com", "password", "pass1234");
        HttpEntity<Map<String, String>> ent5 = new HttpEntity<>(missingRole, authHeaders(adminToken));
        ResponseEntity<String> r5 = restTemplate.exchange(baseUrl() + "/admin/users", HttpMethod.POST, ent5, String.class);
        assertThat(r5.getStatusCode()).isEqualTo(HttpStatus.BAD_REQUEST);
    }

    @Test
    @DisplayName("5. List users returns all without passwords")
    void listUsers() {
        var u1 = new CreateUserRequest("U1", "u1@example.com", "pass1111", UserRole.WORKER);
        var u2 = new CreateUserRequest("U2", "u2@example.com", "pass2222", UserRole.MANAGER);
        restTemplate.exchange(baseUrl() + "/admin/users", HttpMethod.POST, new HttpEntity<>(u1, authHeaders(adminToken)), UserResponse.class);
        restTemplate.exchange(baseUrl() + "/admin/users", HttpMethod.POST, new HttpEntity<>(u2, authHeaders(adminToken)), UserResponse.class);
        ResponseEntity<List<UserResponse>> resp = restTemplate.exchange(baseUrl() + "/admin/users", HttpMethod.GET, new HttpEntity<>(authHeaders(adminToken)), new ParameterizedTypeReference<List<UserResponse>>() {});
        assertThat(resp.getStatusCode()).isEqualTo(HttpStatus.OK);
        List<UserResponse> list = resp.getBody();
        assertThat(list).hasSize(3);
        assertThat(list).extracting(UserResponse::email).containsExactlyInAnyOrder("admin@dev.local", "u1@example.com", "u2@example.com");
    }

    @Test
    @DisplayName("6. Get user by id")
    void getUser() {
        var create = new CreateUserRequest("Jane", "jane@example.com", "securePass", UserRole.MANAGER);
        ResponseEntity<UserResponse> created = restTemplate.exchange(baseUrl() + "/admin/users", HttpMethod.POST, new HttpEntity<>(create, authHeaders(adminToken)), UserResponse.class);
        UUID id = created.getBody().id();
        ResponseEntity<UserResponse> fetched = restTemplate.exchange(baseUrl() + "/admin/users/" + id, HttpMethod.GET, new HttpEntity<>(authHeaders(adminToken)), UserResponse.class);
        assertThat(fetched.getStatusCode()).isEqualTo(HttpStatus.OK);
        UserResponse ur = fetched.getBody();
        assertThat(ur.name()).isEqualTo("Jane");
        assertThat(ur.email()).isEqualTo("jane@example.com");
        assertThat(ur.role()).isEqualTo(UserRole.MANAGER);
    }

    @Test
    @DisplayName("7. Update user fields (name, email, role)")
    void updateUser_fields() {
        var create = new CreateUserRequest("Old", "old@example.com", "oldPass123", UserRole.WORKER);
        UUID id = restTemplate.exchange(baseUrl() + "/admin/users", HttpMethod.POST, new HttpEntity<>(create, authHeaders(adminToken)), UserResponse.class).getBody().id();
        var updateReq = new UpdateUserRequest("NewName", "new@example.com", UserRole.MANAGER, null);
        ResponseEntity<UserResponse> updated = restTemplate.exchange(baseUrl() + "/admin/users/" + id, HttpMethod.PUT, new HttpEntity<>(updateReq, authHeaders(adminToken)), UserResponse.class);
        assertThat(updated.getStatusCode()).isEqualTo(HttpStatus.OK);
        UserResponse body = updated.getBody();
        assertThat(body.name()).isEqualTo("NewName");
        assertThat(body.email()).isEqualTo("new@example.com");
        assertThat(body.role()).isEqualTo(UserRole.MANAGER);
        User db = userRepository.findById(id).orElseThrow();
        assertThat(db.getName()).isEqualTo("NewName");
        assertThat(db.getEmail()).isEqualTo("new@example.com");
        assertThat(db.getRole()).isEqualTo(UserRole.MANAGER);
    }

    @Test
    @DisplayName("8. Optional password update – password changes when provided")
    void updateUser_passwordChange() {
        var create = new CreateUserRequest("Bob", "bob@example.com", "oldPass123", UserRole.WORKER);
        UUID id = restTemplate.exchange(baseUrl() + "/admin/users", HttpMethod.POST, new HttpEntity<>(create, authHeaders(adminToken)), UserResponse.class).getBody().id();
        var update = new UpdateUserRequest("Bob", "bob@example.com", UserRole.WORKER, "newPass456");
        restTemplate.exchange(baseUrl() + "/admin/users/" + id, HttpMethod.PUT, new HttpEntity<>(update, authHeaders(adminToken)), UserResponse.class);
        User db = userRepository.findById(id).orElseThrow();
        assertThat(passwordEncoder.matches("newPass456", db.getPassword())).isTrue();
        assertThat(passwordEncoder.matches("oldPass123", db.getPassword())).isFalse();
    }

    @Test
    @DisplayName("9. Password omitted during update keeps existing hash")
    void updateUser_passwordOmitted() {
        var create = new CreateUserRequest("Alice", "alice@example.com", "originalPass", UserRole.WORKER);
        UUID id = restTemplate.exchange(baseUrl() + "/admin/users", HttpMethod.POST, new HttpEntity<>(create, authHeaders(adminToken)), UserResponse.class).getBody().id();
        User before = userRepository.findById(id).orElseThrow();
        String storedHash = before.getPassword();
        var update = new UpdateUserRequest("Alice Updated", "alice@example.com", UserRole.WORKER, null);
        restTemplate.exchange(baseUrl() + "/admin/users/" + id, HttpMethod.PUT, new HttpEntity<>(update, authHeaders(adminToken)), UserResponse.class);
        User after = userRepository.findById(id).orElseThrow();
        assertThat(after.getPassword()).isEqualTo(storedHash);
        assertThat(passwordEncoder.matches("originalPass", after.getPassword())).isTrue();
    }

    @Test
    @DisplayName("10. Duplicate email during update returns 409")
    void updateUser_duplicateEmail() {
        var a = new CreateUserRequest("A", "a@example.com", "passA1234", UserRole.WORKER);
        var b = new CreateUserRequest("B", "b@example.com", "passB1234", UserRole.WORKER);
        UUID idA = restTemplate.exchange(baseUrl() + "/admin/users", HttpMethod.POST, new HttpEntity<>(a, authHeaders(adminToken)), UserResponse.class).getBody().id();
        UUID idB = restTemplate.exchange(baseUrl() + "/admin/users", HttpMethod.POST, new HttpEntity<>(b, authHeaders(adminToken)), UserResponse.class).getBody().id();
        var update = new UpdateUserRequest("B", "a@example.com", UserRole.WORKER, null);
        ResponseEntity<String> resp = restTemplate.exchange(baseUrl() + "/admin/users/" + idB, HttpMethod.PUT, new HttpEntity<>(update, authHeaders(adminToken)), String.class);
        assertThat(resp.getStatusCode()).isEqualTo(HttpStatus.CONFLICT);
        User unchanged = userRepository.findById(idB).orElseThrow();
        assertThat(unchanged.getEmail()).isEqualTo("b@example.com");
    }

    @Test
    @DisplayName("11. Activate inactive user")
    void activateUser() {
        var create = new CreateUserRequest("E", "e@example.com", "passE123", UserRole.WORKER);
        UUID id = restTemplate.exchange(baseUrl() + "/admin/users", HttpMethod.POST, new HttpEntity<>(create, authHeaders(adminToken)), UserResponse.class).getBody().id();
        var deactivateReq = new UpdateUserStatusRequest(false);
        restTemplate.exchange(baseUrl() + "/admin/users/" + id + "/status", HttpMethod.PATCH, new HttpEntity<>(deactivateReq, authHeaders(adminToken)), UserResponse.class);
        var activateReq = new UpdateUserStatusRequest(true);
        ResponseEntity<UserResponse> resp = restTemplate.exchange(baseUrl() + "/admin/users/" + id + "/status", HttpMethod.PATCH, new HttpEntity<>(activateReq, authHeaders(adminToken)), UserResponse.class);
        assertThat(resp.getStatusCode()).isEqualTo(HttpStatus.OK);
        assertThat(resp.getBody().isActive()).isTrue();
        User db = userRepository.findById(id).orElseThrow();
        assertThat(db.getIsActive()).isTrue();
    }

    @Test
    @DisplayName("12. Deactivate active user")
    void deactivateUser() {
        var create = new CreateUserRequest("F", "f@example.com", "passF123", UserRole.WORKER);
        UUID id = restTemplate.exchange(baseUrl() + "/admin/users", HttpMethod.POST, new HttpEntity<>(create, authHeaders(adminToken)), UserResponse.class).getBody().id();
        var deactivate = new UpdateUserStatusRequest(false);
        ResponseEntity<UserResponse> resp = restTemplate.exchange(baseUrl() + "/admin/users/" + id + "/status", HttpMethod.PATCH, new HttpEntity<>(deactivate, authHeaders(adminToken)), UserResponse.class);
        assertThat(resp.getStatusCode()).isEqualTo(HttpStatus.OK);
        assertThat(resp.getBody().isActive()).isFalse();
        User db = userRepository.findById(id).orElseThrow();
        assertThat(db.getIsActive()).isFalse();
    }

    @Test
    @DisplayName("13. Self‑deactivation protection returns BAD_REQUEST")
    void selfDeactivationNotAllowed() {
        User admin = userRepository.findByEmail(adminEmail).orElseThrow();
        var deactivate = new UpdateUserStatusRequest(false);
        ResponseEntity<String> resp = restTemplate.exchange(baseUrl() + "/admin/users/" + admin.getId() + "/status", HttpMethod.PATCH, new HttpEntity<>(deactivate, authHeaders(adminToken)), String.class);
        assertThat(resp.getStatusCode()).isEqualTo(HttpStatus.BAD_REQUEST);
        User after = userRepository.findById(admin.getId()).orElseThrow();
        assertThat(after.getIsActive()).isTrue();
    }

    @Test
    @DisplayName("14. Deactivated user cannot log in")
    void deactivatedUserCannotLogin() {
        var create = new CreateUserRequest("G", "g@example.com", "passG123", UserRole.WORKER);
        UUID id = restTemplate.exchange(baseUrl() + "/admin/users", HttpMethod.POST, new HttpEntity<>(create, authHeaders(adminToken)), UserResponse.class).getBody().id();
        String token = login("g@example.com", "passG123");
        assertThat(token).isNotBlank();
        var deactivate = new UpdateUserStatusRequest(false);
        restTemplate.exchange(baseUrl() + "/admin/users/" + id + "/status", HttpMethod.PATCH, new HttpEntity<>(deactivate, authHeaders(adminToken)), UserResponse.class);
        var loginReq = Map.of("email", "g@example.com", "password", "passG123");
        ResponseEntity<Map> resp = restTemplate.postForEntity(baseUrl() + "/auth/login", loginReq, Map.class);
        assertThat(resp.getStatusCode()).isEqualTo(HttpStatus.UNAUTHORIZED);
        assertThat(resp.getBody()).containsEntry("status", 401);
    }

    @Test
    @DisplayName("15. Existing JWT becomes invalid after deactivation")
    void jwtInvalidAfterDeactivation() {
        var create = new CreateUserRequest("H", "h@example.com", "passH123", UserRole.WORKER);
        UUID id = restTemplate.exchange(baseUrl() + "/admin/users", HttpMethod.POST, new HttpEntity<>(create, authHeaders(adminToken)), UserResponse.class).getBody().id();
        String token = login("h@example.com", "passH123");
        HttpHeaders hdr = new HttpHeaders();
        hdr.setBearerAuth(token);
        HttpEntity<Void> entity = new HttpEntity<>(hdr);
        ResponseEntity<String> before = restTemplate.exchange(baseUrl() + "/admin/users", HttpMethod.GET, entity, String.class);
        assertThat(before.getStatusCode()).isNotEqualTo(HttpStatus.UNAUTHORIZED);
        var deactivate = new UpdateUserStatusRequest(false);
        restTemplate.exchange(baseUrl() + "/admin/users/" + id + "/status", HttpMethod.PATCH, new HttpEntity<>(deactivate, authHeaders(adminToken)), UserResponse.class);
        ResponseEntity<String> after = restTemplate.exchange(baseUrl() + "/admin/users", HttpMethod.GET, entity, String.class);
        assertThat(after.getStatusCode()).isEqualTo(HttpStatus.UNAUTHORIZED);
        assertThat(after.getBody()).contains("\"status\":401");
    }

    @Nested
    @DisplayName("16-18 Authorization checks")
    class AuthorizationTests {
        private String managerToken;
        private String workerToken;

        @BeforeEach
        void createOtherRoles() {
            var mgr = new CreateUserRequest("Mgr", "mgr@example.com", "mgrPass123", UserRole.MANAGER);
            restTemplate.exchange(baseUrl() + "/admin/users", HttpMethod.POST, new HttpEntity<>(mgr, authHeaders(adminToken)), UserResponse.class);
            managerToken = login("mgr@example.com", "mgrPass123");
            var wk = new CreateUserRequest("Wkr", "wkr@example.com", "wkrPass123", UserRole.WORKER);
            restTemplate.exchange(baseUrl() + "/admin/users", HttpMethod.POST, new HttpEntity<>(wk, authHeaders(adminToken)), UserResponse.class);
            workerToken = login("wkr@example.com", "wkrPass123");
        }

        @Test
        @DisplayName("16. ADMIN can access admin endpoint")
        void adminAccess() {
            ResponseEntity<String> resp = restTemplate.exchange(baseUrl() + "/admin/users", HttpMethod.GET, new HttpEntity<>(authHeaders(adminToken)), String.class);
            assertThat(resp.getStatusCode()).isEqualTo(HttpStatus.OK);
        }

        @Test
        @DisplayName("17. MANAGER receives 403 on admin endpoint")
        void managerForbidden() {
            ResponseEntity<String> resp = restTemplate.exchange(baseUrl() + "/admin/users", HttpMethod.GET, new HttpEntity<>(authHeaders(managerToken)), String.class);
            assertThat(resp.getStatusCode()).isEqualTo(HttpStatus.FORBIDDEN);
        }

        @Test
        @DisplayName("18. WORKER receives 403 on admin endpoint")
        void workerForbidden() {
            ResponseEntity<String> resp = restTemplate.exchange(baseUrl() + "/admin/users", HttpMethod.GET, new HttpEntity<>(authHeaders(workerToken)), String.class);
            assertThat(resp.getStatusCode()).isEqualTo(HttpStatus.FORBIDDEN);
        }
    }

    @Test
    @DisplayName("19. Unauthenticated request returns 401 with proper JSON structure")
    void unauthenticatedRequest() {
        ResponseEntity<Map> resp = restTemplate.getForEntity(baseUrl() + "/admin/users", Map.class);
        assertThat(resp.getStatusCode()).isEqualTo(HttpStatus.UNAUTHORIZED);
        assertThat(resp.getBody()).containsEntry("status", 401);
    }

    @Test
    @DisplayName("20. Role changes use current DB role (not JWT claim)")
    void roleChangeReflectedImmediately() {
        var mgr = new CreateUserRequest("RoleUser", "roleuser@example.com", "rolePass123", UserRole.MANAGER);
        UUID id = restTemplate.exchange(baseUrl() + "/admin/users", HttpMethod.POST, new HttpEntity<>(mgr, authHeaders(adminToken)), UserResponse.class).getBody().id();
        String token = login("roleuser@example.com", "rolePass123");
        HttpHeaders hdr = new HttpHeaders();
        hdr.setBearerAuth(token);
        ResponseEntity<String> okResp = restTemplate.exchange(baseUrl() + "/manager/test", HttpMethod.GET, new HttpEntity<>(hdr), String.class);
        assertThat(okResp.getStatusCode()).isEqualTo(HttpStatus.OK);
        User user = userRepository.findById(id).orElseThrow();
        user.setRole(UserRole.WORKER);
        userRepository.save(user);
        ResponseEntity<String> afterResp = restTemplate.exchange(baseUrl() + "/manager/test", HttpMethod.GET, new HttpEntity<>(hdr), String.class);
        assertThat(afterResp.getStatusCode()).isEqualTo(HttpStatus.FORBIDDEN);
        user.setRole(UserRole.MANAGER);
        userRepository.save(user);
        ResponseEntity<String> restored = restTemplate.exchange(baseUrl() + "/manager/test", HttpMethod.GET, new HttpEntity<>(hdr), String.class);
        assertThat(restored.getStatusCode()).isEqualTo(HttpStatus.OK);
    }
}
