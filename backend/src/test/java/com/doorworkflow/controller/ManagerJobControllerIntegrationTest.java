package com.doorworkflow.controller;

import com.doorworkflow.config.TestRestTemplateConfig;
import com.doorworkflow.dto.request.CreateJobRequest;
import com.doorworkflow.dto.request.ReopenJobRequest;
import com.doorworkflow.dto.response.JobResponse;
import com.doorworkflow.dto.response.JobStepHistoryResponse;
import com.doorworkflow.dto.response.JobStepResponse;
import com.doorworkflow.entity.Job;
import com.doorworkflow.entity.JobStep;
import com.doorworkflow.entity.JobStepHistory;
import com.doorworkflow.entity.ProcessStep;
import com.doorworkflow.entity.User;
import com.doorworkflow.enums.JobStatus;
import com.doorworkflow.enums.JobStepAction;
import com.doorworkflow.enums.JobStepStatus;
import com.doorworkflow.enums.UserRole;
import com.doorworkflow.repository.JobRepository;
import com.doorworkflow.repository.JobStepHistoryRepository;
import com.doorworkflow.repository.JobStepRepository;
import com.doorworkflow.repository.NotificationRepository;
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

import java.time.Instant;
import java.util.List;
import java.util.Map;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;

@Import(TestRestTemplateConfig.class)
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
class ManagerJobControllerIntegrationTest {

    @LocalServerPort
    private int port;

    @Autowired
    private TestRestTemplate restTemplate;

    @Autowired
    private UserRepository userRepository;

    @Autowired
    private JobRepository jobRepository;

    @Autowired
    private JobStepRepository jobStepRepository;

    @Autowired
    private JobStepHistoryRepository jobStepHistoryRepository;

    @Autowired
    private NotificationRepository notificationRepository;

    @Autowired
    private ProcessStepRepository processStepRepository;

    @Autowired
    private PasswordEncoder passwordEncoder;

    private String managerToken;
    private String adminToken;
    private String workerToken;
    private User managerUser;

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
        notificationRepository.deleteAll();
        jobStepHistoryRepository.deleteAll();
        jobStepRepository.deleteAll();
        jobRepository.deleteAll();
        processStepRepository.deleteAll();
        userRepository.deleteAll();

        // Create Manager
        managerUser = User.builder()
                .name("Manager Bob")
                .email("manager@test.local")
                .password(passwordEncoder.encode("manager123"))
                .role(UserRole.MANAGER)
                .isActive(true)
                .build();
        userRepository.save(managerUser);
        managerToken = login("manager@test.local", "manager123");

        // Create Admin
        User adminUser = User.builder()
                .name("Admin Alice")
                .email("admin@test.local")
                .password(passwordEncoder.encode("admin123"))
                .role(UserRole.ADMIN)
                .isActive(true)
                .build();
        userRepository.save(adminUser);
        adminToken = login("admin@test.local", "admin123");

        // Create Worker
        User workerUser = User.builder()
                .name("Worker Charlie")
                .email("worker@test.local")
                .password(passwordEncoder.encode("worker123"))
                .role(UserRole.WORKER)
                .isActive(true)
                .build();
        userRepository.save(workerUser);
        workerToken = login("worker@test.local", "worker123");
    }

    @Test
    @DisplayName("1. MANAGER can create a job -> 200 OK")
    void managerCanCreateJob() {
        CreateJobRequest request = new CreateJobRequest("JOB-100", "Acme Door Co");
        HttpEntity<CreateJobRequest> entity = new HttpEntity<>(request, authHeaders(managerToken));
        ResponseEntity<JobResponse> resp = restTemplate.exchange(baseUrl() + "/manager/jobs", HttpMethod.POST, entity, JobResponse.class);

        assertThat(resp.getStatusCode()).isEqualTo(HttpStatus.OK);
        JobResponse body = resp.getBody();
        assertThat(body).isNotNull();
        assertThat(body.jobNumber()).isEqualTo("JOB-100");
        assertThat(body.companyName()).isEqualTo("Acme Door Co");
        assertThat(body.status()).isEqualTo(JobStatus.IN_PROGRESS);
        assertThat(body.createdBy()).isEqualTo("Manager Bob");
        assertThat(body.id()).isNotNull();
    }

    @Test
    @DisplayName("2. MANAGER can list jobs")
    void managerCanListJobs() {
        // Create 2 jobs
        restTemplate.exchange(baseUrl() + "/manager/jobs", HttpMethod.POST,
                new HttpEntity<>(new CreateJobRequest("JOB-201", "Co 1"), authHeaders(managerToken)), JobResponse.class);
        restTemplate.exchange(baseUrl() + "/manager/jobs", HttpMethod.POST,
                new HttpEntity<>(new CreateJobRequest("JOB-202", "Co 2"), authHeaders(managerToken)), JobResponse.class);

        ResponseEntity<List<JobResponse>> resp = restTemplate.exchange(
                baseUrl() + "/manager/jobs",
                HttpMethod.GET,
                new HttpEntity<>(authHeaders(managerToken)),
                new ParameterizedTypeReference<List<JobResponse>>() {}
        );

        assertThat(resp.getStatusCode()).isEqualTo(HttpStatus.OK);
        List<JobResponse> jobs = resp.getBody();
        assertThat(jobs).hasSize(2);
        assertThat(jobs).extracting(JobResponse::jobNumber).contains("JOB-201", "JOB-202");
    }

    @Test
    @DisplayName("3. MANAGER can get a job by ID")
    void managerCanGetJobById() {
        ResponseEntity<JobResponse> created = restTemplate.exchange(baseUrl() + "/manager/jobs", HttpMethod.POST,
                new HttpEntity<>(new CreateJobRequest("JOB-301", "Single Co"), authHeaders(managerToken)), JobResponse.class);
        UUID jobId = created.getBody().id();

        ResponseEntity<JobResponse> resp = restTemplate.exchange(
                baseUrl() + "/manager/jobs/" + jobId,
                HttpMethod.GET,
                new HttpEntity<>(authHeaders(managerToken)),
                JobResponse.class
        );

        assertThat(resp.getStatusCode()).isEqualTo(HttpStatus.OK);
        assertThat(resp.getBody()).isNotNull();
        assertThat(resp.getBody().id()).isEqualTo(jobId);
        assertThat(resp.getBody().jobNumber()).isEqualTo("JOB-301");
        assertThat(resp.getBody().companyName()).isEqualTo("Single Co");
    }

    @Test
    @DisplayName("4. ADMIN receives 403 on manager jobs endpoints")
    void adminReceivesForbidden() {
        CreateJobRequest req = new CreateJobRequest("JOB-401", "Forbidden Co");
        ResponseEntity<String> postResp = restTemplate.exchange(
                baseUrl() + "/manager/jobs",
                HttpMethod.POST,
                new HttpEntity<>(req, authHeaders(adminToken)),
                String.class
        );
        assertThat(postResp.getStatusCode()).isEqualTo(HttpStatus.FORBIDDEN);

        ResponseEntity<String> getResp = restTemplate.exchange(
                baseUrl() + "/manager/jobs",
                HttpMethod.GET,
                new HttpEntity<>(authHeaders(adminToken)),
                String.class
        );
        assertThat(getResp.getStatusCode()).isEqualTo(HttpStatus.FORBIDDEN);
    }

    @Test
    @DisplayName("5. WORKER receives 403 on manager jobs endpoints")
    void workerReceivesForbidden() {
        CreateJobRequest req = new CreateJobRequest("JOB-501", "Worker Co");
        ResponseEntity<String> postResp = restTemplate.exchange(
                baseUrl() + "/manager/jobs",
                HttpMethod.POST,
                new HttpEntity<>(req, authHeaders(workerToken)),
                String.class
        );
        assertThat(postResp.getStatusCode()).isEqualTo(HttpStatus.FORBIDDEN);

        ResponseEntity<String> getResp = restTemplate.exchange(
                baseUrl() + "/manager/jobs",
                HttpMethod.GET,
                new HttpEntity<>(authHeaders(workerToken)),
                String.class
        );
        assertThat(getResp.getStatusCode()).isEqualTo(HttpStatus.FORBIDDEN);
    }

    @Test
    @DisplayName("6. Unauthenticated request receives 401")
    void unauthenticatedReceivesUnauthorized() {
        CreateJobRequest req = new CreateJobRequest("JOB-601", "Anon Co");
        HttpHeaders headers = new HttpHeaders();
        headers.setContentType(MediaType.APPLICATION_JSON);

        ResponseEntity<String> postResp = restTemplate.exchange(
                baseUrl() + "/manager/jobs",
                HttpMethod.POST,
                new HttpEntity<>(req, headers),
                String.class
        );
        assertThat(postResp.getStatusCode()).isEqualTo(HttpStatus.UNAUTHORIZED);

        ResponseEntity<String> getResp = restTemplate.exchange(
                baseUrl() + "/manager/jobs",
                HttpMethod.GET,
                new HttpEntity<>(headers),
                String.class
        );
        assertThat(getResp.getStatusCode()).isEqualTo(HttpStatus.UNAUTHORIZED);
    }

    @Test
    @DisplayName("7. Invalid create request receives 400")
    void invalidCreateRequestReceivesBadRequest() {
        // Blank jobNumber
        CreateJobRequest badReq = new CreateJobRequest("", "Valid Company");
        ResponseEntity<String> resp = restTemplate.exchange(
                baseUrl() + "/manager/jobs",
                HttpMethod.POST,
                new HttpEntity<>(badReq, authHeaders(managerToken)),
                String.class
        );
        assertThat(resp.getStatusCode()).isEqualTo(HttpStatus.BAD_REQUEST);

        // Blank companyName
        CreateJobRequest badReq2 = new CreateJobRequest("JOB-701", "   ");
        ResponseEntity<String> resp2 = restTemplate.exchange(
                baseUrl() + "/manager/jobs",
                HttpMethod.POST,
                new HttpEntity<>(badReq2, authHeaders(managerToken)),
                String.class
        );
        assertThat(resp2.getStatusCode()).isEqualTo(HttpStatus.BAD_REQUEST);
    }

    @Test
    @DisplayName("8. Duplicate job number receives 409")
    void duplicateJobNumberReceivesConflict() {
        CreateJobRequest req1 = new CreateJobRequest("JOB-DUP-1", "Company One");
        restTemplate.exchange(baseUrl() + "/manager/jobs", HttpMethod.POST,
                new HttpEntity<>(req1, authHeaders(managerToken)), JobResponse.class);

        CreateJobRequest req2 = new CreateJobRequest("JOB-DUP-1", "Company Two");
        ResponseEntity<String> resp = restTemplate.exchange(
                baseUrl() + "/manager/jobs",
                HttpMethod.POST,
                new HttpEntity<>(req2, authHeaders(managerToken)),
                String.class
        );
        assertThat(resp.getStatusCode()).isEqualTo(HttpStatus.CONFLICT);
    }

    @Test
    @DisplayName("9. Missing job ID receives 404")
    void missingJobIdReceivesNotFound() {
        ResponseEntity<String> resp = restTemplate.exchange(
                baseUrl() + "/manager/jobs/" + UUID.randomUUID(),
                HttpMethod.GET,
                new HttpEntity<>(authHeaders(managerToken)),
                String.class
        );
        assertThat(resp.getStatusCode()).isEqualTo(HttpStatus.NOT_FOUND);
    }

    @Test
    @DisplayName("10. createdBy is the authenticated manager, not client-controlled")
    void createdByIsAuthenticatedManager() {
        CreateJobRequest req = new CreateJobRequest("JOB-CREATOR", "Test Co");
        ResponseEntity<JobResponse> resp = restTemplate.exchange(
                baseUrl() + "/manager/jobs",
                HttpMethod.POST,
                new HttpEntity<>(req, authHeaders(managerToken)),
                JobResponse.class
        );

        assertThat(resp.getStatusCode()).isEqualTo(HttpStatus.OK);
        assertThat(resp.getBody().createdBy()).isEqualTo("Manager Bob");
    }

    @Test
    @DisplayName("11. Newly created job contains only active process steps in correct order")
    void newlyCreatedJobContainsOnlyActiveStepsInOrder() {
        ProcessStep s1 = ProcessStep.builder().name("Cutting").stepOrder(1).isActive(true).build();
        ProcessStep s2 = ProcessStep.builder().name("Old Inactive Step").stepOrder(2).isActive(false).build();
        ProcessStep s3 = ProcessStep.builder().name("Welding").stepOrder(2).isActive(true).build();
        processStepRepository.saveAll(List.of(s1, s2, s3));

        CreateJobRequest req = new CreateJobRequest("JOB-SNAPSHOT-ACTIVE", "Snapshot Corp");
        ResponseEntity<JobResponse> resp = restTemplate.exchange(
                baseUrl() + "/manager/jobs",
                HttpMethod.POST,
                new HttpEntity<>(req, authHeaders(managerToken)),
                JobResponse.class
        );

        assertThat(resp.getStatusCode()).isEqualTo(HttpStatus.OK);
        List<JobStepResponse> steps = resp.getBody().steps();
        assertThat(steps).hasSize(2);
        assertThat(steps).extracting(JobStepResponse::stepName, JobStepResponse::stepOrder, JobStepResponse::status)
                .containsExactly(
                        org.assertj.core.groups.Tuple.tuple("Cutting", 1, JobStepStatus.PENDING),
                        org.assertj.core.groups.Tuple.tuple("Welding", 2, JobStepStatus.PENDING)
                );
    }

    @Test
    @DisplayName("12. Job step snapshot remains independent from later master ProcessStep changes")
    void snapshotRemainsIndependentFromLaterProcessStepChanges() {
        ProcessStep s1 = ProcessStep.builder().name("Cutting").stepOrder(1).isActive(true).build();
        ProcessStep s2 = ProcessStep.builder().name("Bending").stepOrder(2).isActive(true).build();
        processStepRepository.saveAll(List.of(s1, s2));

        // Create Job #1704
        CreateJobRequest req = new CreateJobRequest("JOB-1704", "Independent Co");
        ResponseEntity<JobResponse> createResp = restTemplate.exchange(
                baseUrl() + "/manager/jobs",
                HttpMethod.POST,
                new HttpEntity<>(req, authHeaders(managerToken)),
                JobResponse.class
        );
        UUID createdJobId = createResp.getBody().id();

        // Later, master process steps are modified (renamed, added, or deactivated)
        s1.setName("Cutting v2 - Renamed");
        s1.setStepOrder(99);
        processStepRepository.save(s1);

        ProcessStep s3 = ProcessStep.builder().name("Finishing").stepOrder(3).isActive(true).build();
        processStepRepository.save(s3);

        // Fetch Job #1704 again
        ResponseEntity<JobResponse> getResp = restTemplate.exchange(
                baseUrl() + "/manager/jobs/" + createdJobId,
                HttpMethod.GET,
                new HttpEntity<>(authHeaders(managerToken)),
                JobResponse.class
        );

        assertThat(getResp.getStatusCode()).isEqualTo(HttpStatus.OK);
        List<JobStepResponse> steps = getResp.getBody().steps();
        assertThat(steps).hasSize(2);
        assertThat(steps).extracting(JobStepResponse::stepName, JobStepResponse::stepOrder)
                .containsExactly(
                        org.assertj.core.groups.Tuple.tuple("Cutting", 1),
                        org.assertj.core.groups.Tuple.tuple("Bending", 2)
                );
    }

    @Test
    @DisplayName("13. List endpoint returns jobs in a deterministic order (newest createdAt first)")
    void listEndpointReturnsJobsInDeterministicOrder() throws InterruptedException {
        restTemplate.exchange(baseUrl() + "/manager/jobs", HttpMethod.POST,
                new HttpEntity<>(new CreateJobRequest("JOB-FIRST", "Co A"), authHeaders(managerToken)), JobResponse.class);

        Thread.sleep(50); // slight delay to guarantee distinct createdAt timestamps

        restTemplate.exchange(baseUrl() + "/manager/jobs", HttpMethod.POST,
                new HttpEntity<>(new CreateJobRequest("JOB-SECOND", "Co B"), authHeaders(managerToken)), JobResponse.class);

        ResponseEntity<List<JobResponse>> resp = restTemplate.exchange(
                baseUrl() + "/manager/jobs",
                HttpMethod.GET,
                new HttpEntity<>(authHeaders(managerToken)),
                new ParameterizedTypeReference<List<JobResponse>>() {}
        );

        assertThat(resp.getStatusCode()).isEqualTo(HttpStatus.OK);
        List<JobResponse> jobs = resp.getBody();
        assertThat(jobs).hasSize(2);
        // Newest createdAt first
        assertThat(jobs.get(0).jobNumber()).isEqualTo("JOB-SECOND");
        assertThat(jobs.get(1).jobNumber()).isEqualTo("JOB-FIRST");
    }

    @Test
    @DisplayName("14. MANAGER can cancel IN_PROGRESS job -> returns CANCELLED")
    void managerCanCancelInProgressJob() {
        ResponseEntity<JobResponse> created = restTemplate.exchange(baseUrl() + "/manager/jobs", HttpMethod.POST,
                new HttpEntity<>(new CreateJobRequest("JOB-CANCEL-1", "Co"), authHeaders(managerToken)), JobResponse.class);
        UUID jobId = created.getBody().id();

        ResponseEntity<JobResponse> resp = restTemplate.exchange(
                baseUrl() + "/manager/jobs/" + jobId + "/cancel",
                HttpMethod.PUT,
                new HttpEntity<>(authHeaders(managerToken)),
                JobResponse.class
        );

        assertThat(resp.getStatusCode()).isEqualTo(HttpStatus.OK);
        assertThat(resp.getBody().status()).isEqualTo(JobStatus.CANCELLED);
    }

    @Test
    @DisplayName("15. Cannot cancel already CANCELLED job -> 400 Bad Request")
    void cannotCancelAlreadyCancelledJob() {
        ResponseEntity<JobResponse> created = restTemplate.exchange(baseUrl() + "/manager/jobs", HttpMethod.POST,
                new HttpEntity<>(new CreateJobRequest("JOB-CANCEL-2", "Co"), authHeaders(managerToken)), JobResponse.class);
        UUID jobId = created.getBody().id();

        // First cancel
        restTemplate.exchange(baseUrl() + "/manager/jobs/" + jobId + "/cancel", HttpMethod.PUT,
                new HttpEntity<>(authHeaders(managerToken)), JobResponse.class);

        // Second cancel
        ResponseEntity<String> resp = restTemplate.exchange(
                baseUrl() + "/manager/jobs/" + jobId + "/cancel",
                HttpMethod.PUT,
                new HttpEntity<>(authHeaders(managerToken)),
                String.class
        );

        assertThat(resp.getStatusCode()).isEqualTo(HttpStatus.BAD_REQUEST);
    }

    @Test
    @DisplayName("16. Cannot cancel WORK_DONE job -> 400 Bad Request")
    void cannotCancelWorkDoneJob() {
        ResponseEntity<JobResponse> created = restTemplate.exchange(baseUrl() + "/manager/jobs", HttpMethod.POST,
                new HttpEntity<>(new CreateJobRequest("JOB-CANCEL-3", "Co"), authHeaders(managerToken)), JobResponse.class);
        UUID jobId = created.getBody().id();

        // Simulate job completed
        Job job = jobRepository.findById(jobId).orElseThrow();
        job.setStatus(JobStatus.WORK_DONE);
        jobRepository.save(job);

        ResponseEntity<String> resp = restTemplate.exchange(
                baseUrl() + "/manager/jobs/" + jobId + "/cancel",
                HttpMethod.PUT,
                new HttpEntity<>(authHeaders(managerToken)),
                String.class
        );

        assertThat(resp.getStatusCode()).isEqualTo(HttpStatus.BAD_REQUEST);
    }

    @Test
    @DisplayName("17. Missing job on cancel returns 404")
    void missingJobOnCancelReturns404() {
        ResponseEntity<String> resp = restTemplate.exchange(
                baseUrl() + "/manager/jobs/" + UUID.randomUUID() + "/cancel",
                HttpMethod.PUT,
                new HttpEntity<>(authHeaders(managerToken)),
                String.class
        );
        assertThat(resp.getStatusCode()).isEqualTo(HttpStatus.NOT_FOUND);
    }

    @Test
    @DisplayName("18. MANAGER can reopen WORK_DONE job: resets target & later steps to PENDING, earlier stay COMPLETED, records history")
    void managerCanReopenWorkDoneJob() {
        ProcessStep p1 = ProcessStep.builder().name("Step 1").stepOrder(1).isActive(true).build();
        ProcessStep p2 = ProcessStep.builder().name("Step 2").stepOrder(2).isActive(true).build();
        ProcessStep p3 = ProcessStep.builder().name("Step 3").stepOrder(3).isActive(true).build();
        processStepRepository.saveAll(List.of(p1, p2, p3));

        ResponseEntity<JobResponse> created = restTemplate.exchange(baseUrl() + "/manager/jobs", HttpMethod.POST,
                new HttpEntity<>(new CreateJobRequest("JOB-REOPEN-1", "Co"), authHeaders(managerToken)), JobResponse.class);
        UUID jobId = created.getBody().id();

        // Mark all steps COMPLETED and job WORK_DONE
        Job job = jobRepository.findById(jobId).orElseThrow();
        job.setStatus(JobStatus.WORK_DONE);
        job.setCompletedAt(java.time.Instant.now());
        jobRepository.save(job);

        List<JobStep> steps = jobStepRepository.findByJobIdOrderByStepOrderAsc(jobId);
        for (JobStep s : steps) {
            s.setStatus(JobStepStatus.COMPLETED);
            s.setCompletedBy(managerUser);
            s.setCompletedAt(java.time.Instant.now());
        }
        jobStepRepository.saveAll(steps);

        // Reopen from Step 2
        UUID step2Id = steps.get(1).getId();
        ReopenJobRequest reopenReq = new ReopenJobRequest(step2Id);

        ResponseEntity<JobResponse> resp = restTemplate.exchange(
                baseUrl() + "/manager/jobs/" + jobId + "/reopen",
                HttpMethod.PUT,
                new HttpEntity<>(reopenReq, authHeaders(managerToken)),
                JobResponse.class
        );

        assertThat(resp.getStatusCode()).isEqualTo(HttpStatus.OK);
        JobResponse reopenedJob = resp.getBody();
        assertThat(reopenedJob.status()).isEqualTo(JobStatus.IN_PROGRESS);
        assertThat(reopenedJob.completedAt()).isNull();

        List<JobStepResponse> reopenedSteps = reopenedJob.steps();
        // Step 1 remains COMPLETED
        assertThat(reopenedSteps.get(0).status()).isEqualTo(JobStepStatus.COMPLETED);
        assertThat(reopenedSteps.get(0).completedBy()).isEqualTo("Manager Bob");
        // Step 2 reset to PENDING
        assertThat(reopenedSteps.get(1).status()).isEqualTo(JobStepStatus.PENDING);
        assertThat(reopenedSteps.get(1).completedBy()).isNull();
        assertThat(reopenedSteps.get(1).completedAt()).isNull();
        // Step 3 reset to PENDING
        assertThat(reopenedSteps.get(2).status()).isEqualTo(JobStepStatus.PENDING);
        assertThat(reopenedSteps.get(2).completedBy()).isNull();
        assertThat(reopenedSteps.get(2).completedAt()).isNull();

        // Check JobStepHistory recorded
        List<JobStepHistory> historyList = jobStepHistoryRepository.findByJobId(jobId);
        assertThat(historyList).hasSize(1);
        JobStepHistory entry = historyList.get(0);
        assertThat(entry.getAction()).isEqualTo(JobStepAction.REOPENED);
        assertThat(entry.getJobStep().getId()).isEqualTo(step2Id);
        assertThat(entry.getPerformedBy().getId()).isEqualTo(managerUser.getId());
        assertThat(entry.getCreatedAt()).isNotNull();
    }

    @Test
    @DisplayName("19. Reopen requires valid stepId -> 400 when null")
    void reopenRequiresStepId() {
        ResponseEntity<JobResponse> created = restTemplate.exchange(baseUrl() + "/manager/jobs", HttpMethod.POST,
                new HttpEntity<>(new CreateJobRequest("JOB-REOPEN-2", "Co"), authHeaders(managerToken)), JobResponse.class);
        UUID jobId = created.getBody().id();

        String bodyWithNull = "{\"stepId\": null}";
        HttpHeaders headers = authHeaders(managerToken);
        ResponseEntity<String> resp = restTemplate.exchange(
                baseUrl() + "/manager/jobs/" + jobId + "/reopen",
                HttpMethod.PUT,
                new HttpEntity<>(bodyWithNull, headers),
                String.class
        );

        assertThat(resp.getStatusCode()).isEqualTo(HttpStatus.BAD_REQUEST);
    }

    @Test
    @DisplayName("20. Supplied stepId must belong to the job -> 400 Bad Request")
    void suppliedStepIdMustBelongToJob() {
        ResponseEntity<JobResponse> created = restTemplate.exchange(baseUrl() + "/manager/jobs", HttpMethod.POST,
                new HttpEntity<>(new CreateJobRequest("JOB-REOPEN-3", "Co"), authHeaders(managerToken)), JobResponse.class);
        UUID jobId = created.getBody().id();

        Job job = jobRepository.findById(jobId).orElseThrow();
        job.setStatus(JobStatus.WORK_DONE);
        jobRepository.save(job);

        ReopenJobRequest req = new ReopenJobRequest(UUID.randomUUID());
        ResponseEntity<String> resp = restTemplate.exchange(
                baseUrl() + "/manager/jobs/" + jobId + "/reopen",
                HttpMethod.PUT,
                new HttpEntity<>(req, authHeaders(managerToken)),
                String.class
        );

        assertThat(resp.getStatusCode()).isEqualTo(HttpStatus.BAD_REQUEST);
    }

    @Test
    @DisplayName("21. Cannot reopen IN_PROGRESS or CANCELLED job -> 400 Bad Request")
    void cannotReopenInProgressOrCancelledJob() {
        ProcessStep p1 = ProcessStep.builder().name("Step 1").stepOrder(1).isActive(true).build();
        processStepRepository.save(p1);

        ResponseEntity<JobResponse> created = restTemplate.exchange(baseUrl() + "/manager/jobs", HttpMethod.POST,
                new HttpEntity<>(new CreateJobRequest("JOB-REOPEN-4", "Co"), authHeaders(managerToken)), JobResponse.class);
        UUID jobId = created.getBody().id();
        UUID stepId = created.getBody().steps().get(0).id();

        // 1. IN_PROGRESS job reopen attempt
        ReopenJobRequest req = new ReopenJobRequest(stepId);
        ResponseEntity<String> inProgResp = restTemplate.exchange(
                baseUrl() + "/manager/jobs/" + jobId + "/reopen",
                HttpMethod.PUT,
                new HttpEntity<>(req, authHeaders(managerToken)),
                String.class
        );
        assertThat(inProgResp.getStatusCode()).isEqualTo(HttpStatus.BAD_REQUEST);

        // 2. Cancel job, then CANCELLED job reopen attempt
        restTemplate.exchange(baseUrl() + "/manager/jobs/" + jobId + "/cancel", HttpMethod.PUT,
                new HttpEntity<>(authHeaders(managerToken)), JobResponse.class);

        ResponseEntity<String> cancelResp = restTemplate.exchange(
                baseUrl() + "/manager/jobs/" + jobId + "/reopen",
                HttpMethod.PUT,
                new HttpEntity<>(req, authHeaders(managerToken)),
                String.class
        );
        assertThat(cancelResp.getStatusCode()).isEqualTo(HttpStatus.BAD_REQUEST);
    }

    @Test
    @DisplayName("22. Missing job on reopen returns 404")
    void missingJobOnReopenReturns404() {
        ReopenJobRequest req = new ReopenJobRequest(UUID.randomUUID());
        ResponseEntity<String> resp = restTemplate.exchange(
                baseUrl() + "/manager/jobs/" + UUID.randomUUID() + "/reopen",
                HttpMethod.PUT,
                new HttpEntity<>(req, authHeaders(managerToken)),
                String.class
        );
        assertThat(resp.getStatusCode()).isEqualTo(HttpStatus.NOT_FOUND);
    }

    @Test
    @DisplayName("23. Security: ADMIN and WORKER receive 403 on cancel and reopen; Unauthenticated receives 401")
    void securityForCancelAndReopen() {
        ResponseEntity<JobResponse> created = restTemplate.exchange(baseUrl() + "/manager/jobs", HttpMethod.POST,
                new HttpEntity<>(new CreateJobRequest("JOB-SEC-1", "Co"), authHeaders(managerToken)), JobResponse.class);
        UUID jobId = created.getBody().id();
        ReopenJobRequest reopenReq = new ReopenJobRequest(UUID.randomUUID());

        // ADMIN -> 403
        assertThat(restTemplate.exchange(baseUrl() + "/manager/jobs/" + jobId + "/cancel", HttpMethod.PUT,
                new HttpEntity<>(authHeaders(adminToken)), String.class).getStatusCode()).isEqualTo(HttpStatus.FORBIDDEN);
        assertThat(restTemplate.exchange(baseUrl() + "/manager/jobs/" + jobId + "/reopen", HttpMethod.PUT,
                new HttpEntity<>(reopenReq, authHeaders(adminToken)), String.class).getStatusCode()).isEqualTo(HttpStatus.FORBIDDEN);

        // WORKER -> 403
        assertThat(restTemplate.exchange(baseUrl() + "/manager/jobs/" + jobId + "/cancel", HttpMethod.PUT,
                new HttpEntity<>(authHeaders(workerToken)), String.class).getStatusCode()).isEqualTo(HttpStatus.FORBIDDEN);
        assertThat(restTemplate.exchange(baseUrl() + "/manager/jobs/" + jobId + "/reopen", HttpMethod.PUT,
                new HttpEntity<>(reopenReq, authHeaders(workerToken)), String.class).getStatusCode()).isEqualTo(HttpStatus.FORBIDDEN);

        // Unauthenticated -> 401
        HttpHeaders headers = new HttpHeaders();
        headers.setContentType(MediaType.APPLICATION_JSON);
        assertThat(restTemplate.exchange(baseUrl() + "/manager/jobs/" + jobId + "/cancel", HttpMethod.PUT,
                new HttpEntity<>(headers), String.class).getStatusCode()).isEqualTo(HttpStatus.UNAUTHORIZED);
        assertThat(restTemplate.exchange(baseUrl() + "/manager/jobs/" + jobId + "/reopen", HttpMethod.PUT,
                new HttpEntity<>(reopenReq, headers), String.class).getStatusCode()).isEqualTo(HttpStatus.UNAUTHORIZED);
    }

    @Test
    @DisplayName("24. Optimistic locking version field is preserved on JobStep")
    void optimisticLockingVersionPreserved() {
        ProcessStep p1 = ProcessStep.builder().name("Step 1").stepOrder(1).isActive(true).build();
        processStepRepository.save(p1);

        ResponseEntity<JobResponse> created = restTemplate.exchange(baseUrl() + "/manager/jobs", HttpMethod.POST,
                new HttpEntity<>(new CreateJobRequest("JOB-OPT-1", "Co"), authHeaders(managerToken)), JobResponse.class);
        UUID jobId = created.getBody().id();

        JobStep step = jobStepRepository.findByJobIdOrderByStepOrderAsc(jobId).get(0);
        assertThat(step.getVersion()).isNotNull();
        assertThat(step.getVersion()).isGreaterThanOrEqualTo(0L);
    }

    @Test
    @DisplayName("25. MANAGER can retrieve job logs (all logs and job-specific logs in newest-first order)")
    void managerCanRetrieveJobLogs() {
        ProcessStep p1 = ProcessStep.builder().name("Step 1").stepOrder(1).isActive(true).build();
        processStepRepository.save(p1);

        ResponseEntity<JobResponse> created = restTemplate.exchange(baseUrl() + "/manager/jobs", HttpMethod.POST,
                new HttpEntity<>(new CreateJobRequest("JOB-LOG-1", "Co"), authHeaders(managerToken)), JobResponse.class);
        UUID jobId = created.getBody().id();
        UUID stepId = created.getBody().steps().get(0).id();

        // Mark job completed, then reopen -> creates REOPENED history
        Job job = jobRepository.findById(jobId).orElseThrow();
        job.setStatus(JobStatus.WORK_DONE);
        jobRepository.save(job);

        restTemplate.exchange(baseUrl() + "/manager/jobs/" + jobId + "/reopen", HttpMethod.PUT,
                new HttpEntity<>(new ReopenJobRequest(stepId), authHeaders(managerToken)), JobResponse.class);

        // Fetch logs for this job
        ResponseEntity<List<JobStepHistoryResponse>> jobLogsResp = restTemplate.exchange(
                baseUrl() + "/manager/jobs/" + jobId + "/logs",
                HttpMethod.GET,
                new HttpEntity<>(authHeaders(managerToken)),
                new ParameterizedTypeReference<List<JobStepHistoryResponse>>() {}
        );

        assertThat(jobLogsResp.getStatusCode()).isEqualTo(HttpStatus.OK);
        List<JobStepHistoryResponse> logs = jobLogsResp.getBody();
        assertThat(logs).hasSize(1);
        assertThat(logs.get(0).action()).isEqualTo(JobStepAction.REOPENED);
        assertThat(logs.get(0).stepName()).isEqualTo("Step 1");
        assertThat(logs.get(0).performedBy()).isEqualTo("Manager Bob");

        // Fetch all logs
        ResponseEntity<List<JobStepHistoryResponse>> allLogsResp = restTemplate.exchange(
                baseUrl() + "/manager/jobs/logs",
                HttpMethod.GET,
                new HttpEntity<>(authHeaders(managerToken)),
                new ParameterizedTypeReference<List<JobStepHistoryResponse>>() {}
        );
        assertThat(allLogsResp.getStatusCode()).isEqualTo(HttpStatus.OK);
        assertThat(allLogsResp.getBody()).isNotEmpty();
    }

    @Test
    @DisplayName("26. Job logs missing job returns 404")
    void jobLogsMissingJobReturns404() {
        ResponseEntity<String> resp = restTemplate.exchange(
                baseUrl() + "/manager/jobs/" + UUID.randomUUID() + "/logs",
                HttpMethod.GET,
                new HttpEntity<>(authHeaders(managerToken)),
                String.class
        );
        assertThat(resp.getStatusCode()).isEqualTo(HttpStatus.NOT_FOUND);
    }

    @Test
    @DisplayName("27. Job logs security: ADMIN and WORKER receive 403; Unauthenticated receives 401")
    void jobLogsSecurity() {
        ResponseEntity<JobResponse> created = restTemplate.exchange(baseUrl() + "/manager/jobs", HttpMethod.POST,
                new HttpEntity<>(new CreateJobRequest("JOB-LOG-SEC", "Co"), authHeaders(managerToken)), JobResponse.class);
        UUID jobId = created.getBody().id();

        // ADMIN -> 403
        assertThat(restTemplate.exchange(baseUrl() + "/manager/jobs/logs", HttpMethod.GET,
                new HttpEntity<>(authHeaders(adminToken)), String.class).getStatusCode()).isEqualTo(HttpStatus.FORBIDDEN);
        assertThat(restTemplate.exchange(baseUrl() + "/manager/jobs/" + jobId + "/logs", HttpMethod.GET,
                new HttpEntity<>(authHeaders(adminToken)), String.class).getStatusCode()).isEqualTo(HttpStatus.FORBIDDEN);

        // WORKER -> 403
        assertThat(restTemplate.exchange(baseUrl() + "/manager/jobs/logs", HttpMethod.GET,
                new HttpEntity<>(authHeaders(workerToken)), String.class).getStatusCode()).isEqualTo(HttpStatus.FORBIDDEN);
        assertThat(restTemplate.exchange(baseUrl() + "/manager/jobs/" + jobId + "/logs", HttpMethod.GET,
                new HttpEntity<>(authHeaders(workerToken)), String.class).getStatusCode()).isEqualTo(HttpStatus.FORBIDDEN);

        // Unauthenticated -> 401
        HttpHeaders headers = new HttpHeaders();
        assertThat(restTemplate.exchange(baseUrl() + "/manager/jobs/logs", HttpMethod.GET,
                new HttpEntity<>(headers), String.class).getStatusCode()).isEqualTo(HttpStatus.UNAUTHORIZED);
        assertThat(restTemplate.exchange(baseUrl() + "/manager/jobs/" + jobId + "/logs", HttpMethod.GET,
                new HttpEntity<>(headers), String.class).getStatusCode()).isEqualTo(HttpStatus.UNAUTHORIZED);
    }
}
