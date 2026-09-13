package com.doorworkflow.controller;

import com.doorworkflow.config.TestRestTemplateConfig;
import com.doorworkflow.dto.request.AddChalanRequest;
import com.doorworkflow.dto.request.ReopenJobRequest;
import com.doorworkflow.dto.response.JobResponse;
import com.doorworkflow.entity.Job;
import com.doorworkflow.entity.JobStep;
import com.doorworkflow.entity.JobStepHistory;
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
import org.springframework.http.*;
import org.springframework.security.crypto.password.PasswordEncoder;

import java.time.Instant;
import java.util.List;
import java.util.Map;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;

@Import(TestRestTemplateConfig.class)
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
class WorkerJobCompletionIntegrationTest {

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
        if (token != null) {
            headers.setBearerAuth(token);
        }
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

    private Job createJobWithSteps(String jobNumber, JobStatus status, String... stepNames) {
        Job job = Job.builder()
                .jobNumber(jobNumber)
                .companyName("Acme Co")
                .status(status)
                .createdBy(managerUser)
                .completedAt(status == JobStatus.WORK_DONE || status == JobStatus.JOB_COMPLETED ? Instant.now() : null)
                .build();
        Job savedJob = jobRepository.save(job);

        for (int i = 0; i < stepNames.length; i++) {
            JobStep step = JobStep.builder()
                    .job(savedJob)
                    .stepName(stepNames[i])
                    .stepOrder(i + 1)
                    .status(status == JobStatus.WORK_DONE || status == JobStatus.JOB_COMPLETED ? JobStepStatus.COMPLETED : JobStepStatus.PENDING)
                    .completedBy(status == JobStatus.WORK_DONE || status == JobStatus.JOB_COMPLETED ? workerUser : null)
                    .completedAt(status == JobStatus.WORK_DONE || status == JobStatus.JOB_COMPLETED ? Instant.now() : null)
                    .build();
            jobStepRepository.save(step);
        }
        return savedJob;
    }

    @Test
    @DisplayName("1. Worker can add Chalan when job is WORK_DONE")
    void workerCanAddChalanWhenJobIsWorkDone() {
        Job job = createJobWithSteps("JOB-CH-1", JobStatus.WORK_DONE, "Cutting", "Welding");

        ResponseEntity<JobResponse> resp = restTemplate.exchange(
                baseUrl() + "/worker/jobs/" + job.getId() + "/chalan",
                HttpMethod.PUT,
                new HttpEntity<>(new AddChalanRequest("CH-10294"), authHeaders(workerToken)),
                JobResponse.class
        );

        assertThat(resp.getStatusCode()).isEqualTo(HttpStatus.OK);
        assertThat(resp.getBody()).isNotNull();
        assertThat(resp.getBody().chalanNumber()).isEqualTo("CH-10294");
        assertThat(resp.getBody().status()).isEqualTo(JobStatus.WORK_DONE);

        Job dbJob = jobRepository.findById(job.getId()).orElseThrow();
        assertThat(dbJob.getChalanNumber()).isEqualTo("CH-10294");

        List<JobStepHistory> logs = jobStepHistoryRepository.findByJobIdOrderByCreatedAtDesc(job.getId());
        assertThat(logs).isNotEmpty();
        assertThat(logs.get(0).getAction()).isEqualTo(JobStepAction.CHALAN_ADDED);
        assertThat(logs.get(0).getPerformedBy().getId()).isEqualTo(workerUser.getId());
        assertThat(logs.get(0).getJobStep()).isNull();
    }

    @Test
    @DisplayName("2. Worker cannot add Chalan while IN_PROGRESS")
    void workerCannotAddChalanWhileInProgress() {
        Job job = createJobWithSteps("JOB-CH-2", JobStatus.IN_PROGRESS, "Cutting");

        ResponseEntity<String> resp = restTemplate.exchange(
                baseUrl() + "/worker/jobs/" + job.getId() + "/chalan",
                HttpMethod.PUT,
                new HttpEntity<>(new AddChalanRequest("CH-10294"), authHeaders(workerToken)),
                String.class
        );

        assertThat(resp.getStatusCode()).isEqualTo(HttpStatus.BAD_REQUEST);
        assertThat(resp.getBody()).contains("WORK_DONE");
    }

    @Test
    @DisplayName("3. Worker cannot add blank Chalan")
    void workerCannotAddBlankChalan() {
        Job job = createJobWithSteps("JOB-CH-3", JobStatus.WORK_DONE, "Cutting");

        ResponseEntity<String> resp = restTemplate.exchange(
                baseUrl() + "/worker/jobs/" + job.getId() + "/chalan",
                HttpMethod.PUT,
                new HttpEntity<>(new AddChalanRequest("   "), authHeaders(workerToken)),
                String.class
        );

        assertThat(resp.getStatusCode()).isEqualTo(HttpStatus.BAD_REQUEST);
    }

    @Test
    @DisplayName("4. Worker cannot add Chalan to CANCELLED job")
    void workerCannotAddChalanToCancelledJob() {
        Job job = createJobWithSteps("JOB-CH-4", JobStatus.CANCELLED, "Cutting");

        ResponseEntity<String> resp = restTemplate.exchange(
                baseUrl() + "/worker/jobs/" + job.getId() + "/chalan",
                HttpMethod.PUT,
                new HttpEntity<>(new AddChalanRequest("CH-10294"), authHeaders(workerToken)),
                String.class
        );

        assertThat(resp.getStatusCode()).isEqualTo(HttpStatus.BAD_REQUEST);
        assertThat(resp.getBody()).contains("cancelled");
    }

    @Test
    @DisplayName("5. Worker cannot modify Chalan after JOB_COMPLETED")
    void workerCannotModifyChalanAfterJobCompleted() {
        Job job = createJobWithSteps("JOB-CH-5", JobStatus.JOB_COMPLETED, "Cutting");
        job.setChalanNumber("CH-ORIG");
        jobRepository.save(job);

        ResponseEntity<String> resp = restTemplate.exchange(
                baseUrl() + "/worker/jobs/" + job.getId() + "/chalan",
                HttpMethod.PUT,
                new HttpEntity<>(new AddChalanRequest("CH-NEW"), authHeaders(workerToken)),
                String.class
        );

        assertThat(resp.getStatusCode()).isEqualTo(HttpStatus.BAD_REQUEST);
        assertThat(resp.getBody()).contains("completed");
    }

    @Test
    @DisplayName("6. Manager receives 403 when calling /chalan or /complete")
    void managerReceives403() {
        Job job = createJobWithSteps("JOB-SEC-MGR", JobStatus.WORK_DONE, "Cutting");

        ResponseEntity<String> chalanResp = restTemplate.exchange(
                baseUrl() + "/worker/jobs/" + job.getId() + "/chalan",
                HttpMethod.PUT,
                new HttpEntity<>(new AddChalanRequest("CH-101"), authHeaders(managerToken)),
                String.class
        );
        assertThat(chalanResp.getStatusCode()).isEqualTo(HttpStatus.FORBIDDEN);

        ResponseEntity<String> compResp = restTemplate.exchange(
                baseUrl() + "/worker/jobs/" + job.getId() + "/complete",
                HttpMethod.PUT,
                new HttpEntity<>(authHeaders(managerToken)),
                String.class
        );
        assertThat(compResp.getStatusCode()).isEqualTo(HttpStatus.FORBIDDEN);
    }

    @Test
    @DisplayName("7. Admin receives 403 when calling /chalan or /complete")
    void adminReceives403() {
        Job job = createJobWithSteps("JOB-SEC-ADM", JobStatus.WORK_DONE, "Cutting");

        ResponseEntity<String> chalanResp = restTemplate.exchange(
                baseUrl() + "/worker/jobs/" + job.getId() + "/chalan",
                HttpMethod.PUT,
                new HttpEntity<>(new AddChalanRequest("CH-101"), authHeaders(adminToken)),
                String.class
        );
        assertThat(chalanResp.getStatusCode()).isEqualTo(HttpStatus.FORBIDDEN);

        ResponseEntity<String> compResp = restTemplate.exchange(
                baseUrl() + "/worker/jobs/" + job.getId() + "/complete",
                HttpMethod.PUT,
                new HttpEntity<>(authHeaders(adminToken)),
                String.class
        );
        assertThat(compResp.getStatusCode()).isEqualTo(HttpStatus.FORBIDDEN);
    }

    @Test
    @DisplayName("8. Unauthenticated request receives 401")
    void unauthenticatedReceives401() {
        Job job = createJobWithSteps("JOB-SEC-UNAUTH", JobStatus.WORK_DONE, "Cutting");

        ResponseEntity<String> chalanResp = restTemplate.exchange(
                baseUrl() + "/worker/jobs/" + job.getId() + "/chalan",
                HttpMethod.PUT,
                new HttpEntity<>(new AddChalanRequest("CH-101")),
                String.class
        );
        assertThat(chalanResp.getStatusCode()).isEqualTo(HttpStatus.UNAUTHORIZED);

        ResponseEntity<String> compResp = restTemplate.exchange(
                baseUrl() + "/worker/jobs/" + job.getId() + "/complete",
                HttpMethod.PUT,
                HttpEntity.EMPTY,
                String.class
        );
        assertThat(compResp.getStatusCode()).isEqualTo(HttpStatus.UNAUTHORIZED);
    }

    @Test
    @DisplayName("9. Worker can mark WORK_DONE job as JOB_COMPLETED when Chalan exists")
    void workerCanMarkWorkDoneJobAsCompleted() {
        Job job = createJobWithSteps("JOB-FIN-1", JobStatus.WORK_DONE, "Cutting", "Painting");
        job.setChalanNumber("CH-7788");
        jobRepository.save(job);

        ResponseEntity<JobResponse> resp = restTemplate.exchange(
                baseUrl() + "/worker/jobs/" + job.getId() + "/complete",
                HttpMethod.PUT,
                new HttpEntity<>(authHeaders(workerToken)),
                JobResponse.class
        );

        assertThat(resp.getStatusCode()).isEqualTo(HttpStatus.OK);
        assertThat(resp.getBody()).isNotNull();
        assertThat(resp.getBody().status()).isEqualTo(JobStatus.JOB_COMPLETED);
        assertThat(resp.getBody().chalanNumber()).isEqualTo("CH-7788");
        assertThat(resp.getBody().completedAt()).isNotNull();

        Job dbJob = jobRepository.findById(job.getId()).orElseThrow();
        assertThat(dbJob.getStatus()).isEqualTo(JobStatus.JOB_COMPLETED);
    }

    @Test
    @DisplayName("10. Final completion sets completedAt timestamp")
    void completionSetsCompletedAt() {
        Job job = createJobWithSteps("JOB-FIN-2", JobStatus.WORK_DONE, "Cutting");
        job.setChalanNumber("CH-TIMESTAMP");
        jobRepository.save(job);

        ResponseEntity<JobResponse> resp = restTemplate.exchange(
                baseUrl() + "/worker/jobs/" + job.getId() + "/complete",
                HttpMethod.PUT,
                new HttpEntity<>(authHeaders(workerToken)),
                JobResponse.class
        );

        assertThat(resp.getStatusCode()).isEqualTo(HttpStatus.OK);
        assertThat(resp.getBody().completedAt()).isNotNull();

        Job dbJob = jobRepository.findById(job.getId()).orElseThrow();
        assertThat(dbJob.getCompletedAt()).isNotNull();
    }

    @Test
    @DisplayName("11. Completion records authenticated worker in history")
    void completionRecordsAuthenticatedWorker() {
        Job job = createJobWithSteps("JOB-FIN-3", JobStatus.WORK_DONE, "Cutting");
        job.setChalanNumber("CH-AUDIT");
        jobRepository.save(job);

        restTemplate.exchange(
                baseUrl() + "/worker/jobs/" + job.getId() + "/complete",
                HttpMethod.PUT,
                new HttpEntity<>(authHeaders(workerToken)),
                JobResponse.class
        );

        List<JobStepHistory> logs = jobStepHistoryRepository.findByJobIdOrderByCreatedAtDesc(job.getId());
        assertThat(logs).isNotEmpty();
        JobStepHistory latestLog = logs.get(0);
        assertThat(latestLog.getAction()).isEqualTo(JobStepAction.JOB_COMPLETED);
        assertThat(latestLog.getPerformedBy().getId()).isEqualTo(workerUser.getId());
        assertThat(latestLog.getJobStep()).isNull();
    }

    @Test
    @DisplayName("12. Cannot complete without Chalan number")
    void cannotCompleteWithoutChalan() {
        Job job = createJobWithSteps("JOB-FIN-4", JobStatus.WORK_DONE, "Cutting");
        job.setChalanNumber(null);
        jobRepository.save(job);

        ResponseEntity<String> resp = restTemplate.exchange(
                baseUrl() + "/worker/jobs/" + job.getId() + "/complete",
                HttpMethod.PUT,
                new HttpEntity<>(authHeaders(workerToken)),
                String.class
        );

        assertThat(resp.getStatusCode()).isEqualTo(HttpStatus.BAD_REQUEST);
        assertThat(resp.getBody()).contains("Chalan number is required");
    }

    @Test
    @DisplayName("13. Cannot complete while IN_PROGRESS")
    void cannotCompleteWhileInProgress() {
        Job job = createJobWithSteps("JOB-FIN-5", JobStatus.IN_PROGRESS, "Cutting");
        job.setChalanNumber("CH-555");
        jobRepository.save(job);

        ResponseEntity<String> resp = restTemplate.exchange(
                baseUrl() + "/worker/jobs/" + job.getId() + "/complete",
                HttpMethod.PUT,
                new HttpEntity<>(authHeaders(workerToken)),
                String.class
        );

        assertThat(resp.getStatusCode()).isEqualTo(HttpStatus.BAD_REQUEST);
        assertThat(resp.getBody()).contains("IN_PROGRESS");
    }

    @Test
    @DisplayName("14. Cannot complete CANCELLED job")
    void cannotCompleteCancelledJob() {
        Job job = createJobWithSteps("JOB-FIN-6", JobStatus.CANCELLED, "Cutting");
        job.setChalanNumber("CH-666");
        jobRepository.save(job);

        ResponseEntity<String> resp = restTemplate.exchange(
                baseUrl() + "/worker/jobs/" + job.getId() + "/complete",
                HttpMethod.PUT,
                new HttpEntity<>(authHeaders(workerToken)),
                String.class
        );

        assertThat(resp.getStatusCode()).isEqualTo(HttpStatus.BAD_REQUEST);
        assertThat(resp.getBody()).contains("cancelled");
    }

    @Test
    @DisplayName("15. Cannot complete already JOB_COMPLETED job")
    void cannotCompleteAlreadyCompletedJob() {
        Job job = createJobWithSteps("JOB-FIN-7", JobStatus.JOB_COMPLETED, "Cutting");
        job.setChalanNumber("CH-777");
        jobRepository.save(job);

        ResponseEntity<String> resp = restTemplate.exchange(
                baseUrl() + "/worker/jobs/" + job.getId() + "/complete",
                HttpMethod.PUT,
                new HttpEntity<>(authHeaders(workerToken)),
                String.class
        );

        assertThat(resp.getStatusCode()).isEqualTo(HttpStatus.BAD_REQUEST);
        assertThat(resp.getBody()).contains("already completed");
    }

    @Test
    @DisplayName("16. Cannot complete if any manufacturing step is still PENDING")
    void cannotCompleteIfAnyStepPending() {
        Job job = createJobWithSteps("JOB-FIN-8", JobStatus.WORK_DONE, "Cutting", "Welding");
        job.setChalanNumber("CH-888");
        jobRepository.save(job);

        // Artificially reset step 2 to PENDING
        List<JobStep> steps = jobStepRepository.findByJobIdOrderByStepOrderAsc(job.getId());
        JobStep step2 = steps.get(1);
        step2.setStatus(JobStepStatus.PENDING);
        jobStepRepository.save(step2);

        ResponseEntity<String> resp = restTemplate.exchange(
                baseUrl() + "/worker/jobs/" + job.getId() + "/complete",
                HttpMethod.PUT,
                new HttpEntity<>(authHeaders(workerToken)),
                String.class
        );

        assertThat(resp.getStatusCode()).isEqualTo(HttpStatus.BAD_REQUEST);
        assertThat(resp.getBody()).contains("manufacturing steps must be completed");
    }

    @Test
    @DisplayName("17. JOB_COMPLETED job cannot have its steps completed or undone")
    void jobCompletedCannotModifySteps() {
        Job job = createJobWithSteps("JOB-FIN-9", JobStatus.JOB_COMPLETED, "Cutting");
        job.setChalanNumber("CH-999");
        jobRepository.save(job);

        UUID stepId = jobStepRepository.findByJobIdOrderByStepOrderAsc(job.getId()).get(0).getId();

        ResponseEntity<String> compResp = restTemplate.exchange(
                baseUrl() + "/worker/job-steps/" + stepId + "/complete",
                HttpMethod.PUT,
                new HttpEntity<>(authHeaders(workerToken)),
                String.class
        );
        assertThat(compResp.getStatusCode()).isEqualTo(HttpStatus.BAD_REQUEST);

        ResponseEntity<String> undoResp = restTemplate.exchange(
                baseUrl() + "/worker/job-steps/" + stepId + "/undo",
                HttpMethod.PUT,
                new HttpEntity<>(authHeaders(workerToken)),
                String.class
        );
        assertThat(undoResp.getStatusCode()).isEqualTo(HttpStatus.BAD_REQUEST);
    }

    @Test
    @DisplayName("18. JOB_COMPLETED job cannot be reopened or cancelled by Manager")
    void jobCompletedCannotBeReopenedOrCancelledByManager() {
        Job job = createJobWithSteps("JOB-FIN-10", JobStatus.JOB_COMPLETED, "Cutting");
        job.setChalanNumber("CH-1000");
        jobRepository.save(job);

        UUID stepId = jobStepRepository.findByJobIdOrderByStepOrderAsc(job.getId()).get(0).getId();

        // Reopen attempt -> 400
        ResponseEntity<String> reopenResp = restTemplate.exchange(
                baseUrl() + "/manager/jobs/" + job.getId() + "/reopen",
                HttpMethod.PUT,
                new HttpEntity<>(new ReopenJobRequest(stepId), authHeaders(managerToken)),
                String.class
        );
        assertThat(reopenResp.getStatusCode()).isEqualTo(HttpStatus.BAD_REQUEST);

        // Cancel attempt -> 400
        ResponseEntity<String> cancelResp = restTemplate.exchange(
                baseUrl() + "/manager/jobs/" + job.getId() + "/cancel",
                HttpMethod.PUT,
                new HttpEntity<>(authHeaders(managerToken)),
                String.class
        );
        assertThat(cancelResp.getStatusCode()).isEqualTo(HttpStatus.BAD_REQUEST);
    }

    @Test
    @DisplayName("19. Existing WORK_DONE -> Manager reopen -> IN_PROGRESS still works")
    void existingWorkDoneManagerReopenStillWorks() {
        Job job = createJobWithSteps("JOB-REOPEN-FLOW", JobStatus.WORK_DONE, "Cutting", "Welding");
        UUID step2Id = jobStepRepository.findByJobIdOrderByStepOrderAsc(job.getId()).get(1).getId();

        ResponseEntity<JobResponse> reopenResp = restTemplate.exchange(
                baseUrl() + "/manager/jobs/" + job.getId() + "/reopen",
                HttpMethod.PUT,
                new HttpEntity<>(new ReopenJobRequest(step2Id), authHeaders(managerToken)),
                JobResponse.class
        );

        assertThat(reopenResp.getStatusCode()).isEqualTo(HttpStatus.OK);
        assertThat(reopenResp.getBody().status()).isEqualTo(JobStatus.IN_PROGRESS);

        Job dbJob = jobRepository.findById(job.getId()).orElseThrow();
        assertThat(dbJob.getStatus()).isEqualTo(JobStatus.IN_PROGRESS);
    }

    @Test
    @DisplayName("20. Reopened job can eventually reach WORK_DONE and JOB_COMPLETED again")
    void reopenedJobCanReachWorkDoneAndJobCompletedAgain() {
        // Start as WORK_DONE
        Job job = createJobWithSteps("JOB-LIFECYCLE-FULL", JobStatus.WORK_DONE, "Cutting", "Welding");
        UUID step2Id = jobStepRepository.findByJobIdOrderByStepOrderAsc(job.getId()).get(1).getId();

        // 1. Manager reopens step 2
        ResponseEntity<JobResponse> reopenResp = restTemplate.exchange(
                baseUrl() + "/manager/jobs/" + job.getId() + "/reopen",
                HttpMethod.PUT,
                new HttpEntity<>(new ReopenJobRequest(step2Id), authHeaders(managerToken)),
                JobResponse.class
        );
        assertThat(reopenResp.getStatusCode()).isEqualTo(HttpStatus.OK);
        assertThat(reopenResp.getBody().status()).isEqualTo(JobStatus.IN_PROGRESS);

        // 2. Worker completes step 2 -> transitions back to WORK_DONE
        ResponseEntity<JobResponse> compStepResp = restTemplate.exchange(
                baseUrl() + "/worker/job-steps/" + step2Id + "/complete",
                HttpMethod.PUT,
                new HttpEntity<>(authHeaders(workerToken)),
                JobResponse.class
        );
        assertThat(compStepResp.getStatusCode()).isEqualTo(HttpStatus.OK);
        assertThat(compStepResp.getBody().status()).isEqualTo(JobStatus.WORK_DONE);

        // 3. Worker adds Chalan
        ResponseEntity<JobResponse> chalanResp = restTemplate.exchange(
                baseUrl() + "/worker/jobs/" + job.getId() + "/chalan",
                HttpMethod.PUT,
                new HttpEntity<>(new AddChalanRequest("CH-REWORK-99"), authHeaders(workerToken)),
                JobResponse.class
        );
        assertThat(chalanResp.getStatusCode()).isEqualTo(HttpStatus.OK);
        assertThat(chalanResp.getBody().chalanNumber()).isEqualTo("CH-REWORK-99");

        // 4. Worker marks job as JOB_COMPLETED
        ResponseEntity<JobResponse> finalCompResp = restTemplate.exchange(
                baseUrl() + "/worker/jobs/" + job.getId() + "/complete",
                HttpMethod.PUT,
                new HttpEntity<>(authHeaders(workerToken)),
                JobResponse.class
        );
        assertThat(finalCompResp.getStatusCode()).isEqualTo(HttpStatus.OK);
        assertThat(finalCompResp.getBody().status()).isEqualTo(JobStatus.JOB_COMPLETED);
        assertThat(finalCompResp.getBody().chalanNumber()).isEqualTo("CH-REWORK-99");

        Job dbJob = jobRepository.findById(job.getId()).orElseThrow();
        assertThat(dbJob.getStatus()).isEqualTo(JobStatus.JOB_COMPLETED);
    }
}
