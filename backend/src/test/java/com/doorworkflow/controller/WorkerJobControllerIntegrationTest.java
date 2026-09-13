package com.doorworkflow.controller;

import com.doorworkflow.config.TestRestTemplateConfig;
import com.doorworkflow.dto.request.CreateJobRequest;
import com.doorworkflow.dto.response.JobResponse;
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
class WorkerJobControllerIntegrationTest {

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

    private String workerToken;
    private String managerToken;
    private String adminToken;
    private User workerUser;
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

        // Worker
        workerUser = User.builder()
                .name("Worker Bob")
                .email("worker@test.local")
                .password(passwordEncoder.encode("worker123"))
                .role(UserRole.WORKER)
                .isActive(true)
                .build();
        userRepository.save(workerUser);
        workerToken = login("worker@test.local", "worker123");

        // Manager
        managerUser = User.builder()
                .name("Manager Alice")
                .email("manager@test.local")
                .password(passwordEncoder.encode("manager123"))
                .role(UserRole.MANAGER)
                .isActive(true)
                .build();
        userRepository.save(managerUser);
        managerToken = login("manager@test.local", "manager123");

        // Admin
        User adminUser = User.builder()
                .name("Admin Charlie")
                .email("admin@test.local")
                .password(passwordEncoder.encode("admin123"))
                .role(UserRole.ADMIN)
                .isActive(true)
                .build();
        userRepository.save(adminUser);
        adminToken = login("admin@test.local", "admin123");
    }

    private Job createJobWithSteps(String jobNumber, String... stepNames) {
        Job job = Job.builder()
                .jobNumber(jobNumber)
                .companyName("Acme Co")
                .status(JobStatus.IN_PROGRESS)
                .createdBy(managerUser)
                .build();
        Job savedJob = jobRepository.save(job);

        for (int i = 0; i < stepNames.length; i++) {
            JobStep step = JobStep.builder()
                    .job(savedJob)
                    .stepName(stepNames[i])
                    .stepOrder(i + 1)
                    .status(JobStepStatus.PENDING)
                    .build();
            jobStepRepository.save(step);
        }
        return savedJob;
    }

    @Test
    @DisplayName("1. WORKER can list IN_PROGRESS jobs")
    void workerCanListInProgressJobs() {
        createJobWithSteps("JOB-ACT-1", "Step 1");
        createJobWithSteps("JOB-ACT-2", "Step 1");

        ResponseEntity<List<JobResponse>> resp = restTemplate.exchange(
                baseUrl() + "/worker/jobs",
                HttpMethod.GET,
                new HttpEntity<>(authHeaders(workerToken)),
                new ParameterizedTypeReference<List<JobResponse>>() {}
        );

        assertThat(resp.getStatusCode()).isEqualTo(HttpStatus.OK);
        assertThat(resp.getBody()).hasSize(2);
        assertThat(resp.getBody()).extracting(JobResponse::jobNumber).contains("JOB-ACT-1", "JOB-ACT-2");
    }

    @Test
    @DisplayName("2. WORKER cannot see CANCELLED or WORK_DONE jobs in active list")
    void workerCannotSeeCancelledOrWorkDoneJobs() {
        Job active = createJobWithSteps("JOB-ACT", "Step 1");

        Job cancelled = createJobWithSteps("JOB-CAN", "Step 1");
        cancelled.setStatus(JobStatus.CANCELLED);
        jobRepository.save(cancelled);

        Job workDone = createJobWithSteps("JOB-DONE", "Step 1");
        workDone.setStatus(JobStatus.WORK_DONE);
        jobRepository.save(workDone);

        ResponseEntity<List<JobResponse>> resp = restTemplate.exchange(
                baseUrl() + "/worker/jobs",
                HttpMethod.GET,
                new HttpEntity<>(authHeaders(workerToken)),
                new ParameterizedTypeReference<List<JobResponse>>() {}
        );

        assertThat(resp.getStatusCode()).isEqualTo(HttpStatus.OK);
        assertThat(resp.getBody()).hasSize(1);
        assertThat(resp.getBody().get(0).jobNumber()).isEqualTo("JOB-ACT");
    }

    @Test
    @DisplayName("3. WORKER can get an IN_PROGRESS job by ID with steps ordered")
    void workerCanGetJobById() {
        Job job = createJobWithSteps("JOB-GET", "Cutting", "Bending");

        ResponseEntity<JobResponse> resp = restTemplate.exchange(
                baseUrl() + "/worker/jobs/" + job.getId(),
                HttpMethod.GET,
                new HttpEntity<>(authHeaders(workerToken)),
                JobResponse.class
        );

        assertThat(resp.getStatusCode()).isEqualTo(HttpStatus.OK);
        assertThat(resp.getBody().jobNumber()).isEqualTo("JOB-GET");
        assertThat(resp.getBody().steps()).hasSize(2);
        assertThat(resp.getBody().steps()).extracting(JobStepResponse::stepOrder).containsExactly(1, 2);
    }

    @Test
    @DisplayName("4. WORKER can complete first pending step: records completedBy, completedAt, history")
    void workerCanCompleteFirstPendingStep() {
        Job job = createJobWithSteps("JOB-COMP-1", "Cutting", "Bending");
        List<JobStep> steps = jobStepRepository.findByJobIdOrderByStepOrderAsc(job.getId());
        UUID firstStepId = steps.get(0).getId();

        ResponseEntity<JobResponse> resp = restTemplate.exchange(
                baseUrl() + "/worker/job-steps/" + firstStepId + "/complete",
                HttpMethod.PUT,
                new HttpEntity<>(authHeaders(workerToken)),
                JobResponse.class
        );

        assertThat(resp.getStatusCode()).isEqualTo(HttpStatus.OK);
        JobResponse updatedJob = resp.getBody();
        assertThat(updatedJob.status()).isEqualTo(JobStatus.IN_PROGRESS);

        JobStepResponse step1Resp = updatedJob.steps().get(0);
        assertThat(step1Resp.status()).isEqualTo(JobStepStatus.COMPLETED);
        assertThat(step1Resp.completedBy()).isEqualTo("Worker Bob");
        assertThat(step1Resp.completedAt()).isNotNull();

        // History check
        List<JobStepHistory> historyList = jobStepHistoryRepository.findByJobId(job.getId());
        assertThat(historyList).hasSize(1);
        assertThat(historyList.get(0).getAction()).isEqualTo(JobStepAction.COMPLETED);
        assertThat(historyList.get(0).getJobStep().getId()).isEqualTo(firstStepId);
        assertThat(historyList.get(0).getPerformedBy().getId()).isEqualTo(workerUser.getId());
    }

    @Test
    @DisplayName("5. Cannot complete a later step before the current first pending step")
    void cannotCompleteLaterStepBeforeFirstPending() {
        Job job = createJobWithSteps("JOB-COMP-ORDER", "Cutting", "Bending");
        List<JobStep> steps = jobStepRepository.findByJobIdOrderByStepOrderAsc(job.getId());
        UUID secondStepId = steps.get(1).getId();

        ResponseEntity<String> resp = restTemplate.exchange(
                baseUrl() + "/worker/job-steps/" + secondStepId + "/complete",
                HttpMethod.PUT,
                new HttpEntity<>(authHeaders(workerToken)),
                String.class
        );

        assertThat(resp.getStatusCode()).isEqualTo(HttpStatus.BAD_REQUEST);
    }

    @Test
    @DisplayName("6. Cannot complete an already completed step")
    void cannotCompleteAlreadyCompletedStep() {
        Job job = createJobWithSteps("JOB-COMP-REPEAT", "Cutting", "Bending");
        List<JobStep> steps = jobStepRepository.findByJobIdOrderByStepOrderAsc(job.getId());
        UUID firstStepId = steps.get(0).getId();

        // First completion
        restTemplate.exchange(
                baseUrl() + "/worker/job-steps/" + firstStepId + "/complete",
                HttpMethod.PUT,
                new HttpEntity<>(authHeaders(workerToken)),
                JobResponse.class
        );

        // Repeated completion
        ResponseEntity<String> resp = restTemplate.exchange(
                baseUrl() + "/worker/job-steps/" + firstStepId + "/complete",
                HttpMethod.PUT,
                new HttpEntity<>(authHeaders(workerToken)),
                String.class
        );

        assertThat(resp.getStatusCode()).isEqualTo(HttpStatus.BAD_REQUEST);
    }

    @Test
    @DisplayName("7. Completing final step sets Job.status = WORK_DONE and Job.completedAt")
    void completingFinalStepFinishesJob() {
        Job job = createJobWithSteps("JOB-FINAL", "Cutting", "Welding");
        List<JobStep> steps = jobStepRepository.findByJobIdOrderByStepOrderAsc(job.getId());

        // Complete step 1
        restTemplate.exchange(
                baseUrl() + "/worker/job-steps/" + steps.get(0).getId() + "/complete",
                HttpMethod.PUT,
                new HttpEntity<>(authHeaders(workerToken)),
                JobResponse.class
        );

        // Complete step 2 (final step)
        ResponseEntity<JobResponse> resp = restTemplate.exchange(
                baseUrl() + "/worker/job-steps/" + steps.get(1).getId() + "/complete",
                HttpMethod.PUT,
                new HttpEntity<>(authHeaders(workerToken)),
                JobResponse.class
        );

        assertThat(resp.getStatusCode()).isEqualTo(HttpStatus.OK);
        assertThat(resp.getBody().status()).isEqualTo(JobStatus.WORK_DONE);
        assertThat(resp.getBody().completedAt()).isNotNull();

        Job inDb = jobRepository.findById(job.getId()).orElseThrow();
        assertThat(inDb.getStatus()).isEqualTo(JobStatus.WORK_DONE);
        assertThat(inDb.getCompletedAt()).isNotNull();
    }

    @Test
    @DisplayName("8. WORKER can undo latest completed step while IN_PROGRESS: resets step and records UNDONE history")
    void workerCanUndoLatestCompletedStep() {
        Job job = createJobWithSteps("JOB-UNDO-1", "Cutting", "Bending", "Welding");
        List<JobStep> steps = jobStepRepository.findByJobIdOrderByStepOrderAsc(job.getId());

        // Complete step 1 then step 2
        restTemplate.exchange(baseUrl() + "/worker/job-steps/" + steps.get(0).getId() + "/complete",
                HttpMethod.PUT, new HttpEntity<>(authHeaders(workerToken)), JobResponse.class);
        restTemplate.exchange(baseUrl() + "/worker/job-steps/" + steps.get(1).getId() + "/complete",
                HttpMethod.PUT, new HttpEntity<>(authHeaders(workerToken)), JobResponse.class);

        // Undo step 2 (latest completed)
        ResponseEntity<JobResponse> resp = restTemplate.exchange(
                baseUrl() + "/worker/job-steps/" + steps.get(1).getId() + "/undo",
                HttpMethod.PUT,
                new HttpEntity<>(authHeaders(workerToken)),
                JobResponse.class
        );

        assertThat(resp.getStatusCode()).isEqualTo(HttpStatus.OK);
        JobStepResponse step2Resp = resp.getBody().steps().get(1);
        assertThat(step2Resp.status()).isEqualTo(JobStepStatus.PENDING);
        assertThat(step2Resp.completedBy()).isNull();
        assertThat(step2Resp.completedAt()).isNull();

        // Check history includes UNDONE
        List<JobStepHistory> histories = jobStepHistoryRepository.findByJobId(job.getId());
        assertThat(histories).hasSize(3); // completed step1, completed step2, undone step2
        JobStepHistory lastHistory = histories.get(2);
        assertThat(lastHistory.getAction()).isEqualTo(JobStepAction.UNDONE);
        assertThat(lastHistory.getJobStep().getId()).isEqualTo(steps.get(1).getId());
        assertThat(lastHistory.getPerformedBy().getId()).isEqualTo(workerUser.getId());
    }

    @Test
    @DisplayName("9. Cannot undo an earlier step while a later step remains completed")
    void cannotUndoEarlierStepWhileLaterCompleted() {
        Job job = createJobWithSteps("JOB-UNDO-ORDER", "Cutting", "Bending");
        List<JobStep> steps = jobStepRepository.findByJobIdOrderByStepOrderAsc(job.getId());

        // Complete step 1 then step 2
        restTemplate.exchange(baseUrl() + "/worker/job-steps/" + steps.get(0).getId() + "/complete",
                HttpMethod.PUT, new HttpEntity<>(authHeaders(workerToken)), JobResponse.class);
        restTemplate.exchange(baseUrl() + "/worker/job-steps/" + steps.get(1).getId() + "/complete",
                HttpMethod.PUT, new HttpEntity<>(authHeaders(workerToken)), JobResponse.class);

        // Attempt to undo step 1 while step 2 is completed
        ResponseEntity<String> resp = restTemplate.exchange(
                baseUrl() + "/worker/job-steps/" + steps.get(0).getId() + "/undo",
                HttpMethod.PUT,
                new HttpEntity<>(authHeaders(workerToken)),
                String.class
        );

        assertThat(resp.getStatusCode()).isEqualTo(HttpStatus.BAD_REQUEST);
    }

    @Test
    @DisplayName("10. Cannot undo a step when job is WORK_DONE")
    void cannotUndoWorkDoneJob() {
        Job job = createJobWithSteps("JOB-UNDO-DONE", "Cutting");
        List<JobStep> steps = jobStepRepository.findByJobIdOrderByStepOrderAsc(job.getId());

        // Complete only step -> job becomes WORK_DONE
        restTemplate.exchange(baseUrl() + "/worker/job-steps/" + steps.get(0).getId() + "/complete",
                HttpMethod.PUT, new HttpEntity<>(authHeaders(workerToken)), JobResponse.class);

        // Attempt undo
        ResponseEntity<String> resp = restTemplate.exchange(
                baseUrl() + "/worker/job-steps/" + steps.get(0).getId() + "/undo",
                HttpMethod.PUT,
                new HttpEntity<>(authHeaders(workerToken)),
                String.class
        );

        assertThat(resp.getStatusCode()).isEqualTo(HttpStatus.BAD_REQUEST);
    }

    @Test
    @DisplayName("11. Cannot complete or undo step in a CANCELLED job")
    void cannotModifyCancelledJob() {
        Job job = createJobWithSteps("JOB-CAN-MOD", "Cutting", "Bending");
        List<JobStep> steps = jobStepRepository.findByJobIdOrderByStepOrderAsc(job.getId());

        job.setStatus(JobStatus.CANCELLED);
        jobRepository.save(job);

        // Complete attempt
        ResponseEntity<String> compResp = restTemplate.exchange(
                baseUrl() + "/worker/job-steps/" + steps.get(0).getId() + "/complete",
                HttpMethod.PUT,
                new HttpEntity<>(authHeaders(workerToken)),
                String.class
        );
        assertThat(compResp.getStatusCode()).isEqualTo(HttpStatus.BAD_REQUEST);

        // Undo attempt
        ResponseEntity<String> undoResp = restTemplate.exchange(
                baseUrl() + "/worker/job-steps/" + steps.get(0).getId() + "/undo",
                HttpMethod.PUT,
                new HttpEntity<>(authHeaders(workerToken)),
                String.class
        );
        assertThat(undoResp.getStatusCode()).isEqualTo(HttpStatus.BAD_REQUEST);
    }

    @Test
    @DisplayName("12. Missing job or step returns 404")
    void missingJobOrStepReturns404() {
        ResponseEntity<String> jobResp = restTemplate.exchange(
                baseUrl() + "/worker/jobs/" + UUID.randomUUID(),
                HttpMethod.GET,
                new HttpEntity<>(authHeaders(workerToken)),
                String.class
        );
        assertThat(jobResp.getStatusCode()).isEqualTo(HttpStatus.NOT_FOUND);

        ResponseEntity<String> compResp = restTemplate.exchange(
                baseUrl() + "/worker/job-steps/" + UUID.randomUUID() + "/complete",
                HttpMethod.PUT,
                new HttpEntity<>(authHeaders(workerToken)),
                String.class
        );
        assertThat(compResp.getStatusCode()).isEqualTo(HttpStatus.NOT_FOUND);

        ResponseEntity<String> undoResp = restTemplate.exchange(
                baseUrl() + "/worker/job-steps/" + UUID.randomUUID() + "/undo",
                HttpMethod.PUT,
                new HttpEntity<>(authHeaders(workerToken)),
                String.class
        );
        assertThat(undoResp.getStatusCode()).isEqualTo(HttpStatus.NOT_FOUND);
    }

    @Test
    @DisplayName("13. Security: MANAGER and ADMIN receive 403; Unauthenticated receives 401")
    void securityChecksForWorkerEndpoints() {
        Job job = createJobWithSteps("JOB-SEC", "Cutting");
        UUID stepId = jobStepRepository.findByJobIdOrderByStepOrderAsc(job.getId()).get(0).getId();

        // ADMIN -> 403
        assertThat(restTemplate.exchange(baseUrl() + "/worker/jobs", HttpMethod.GET,
                new HttpEntity<>(authHeaders(adminToken)), String.class).getStatusCode()).isEqualTo(HttpStatus.FORBIDDEN);
        assertThat(restTemplate.exchange(baseUrl() + "/worker/jobs/" + job.getId(), HttpMethod.GET,
                new HttpEntity<>(authHeaders(adminToken)), String.class).getStatusCode()).isEqualTo(HttpStatus.FORBIDDEN);
        assertThat(restTemplate.exchange(baseUrl() + "/worker/job-steps/" + stepId + "/complete", HttpMethod.PUT,
                new HttpEntity<>(authHeaders(adminToken)), String.class).getStatusCode()).isEqualTo(HttpStatus.FORBIDDEN);
        assertThat(restTemplate.exchange(baseUrl() + "/worker/job-steps/" + stepId + "/undo", HttpMethod.PUT,
                new HttpEntity<>(authHeaders(adminToken)), String.class).getStatusCode()).isEqualTo(HttpStatus.FORBIDDEN);

        // MANAGER -> 403
        assertThat(restTemplate.exchange(baseUrl() + "/worker/jobs", HttpMethod.GET,
                new HttpEntity<>(authHeaders(managerToken)), String.class).getStatusCode()).isEqualTo(HttpStatus.FORBIDDEN);
        assertThat(restTemplate.exchange(baseUrl() + "/worker/jobs/" + job.getId(), HttpMethod.GET,
                new HttpEntity<>(authHeaders(managerToken)), String.class).getStatusCode()).isEqualTo(HttpStatus.FORBIDDEN);
        assertThat(restTemplate.exchange(baseUrl() + "/worker/job-steps/" + stepId + "/complete", HttpMethod.PUT,
                new HttpEntity<>(authHeaders(managerToken)), String.class).getStatusCode()).isEqualTo(HttpStatus.FORBIDDEN);
        assertThat(restTemplate.exchange(baseUrl() + "/worker/job-steps/" + stepId + "/undo", HttpMethod.PUT,
                new HttpEntity<>(authHeaders(managerToken)), String.class).getStatusCode()).isEqualTo(HttpStatus.FORBIDDEN);

        // Unauthenticated -> 401
        HttpHeaders headers = new HttpHeaders();
        assertThat(restTemplate.exchange(baseUrl() + "/worker/jobs", HttpMethod.GET,
                new HttpEntity<>(headers), String.class).getStatusCode()).isEqualTo(HttpStatus.UNAUTHORIZED);
        assertThat(restTemplate.exchange(baseUrl() + "/worker/jobs/" + job.getId(), HttpMethod.GET,
                new HttpEntity<>(headers), String.class).getStatusCode()).isEqualTo(HttpStatus.UNAUTHORIZED);
        assertThat(restTemplate.exchange(baseUrl() + "/worker/job-steps/" + stepId + "/complete", HttpMethod.PUT,
                new HttpEntity<>(headers), String.class).getStatusCode()).isEqualTo(HttpStatus.UNAUTHORIZED);
        assertThat(restTemplate.exchange(baseUrl() + "/worker/job-steps/" + stepId + "/undo", HttpMethod.PUT,
                new HttpEntity<>(headers), String.class).getStatusCode()).isEqualTo(HttpStatus.UNAUTHORIZED);
    }
}
