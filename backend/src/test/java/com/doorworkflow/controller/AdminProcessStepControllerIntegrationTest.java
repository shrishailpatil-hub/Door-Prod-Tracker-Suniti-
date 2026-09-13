package com.doorworkflow.controller;

import com.doorworkflow.config.TestRestTemplateConfig;
import com.doorworkflow.dto.request.CreateProcessStepRequest;
import com.doorworkflow.dto.request.UpdateProcessStepRequest;
import com.doorworkflow.dto.response.ProcessStepResponse;
import com.doorworkflow.entity.ProcessStep;
import com.doorworkflow.entity.User;
import com.doorworkflow.enums.UserRole;
import com.doorworkflow.repository.ProcessStepRepository;
import com.doorworkflow.repository.UserRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Nested;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.web.client.TestRestTemplate;
import org.springframework.boot.test.web.server.LocalServerPort;
import org.springframework.context.annotation.Import;
import org.springframework.core.ParameterizedTypeReference;
import org.springframework.http.*;
import org.springframework.security.crypto.password.PasswordEncoder;

import java.util.List;
import java.util.Map;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;

@Import(TestRestTemplateConfig.class)
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
class AdminProcessStepControllerIntegrationTest {

    @LocalServerPort
    private int port;

    @Autowired
    private TestRestTemplate restTemplate;

    @Autowired
    private UserRepository userRepository;

    @Autowired
    private ProcessStepRepository processStepRepository;

    @Autowired
    private PasswordEncoder passwordEncoder;

    private String adminToken;
    private final String adminEmail = System.getenv().getOrDefault("DEV_ADMIN_EMAIL", "admin@dev.local");
    private final String adminPassword = System.getenv().getOrDefault("DEV_ADMIN_PASSWORD", "admin123");

    private String baseUrl() {
        return "http://localhost:" + port + "/api";
    }

    private String login(String email, String password) {
        var loginRequest = Map.of("email", email, "password", password);
        ResponseEntity<Map> resp = restTemplate.postForEntity(baseUrl() + "/auth/login", loginRequest, Map.class);
        assertThat(resp.getStatusCode()).isEqualTo(HttpStatus.OK);
        return (String) resp.getBody().get("token");
    }

    private HttpHeaders authHeaders(String token) {
        HttpHeaders headers = new HttpHeaders();
        headers.setBearerAuth(token);
        headers.setContentType(MediaType.APPLICATION_JSON);
        return headers;
    }

    @BeforeEach
    void setUp() {
        processStepRepository.deleteAll();
        userRepository.deleteAll();
        User admin = User.builder()
                .name("admin")
                .email(adminEmail)
                .password(passwordEncoder.encode(adminPassword))
                .role(UserRole.ADMIN)
                .isActive(true)
                .build();
        userRepository.save(admin);
        adminToken = login(adminEmail, adminPassword);
    }

    @Test
    @DisplayName("1. ADMIN can create a process step")
    void adminCreateSuccess() {
        var request = new CreateProcessStepRequest("Cutting", 1);
        HttpEntity<CreateProcessStepRequest> entity = new HttpEntity<>(request, authHeaders(adminToken));
        ResponseEntity<ProcessStepResponse> resp = restTemplate.exchange(baseUrl() + "/admin/process-steps", HttpMethod.POST, entity, ProcessStepResponse.class);
        assertThat(resp.getStatusCode()).isEqualTo(HttpStatus.OK);
        ProcessStepResponse body = resp.getBody();
        assertThat(body).isNotNull();
        assertThat(body.name()).isEqualTo("Cutting");
        assertThat(body.stepOrder()).isEqualTo(1);
        assertThat(body.isActive()).isTrue();
        assertThat(body.id()).isNotNull();
    }

    @Test
    @DisplayName("2. Creating at existing order shifts later active steps")
    void createShiftsActiveSteps() {
        ProcessStep s1 = ProcessStep.builder().name("Step1").stepOrder(1).isActive(true).build();
        ProcessStep s2 = ProcessStep.builder().name("Step2").stepOrder(2).isActive(true).build();
        processStepRepository.saveAll(List.of(s1, s2));
        var request = new CreateProcessStepRequest("NewStep", 1);
        HttpEntity<CreateProcessStepRequest> entity = new HttpEntity<>(request, authHeaders(adminToken));
        restTemplate.exchange(baseUrl() + "/admin/process-steps", HttpMethod.POST, entity, ProcessStepResponse.class);
        ResponseEntity<List<ProcessStepResponse>> listResp = restTemplate.exchange(baseUrl() + "/admin/process-steps", HttpMethod.GET,
                new HttpEntity<>(authHeaders(adminToken)), new ParameterizedTypeReference<List<ProcessStepResponse>>() {});
        List<ProcessStepResponse> steps = listResp.getBody();
        assertThat(steps).hasSize(3);
        assertThat(steps).extracting(ProcessStepResponse::name, ProcessStepResponse::stepOrder)
                .containsExactlyInAnyOrder(
                        org.assertj.core.groups.Tuple.tuple("NewStep", 1),
                        org.assertj.core.groups.Tuple.tuple("Step1", 2),
                        org.assertj.core.groups.Tuple.tuple("Step2", 3)
                );
    }

    @Test
    @DisplayName("3. Duplicate active name returns 409")
    void duplicateNameConflict() {
        var first = new CreateProcessStepRequest("Welding", 1);
        restTemplate.exchange(baseUrl() + "/admin/process-steps", HttpMethod.POST,
                new HttpEntity<>(first, authHeaders(adminToken)), ProcessStepResponse.class);
        var dup = new CreateProcessStepRequest("welding", 2);
        ResponseEntity<String> resp = restTemplate.exchange(baseUrl() + "/admin/process-steps", HttpMethod.POST,
                new HttpEntity<>(dup, authHeaders(adminToken)), String.class);
        assertThat(resp.getStatusCode()).isEqualTo(HttpStatus.CONFLICT);
    }

    @Test
    @DisplayName("4. Invalid stepOrder returns 400")
    void invalidStepOrderBadRequest() {
        var bad = new CreateProcessStepRequest("Bad", 0);
        ResponseEntity<String> resp = restTemplate.exchange(baseUrl() + "/admin/process-steps", HttpMethod.POST,
                new HttpEntity<>(bad, authHeaders(adminToken)), String.class);
        assertThat(resp.getStatusCode()).isEqualTo(HttpStatus.BAD_REQUEST);
    }

    @Test
    @DisplayName("5. Get existing step returns 200")
    void getExistingStep() {
        var created = restTemplate.exchange(baseUrl() + "/admin/process-steps", HttpMethod.POST,
                new HttpEntity<>(new CreateProcessStepRequest("Paint", 1), authHeaders(adminToken)), ProcessStepResponse.class).getBody();
        ResponseEntity<ProcessStepResponse> resp = restTemplate.exchange(baseUrl() + "/admin/process-steps/" + created.id(), HttpMethod.GET,
                new HttpEntity<>(authHeaders(adminToken)), ProcessStepResponse.class);
        assertThat(resp.getStatusCode()).isEqualTo(HttpStatus.OK);
        assertThat(resp.getBody().name()).isEqualTo("Paint");
    }

    @Test
    @DisplayName("6. Missing step returns 404")
    void getMissingStepNotFound() {
        ResponseEntity<String> resp = restTemplate.exchange(baseUrl() + "/admin/process-steps/" + UUID.randomUUID(), HttpMethod.GET,
                new HttpEntity<>(authHeaders(adminToken)), String.class);
        assertThat(resp.getStatusCode()).isEqualTo(HttpStatus.NOT_FOUND);
    }

    @Test
    @DisplayName("7. Update step name and order reorders correctly")
    void updateReorder() {
        ProcessStep s1 = ProcessStep.builder().name("S1").stepOrder(1).isActive(true).build();
        ProcessStep s2 = ProcessStep.builder().name("S2").stepOrder(2).isActive(true).build();
        ProcessStep s3 = ProcessStep.builder().name("S3").stepOrder(3).isActive(true).build();
        processStepRepository.saveAll(List.of(s1, s2, s3));
        var update = new UpdateProcessStepRequest("S3Renamed", 1);
        ResponseEntity<ProcessStepResponse> resp = restTemplate.exchange(baseUrl() + "/admin/process-steps/" + s3.getId(), HttpMethod.PUT,
                new HttpEntity<>(update, authHeaders(adminToken)), ProcessStepResponse.class);
        assertThat(resp.getStatusCode()).isEqualTo(HttpStatus.OK);
        ResponseEntity<List<ProcessStepResponse>> listResp = restTemplate.exchange(baseUrl() + "/admin/process-steps", HttpMethod.GET,
                new HttpEntity<>(authHeaders(adminToken)), new ParameterizedTypeReference<List<ProcessStepResponse>>() {});
        List<ProcessStepResponse> steps = listResp.getBody();
        assertThat(steps).extracting(ProcessStepResponse::name, ProcessStepResponse::stepOrder)
                .containsExactlyInAnyOrder(
                        org.assertj.core.groups.Tuple.tuple("S3Renamed", 1),
                        org.assertj.core.groups.Tuple.tuple("S1", 2),
                        org.assertj.core.groups.Tuple.tuple("S2", 3)
                );
    }

    @Test
    @DisplayName("8. Deactivate active step and gap is closed")
    void deactivateActiveClosesGap() {
        ProcessStep s1 = ProcessStep.builder().name("A1").stepOrder(1).isActive(true).build();
        ProcessStep s2 = ProcessStep.builder().name("A2").stepOrder(2).isActive(true).build();
        ProcessStep s3 = ProcessStep.builder().name("A3").stepOrder(3).isActive(true).build();
        processStepRepository.saveAll(List.of(s1, s2, s3));
        ResponseEntity<ProcessStepResponse> delResp = restTemplate.exchange(baseUrl() + "/admin/process-steps/" + s2.getId(), HttpMethod.DELETE,
                new HttpEntity<>(authHeaders(adminToken)), ProcessStepResponse.class);
        assertThat(delResp.getStatusCode()).isEqualTo(HttpStatus.OK);
        assertThat(delResp.getBody().isActive()).isFalse();
        ResponseEntity<List<ProcessStepResponse>> listResp = restTemplate.exchange(baseUrl() + "/admin/process-steps", HttpMethod.GET,
                new HttpEntity<>(authHeaders(adminToken)), new ParameterizedTypeReference<List<ProcessStepResponse>>() {});
        List<ProcessStepResponse> steps = listResp.getBody();
        assertThat(steps).extracting(ProcessStepResponse::name, ProcessStepResponse::stepOrder, ProcessStepResponse::isActive)
                .containsExactlyInAnyOrder(
                        org.assertj.core.groups.Tuple.tuple("A1", 1, true),
                        org.assertj.core.groups.Tuple.tuple("A2", 2, false),
                        org.assertj.core.groups.Tuple.tuple("A3", 2, true)
                );
    }

    @Test
    @DisplayName("9. Deactivating already inactive step is idempotent")
    void deactivateAlreadyInactiveIdempotent() {
        ProcessStep inactive = ProcessStep.builder().name("Old").stepOrder(5).isActive(false).build();
        ProcessStep saved = processStepRepository.save(inactive);
        ResponseEntity<ProcessStepResponse> resp = restTemplate.exchange(baseUrl() + "/admin/process-steps/" + saved.getId(), HttpMethod.DELETE,
                new HttpEntity<>(authHeaders(adminToken)), ProcessStepResponse.class);
        assertThat(resp.getStatusCode()).isEqualTo(HttpStatus.OK);
        assertThat(resp.getBody().isActive()).isFalse();
        ProcessStep after = processStepRepository.findById(saved.getId()).orElseThrow();
        assertThat(after.getIsActive()).isFalse();
    }

    @Test
    @DisplayName("10. Reactivate inactive step appends to active end with contiguous order")
    void reactivateInactiveStepAppendsToEnd() {
        ProcessStep s1 = ProcessStep.builder().name("StepA").stepOrder(1).isActive(true).build();
        ProcessStep s2 = ProcessStep.builder().name("StepB").stepOrder(2).isActive(true).build();
        ProcessStep s3 = ProcessStep.builder().name("StepC").stepOrder(3).isActive(true).build();
        processStepRepository.saveAll(List.of(s1, s2, s3));

        // Deactivate StepB -> StepC becomes order 2, active count = 2
        restTemplate.exchange(baseUrl() + "/admin/process-steps/" + s2.getId(), HttpMethod.DELETE,
                new HttpEntity<>(authHeaders(adminToken)), ProcessStepResponse.class);

        // Reactivate StepB -> becomes active, order should be active count (2) + 1 = 3
        ResponseEntity<ProcessStepResponse> reactivateResp = restTemplate.exchange(
                baseUrl() + "/admin/process-steps/" + s2.getId() + "/reactivate",
                HttpMethod.POST,
                new HttpEntity<>(authHeaders(adminToken)),
                ProcessStepResponse.class);

        assertThat(reactivateResp.getStatusCode()).isEqualTo(HttpStatus.OK);
        assertThat(reactivateResp.getBody()).isNotNull();
        assertThat(reactivateResp.getBody().isActive()).isTrue();
        assertThat(reactivateResp.getBody().stepOrder()).isEqualTo(3);
        assertThat(reactivateResp.getBody().name()).isEqualTo("StepB");

        // Verify full list and contiguous ordering 1, 2, 3
        ResponseEntity<List<ProcessStepResponse>> listResp = restTemplate.exchange(baseUrl() + "/admin/process-steps", HttpMethod.GET,
                new HttpEntity<>(authHeaders(adminToken)), new ParameterizedTypeReference<List<ProcessStepResponse>>() {});
        List<ProcessStepResponse> steps = listResp.getBody();
        assertThat(steps).hasSize(3);
        assertThat(steps).extracting(ProcessStepResponse::name, ProcessStepResponse::stepOrder, ProcessStepResponse::isActive)
                .containsExactlyInAnyOrder(
                        org.assertj.core.groups.Tuple.tuple("StepA", 1, true),
                        org.assertj.core.groups.Tuple.tuple("StepC", 2, true),
                        org.assertj.core.groups.Tuple.tuple("StepB", 3, true)
                );
    }

    @Test
    @DisplayName("11. Reactivating already active step returns 400 Bad Request")
    void reactivateAlreadyActiveReturnsBadRequest() {
        ProcessStep s1 = ProcessStep.builder().name("ActiveOne").stepOrder(1).isActive(true).build();
        processStepRepository.save(s1);

        ResponseEntity<String> resp = restTemplate.exchange(
                baseUrl() + "/admin/process-steps/" + s1.getId() + "/reactivate",
                HttpMethod.POST,
                new HttpEntity<>(authHeaders(adminToken)),
                String.class);

        assertThat(resp.getStatusCode()).isEqualTo(HttpStatus.BAD_REQUEST);
    }

    @Test
    @DisplayName("12. Reactivating step with duplicate active name returns 409 Conflict")
    void reactivateDuplicateActiveNameReturnsConflict() {
        ProcessStep s1 = ProcessStep.builder().name("Polishing").stepOrder(1).isActive(true).build();
        ProcessStep s2 = ProcessStep.builder().name("polishing").stepOrder(2).isActive(false).build();
        processStepRepository.saveAll(List.of(s1, s2));

        ResponseEntity<String> resp = restTemplate.exchange(
                baseUrl() + "/admin/process-steps/" + s2.getId() + "/reactivate",
                HttpMethod.POST,
                new HttpEntity<>(authHeaders(adminToken)),
                String.class);

        assertThat(resp.getStatusCode()).isEqualTo(HttpStatus.CONFLICT);
    }

    @Test
    @DisplayName("13. Reactivating non-existent step returns 404 Not Found")
    void reactivateNonExistentReturnsNotFound() {
        ResponseEntity<String> resp = restTemplate.exchange(
                baseUrl() + "/admin/process-steps/" + UUID.randomUUID() + "/reactivate",
                HttpMethod.POST,
                new HttpEntity<>(authHeaders(adminToken)),
                String.class);

        assertThat(resp.getStatusCode()).isEqualTo(HttpStatus.NOT_FOUND);
    }

    @Nested
    @DisplayName("Authorization checks")
    class AuthorizationTests {
        private String managerToken;
        private String workerToken;
        private ProcessStep testStep;

        @BeforeEach
        void createUsers() {
            User manager = User.builder()
                    .name("manager")
                    .email("manager@example.com")
                    .password(passwordEncoder.encode("mgrpass"))
                    .role(UserRole.MANAGER)
                    .isActive(true)
                    .build();
            User worker = User.builder()
                    .name("worker")
                    .email("worker@example.com")
                    .password(passwordEncoder.encode("wrkpass"))
                    .role(UserRole.WORKER)
                    .isActive(true)
                    .build();
            userRepository.saveAll(List.of(manager, worker));
            managerToken = login("manager@example.com", "mgrpass");
            workerToken = login("worker@example.com", "wrkpass");

            testStep = processStepRepository.save(
                    ProcessStep.builder().name("InactiveStep").stepOrder(1).isActive(false).build()
            );
        }

        @Test
        void managerCannotCreate() {
            var request = new CreateProcessStepRequest("StepX", 1);
            ResponseEntity<String> resp = restTemplate.exchange(baseUrl() + "/admin/process-steps", HttpMethod.POST,
                    new HttpEntity<>(request, authHeaders(managerToken)), String.class);
            assertThat(resp.getStatusCode()).isEqualTo(HttpStatus.FORBIDDEN);
        }

        @Test
        void managerCannotReactivate() {
            ResponseEntity<String> resp = restTemplate.exchange(
                    baseUrl() + "/admin/process-steps/" + testStep.getId() + "/reactivate",
                    HttpMethod.POST,
                    new HttpEntity<>(authHeaders(managerToken)),
                    String.class);
            assertThat(resp.getStatusCode()).isEqualTo(HttpStatus.FORBIDDEN);
        }

        @Test
        void workerCannotReactivate() {
            ResponseEntity<String> resp = restTemplate.exchange(
                    baseUrl() + "/admin/process-steps/" + testStep.getId() + "/reactivate",
                    HttpMethod.POST,
                    new HttpEntity<>(authHeaders(workerToken)),
                    String.class);
            assertThat(resp.getStatusCode()).isEqualTo(HttpStatus.FORBIDDEN);
        }

        @Test
        void unauthenticatedGets401() {
            var request = new CreateProcessStepRequest("StepY", 1);
            HttpHeaders headers = new HttpHeaders();
            headers.setContentType(MediaType.APPLICATION_JSON);
            ResponseEntity<String> resp = restTemplate.exchange(baseUrl() + "/admin/process-steps", HttpMethod.POST,
                    new HttpEntity<>(request, headers), String.class);
            assertThat(resp.getStatusCode()).isEqualTo(HttpStatus.UNAUTHORIZED);
        }

        @Test
        void unauthenticatedCannotReactivate() {
            HttpHeaders headers = new HttpHeaders();
            headers.setContentType(MediaType.APPLICATION_JSON);
            ResponseEntity<String> resp = restTemplate.exchange(
                    baseUrl() + "/admin/process-steps/" + testStep.getId() + "/reactivate",
                    HttpMethod.POST,
                    new HttpEntity<>(headers),
                    String.class);
            assertThat(resp.getStatusCode()).isEqualTo(HttpStatus.UNAUTHORIZED);
        }
    }
}
