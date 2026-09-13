package com.doorworkflow.controller;

import com.doorworkflow.config.TestRestTemplateConfig;
import com.doorworkflow.dto.request.AddChalanRequest;
import com.doorworkflow.dto.request.CreateJobRequest;
import com.doorworkflow.dto.request.CreateProcessStepRequest;
import com.doorworkflow.dto.request.CreateUserRequest;
import com.doorworkflow.dto.response.*;
import com.doorworkflow.entity.User;
import com.doorworkflow.enums.JobStatus;
import com.doorworkflow.enums.UserRole;
import com.doorworkflow.repository.JobRepository;
import com.doorworkflow.repository.ProcessStepRepository;
import com.doorworkflow.repository.UserRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
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

import static org.assertj.core.api.Assertions.assertThat;

@Import(TestRestTemplateConfig.class)
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
class FullWorkflowRuntimeVerificationTest {

    @LocalServerPort
    private int port;

    @Autowired
    private TestRestTemplate restTemplate;

    @Autowired
    private UserRepository userRepository;

    @Autowired
    private ProcessStepRepository processStepRepository;

    @Autowired
    private JobRepository jobRepository;

    @Autowired
    private PasswordEncoder passwordEncoder;

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
    void cleanDatabase() {
        jobRepository.deleteAll();
        processStepRepository.deleteAll();
        userRepository.deleteAll();
    }

    @Test
    @DisplayName("Complete End-to-End Critical Workflow Verification (Admin -> Manager -> Worker -> Chalan -> Completion -> Notification -> Audit Logs)")
    void executeCompleteOperationalLifecycle() {
        // ==========================================
        // 1. AUTHENTICATION & ADMIN INITIALIZATION
        // ==========================================
        User admin = User.builder()
                .name("Super Admin")
                .email("admin@door.local")
                .password(passwordEncoder.encode("adminpass"))
                .role(UserRole.ADMIN)
                .isActive(true)
                .build();
        userRepository.save(admin);

        // 1a. Successful Login & JWT receipt
        String adminToken = login("admin@door.local", "adminpass");
        assertThat(adminToken).isNotBlank();

        // 1b. Protected endpoint with valid JWT
        ResponseEntity<List<ProcessStepResponse>> initialStepsResp = restTemplate.exchange(
                baseUrl() + "/admin/process-steps",
                HttpMethod.GET,
                new HttpEntity<>(authHeaders(adminToken)),
                new ParameterizedTypeReference<>() {}
        );
        assertThat(initialStepsResp.getStatusCode()).isEqualTo(HttpStatus.OK);

        // 1c. Invalid / missing JWT returns 401
        ResponseEntity<String> unauthResp = restTemplate.getForEntity(baseUrl() + "/admin/process-steps", String.class);
        assertThat(unauthResp.getStatusCode()).isEqualTo(HttpStatus.UNAUTHORIZED);

        // ==========================================
        // 2. ADMIN: CREATE USERS & PROCESS STEPS
        // ==========================================
        // Create Manager
        var createMgrReq = new CreateUserRequest("Alice Manager", "alice@door.local", "mgrpass123", UserRole.MANAGER);
        ResponseEntity<UserResponse> mgrResp = restTemplate.exchange(
                baseUrl() + "/admin/users",
                HttpMethod.POST,
                new HttpEntity<>(createMgrReq, authHeaders(adminToken)),
                UserResponse.class
        );
        assertThat(mgrResp.getStatusCode()).isEqualTo(HttpStatus.OK);

        // Create Worker
        var createWrkReq = new CreateUserRequest("Bob Worker", "bob@door.local", "wrkpass123", UserRole.WORKER);
        ResponseEntity<UserResponse> wrkResp = restTemplate.exchange(
                baseUrl() + "/admin/users",
                HttpMethod.POST,
                new HttpEntity<>(createWrkReq, authHeaders(adminToken)),
                UserResponse.class
        );
        assertThat(wrkResp.getStatusCode()).isEqualTo(HttpStatus.OK);

        // Create Master Process Steps
        var step1Req = new CreateProcessStepRequest("Cutting & Sizing", 1);
        var step2Req = new CreateProcessStepRequest("Assembly & Polishing", 2);
        ResponseEntity<ProcessStepResponse> s1Resp = restTemplate.exchange(
                baseUrl() + "/admin/process-steps",
                HttpMethod.POST,
                new HttpEntity<>(step1Req, authHeaders(adminToken)),
                ProcessStepResponse.class
        );
        ResponseEntity<ProcessStepResponse> s2Resp = restTemplate.exchange(
                baseUrl() + "/admin/process-steps",
                HttpMethod.POST,
                new HttpEntity<>(step2Req, authHeaders(adminToken)),
                ProcessStepResponse.class
        );
        assertThat(s1Resp.getStatusCode()).isEqualTo(HttpStatus.OK);
        assertThat(s2Resp.getStatusCode()).isEqualTo(HttpStatus.OK);

        // Retrieve process steps
        ResponseEntity<List<ProcessStepResponse>> allStepsResp = restTemplate.exchange(
                baseUrl() + "/admin/process-steps",
                HttpMethod.GET,
                new HttpEntity<>(authHeaders(adminToken)),
                new ParameterizedTypeReference<>() {}
        );
        assertThat(allStepsResp.getBody()).hasSize(2);

        // ==========================================
        // 3. MANAGER: LOGIN & CREATE JOB
        // ==========================================
        String managerToken = login("alice@door.local", "mgrpass123");
        var createJobReq = new CreateJobRequest("JOB-E2E-101", "Acme Door Corp");
        ResponseEntity<JobResponse> jobResp = restTemplate.exchange(
                baseUrl() + "/manager/jobs",
                HttpMethod.POST,
                new HttpEntity<>(createJobReq, authHeaders(managerToken)),
                JobResponse.class
        );
        assertThat(jobResp.getStatusCode()).isEqualTo(HttpStatus.OK);
        JobResponse createdJob = jobResp.getBody();
        assertThat(createdJob).isNotNull();
        assertThat(createdJob.status()).isEqualTo(JobStatus.IN_PROGRESS);
        assertThat(createdJob.steps()).hasSize(2);
        assertThat(createdJob.steps().get(0).stepName()).isEqualTo("Cutting & Sizing");
        assertThat(createdJob.steps().get(1).stepName()).isEqualTo("Assembly & Polishing");

        var step1 = createdJob.steps().get(0);
        var step2 = createdJob.steps().get(1);

        // ==========================================
        // 4. WORKER: SEQUENTIAL EXECUTION & RULES
        // ==========================================
        String workerToken = login("bob@door.local", "wrkpass123");

        // 4a. Worker retrieves active jobs
        ResponseEntity<List<JobResponse>> activeJobsResp = restTemplate.exchange(
                baseUrl() + "/worker/jobs",
                HttpMethod.GET,
                new HttpEntity<>(authHeaders(workerToken)),
                new ParameterizedTypeReference<>() {}
        );
        assertThat(activeJobsResp.getBody()).hasSize(1);
        assertThat(activeJobsResp.getBody().get(0).jobNumber()).isEqualTo("JOB-E2E-101");

        // 4b. Completing step 2 out of order is rejected
        ResponseEntity<String> outOfOrderResp = restTemplate.exchange(
                baseUrl() + "/worker/job-steps/" + step2.id() + "/complete",
                HttpMethod.PUT,
                new HttpEntity<>(authHeaders(workerToken)),
                String.class
        );
        assertThat(outOfOrderResp.getStatusCode()).isEqualTo(HttpStatus.BAD_REQUEST);

        // 4c. Complete Step 1
        ResponseEntity<JobResponse> comp1Resp = restTemplate.exchange(
                baseUrl() + "/worker/job-steps/" + step1.id() + "/complete",
                HttpMethod.PUT,
                new HttpEntity<>(authHeaders(workerToken)),
                JobResponse.class
        );
        assertThat(comp1Resp.getStatusCode()).isEqualTo(HttpStatus.OK);

        // 4d. Complete Step 2 -> transitions Job status to WORK_DONE
        ResponseEntity<JobResponse> comp2Resp = restTemplate.exchange(
                baseUrl() + "/worker/job-steps/" + step2.id() + "/complete",
                HttpMethod.PUT,
                new HttpEntity<>(authHeaders(workerToken)),
                JobResponse.class
        );
        assertThat(comp2Resp.getStatusCode()).isEqualTo(HttpStatus.OK);
        assertThat(comp2Resp.getBody().status()).isEqualTo(JobStatus.WORK_DONE);

        // ==========================================
        // 5. CHALAN & FINAL COMPLETION
        // ==========================================
        // 5a. Record dispatch chalan
        var chalanReq = new AddChalanRequest("CHALAN-9988");
        ResponseEntity<JobResponse> chalanResp = restTemplate.exchange(
                baseUrl() + "/worker/jobs/" + createdJob.id() + "/chalan",
                HttpMethod.PUT,
                new HttpEntity<>(chalanReq, authHeaders(workerToken)),
                JobResponse.class
        );
        assertThat(chalanResp.getStatusCode()).isEqualTo(HttpStatus.OK);
        assertThat(chalanResp.getBody().chalanNumber()).isEqualTo("CHALAN-9988");

        // 5b. Final complete -> transitions Job status to JOB_COMPLETED
        ResponseEntity<JobResponse> finalCompResp = restTemplate.exchange(
                baseUrl() + "/worker/jobs/" + createdJob.id() + "/complete",
                HttpMethod.PUT,
                new HttpEntity<>(authHeaders(workerToken)),
                JobResponse.class
        );
        assertThat(finalCompResp.getStatusCode()).isEqualTo(HttpStatus.OK);
        assertThat(finalCompResp.getBody().status()).isEqualTo(JobStatus.JOB_COMPLETED);
        assertThat(finalCompResp.getBody().completedAt()).isNotNull();

        // ==========================================
        // 6. MANAGER NOTIFICATIONS
        // ==========================================
        ResponseEntity<List<NotificationResponse>> notifResp = restTemplate.exchange(
                baseUrl() + "/notifications",
                HttpMethod.GET,
                new HttpEntity<>(authHeaders(managerToken)),
                new ParameterizedTypeReference<>() {}
        );
        assertThat(notifResp.getStatusCode()).isEqualTo(HttpStatus.OK);
        List<NotificationResponse> notifs = notifResp.getBody();
        assertThat(notifs).isNotEmpty();
        assertThat(notifs.get(0).isRead()).isFalse();

        // Mark notification as read
        ResponseEntity<NotificationResponse> readResp = restTemplate.exchange(
                baseUrl() + "/notifications/" + notifs.get(0).id() + "/read",
                HttpMethod.PUT,
                new HttpEntity<>(authHeaders(managerToken)),
                NotificationResponse.class
        );
        assertThat(readResp.getStatusCode()).isEqualTo(HttpStatus.OK);
        assertThat(readResp.getBody().isRead()).isTrue();

        // ==========================================
        // 7. AUDIT LOGS
        // ==========================================
        ResponseEntity<List<JobStepHistoryResponse>> mgrLogsResp = restTemplate.exchange(
                baseUrl() + "/manager/jobs/logs",
                HttpMethod.GET,
                new HttpEntity<>(authHeaders(managerToken)),
                new ParameterizedTypeReference<>() {}
        );
        assertThat(mgrLogsResp.getStatusCode()).isEqualTo(HttpStatus.OK);
        assertThat(mgrLogsResp.getBody()).isNotEmpty();

        ResponseEntity<List<JobStepHistoryResponse>> adminLogsResp = restTemplate.exchange(
                baseUrl() + "/admin/logs",
                HttpMethod.GET,
                new HttpEntity<>(authHeaders(adminToken)),
                new ParameterizedTypeReference<>() {}
        );
        assertThat(adminLogsResp.getStatusCode()).isEqualTo(HttpStatus.OK);
        assertThat(adminLogsResp.getBody()).isNotEmpty();
    }
}
