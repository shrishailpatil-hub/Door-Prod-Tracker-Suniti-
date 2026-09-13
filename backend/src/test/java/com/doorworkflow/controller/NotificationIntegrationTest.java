package com.doorworkflow.controller;

import com.doorworkflow.config.TestRestTemplateConfig;
import com.doorworkflow.dto.response.JobResponse;
import com.doorworkflow.dto.response.NotificationResponse;
import com.doorworkflow.entity.Job;
import com.doorworkflow.entity.JobStep;
import com.doorworkflow.entity.User;
import com.doorworkflow.enums.JobStatus;
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

import java.util.List;
import java.util.Map;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;

@Import(TestRestTemplateConfig.class)
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
class NotificationIntegrationTest {

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
    private String manager1Token;
    private String manager2Token;
    private String adminToken;
    private User workerUser;
    private User activeManager1;
    private User activeManager2;
    private User inactiveManager;
    private User adminUser;

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

        // Active Manager 1
        activeManager1 = User.builder()
                .name("Manager Alice")
                .email("manager1@test.local")
                .password(passwordEncoder.encode("manager123"))
                .role(UserRole.MANAGER)
                .isActive(true)
                .build();
        userRepository.save(activeManager1);
        manager1Token = login("manager1@test.local", "manager123");

        // Active Manager 2
        activeManager2 = User.builder()
                .name("Manager David")
                .email("manager2@test.local")
                .password(passwordEncoder.encode("manager123"))
                .role(UserRole.MANAGER)
                .isActive(true)
                .build();
        userRepository.save(activeManager2);
        manager2Token = login("manager2@test.local", "manager123");

        // Inactive Manager
        inactiveManager = User.builder()
                .name("Inactive Manager")
                .email("inactive@test.local")
                .password(passwordEncoder.encode("manager123"))
                .role(UserRole.MANAGER)
                .isActive(false)
                .build();
        userRepository.save(inactiveManager);

        // Admin
        adminUser = User.builder()
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
                .companyName("Door Co")
                .status(JobStatus.IN_PROGRESS)
                .createdBy(activeManager1)
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
    @DisplayName("1. Successful worker step completion creates notifications for active managers only")
    void stepCompletionCreatesNotificationsForActiveManagersOnly() {
        Job job = createJobWithSteps("1704", "Cutting", "Bending");
        UUID step1Id = jobStepRepository.findByJobIdOrderByStepOrderAsc(job.getId()).get(0).getId();

        // Worker completes step
        ResponseEntity<JobResponse> resp = restTemplate.exchange(
                baseUrl() + "/worker/job-steps/" + step1Id + "/complete",
                HttpMethod.PUT,
                new HttpEntity<>(authHeaders(workerToken)),
                JobResponse.class
        );
        assertThat(resp.getStatusCode()).isEqualTo(HttpStatus.OK);

        // Verify active managers received notification
        List<com.doorworkflow.entity.Notification> m1Notifs = notificationRepository.findByUserId(activeManager1.getId());
        assertThat(m1Notifs).hasSize(1);
        assertThat(m1Notifs.get(0).getMessage()).isEqualTo("Job #1704: Cutting completed by Worker Bob.");
        assertThat(m1Notifs.get(0).getJob().getId()).isEqualTo(job.getId());
        assertThat(m1Notifs.get(0).getIsRead()).isFalse();

        List<com.doorworkflow.entity.Notification> m2Notifs = notificationRepository.findByUserId(activeManager2.getId());
        assertThat(m2Notifs).hasSize(1);
        assertThat(m2Notifs.get(0).getMessage()).isEqualTo("Job #1704: Cutting completed by Worker Bob.");

        // Inactive manager, admin, worker receive NO notification
        assertThat(notificationRepository.findByUserId(inactiveManager.getId())).isEmpty();
        assertThat(notificationRepository.findByUserId(adminUser.getId())).isEmpty();
        assertThat(notificationRepository.findByUserId(workerUser.getId())).isEmpty();
    }

    @Test
    @DisplayName("2. Invalid step completion or undo creates NO notification")
    void invalidStepOrUndoCreatesNoNotification() {
        Job job = createJobWithSteps("1705", "Cutting", "Bending");
        List<JobStep> steps = jobStepRepository.findByJobIdOrderByStepOrderAsc(job.getId());

        // Attempt out-of-order completion on step 2
        restTemplate.exchange(
                baseUrl() + "/worker/job-steps/" + steps.get(1).getId() + "/complete",
                HttpMethod.PUT,
                new HttpEntity<>(authHeaders(workerToken)),
                String.class
        );
        assertThat(notificationRepository.count()).isEqualTo(0);

        // Complete step 1 successfully -> 2 notifs (one for each of the 2 active managers)
        restTemplate.exchange(
                baseUrl() + "/worker/job-steps/" + steps.get(0).getId() + "/complete",
                HttpMethod.PUT,
                new HttpEntity<>(authHeaders(workerToken)),
                JobResponse.class
        );
        assertThat(notificationRepository.count()).isEqualTo(2);

        // Undo step 1 -> no extra notifications created
        restTemplate.exchange(
                baseUrl() + "/worker/job-steps/" + steps.get(0).getId() + "/undo",
                HttpMethod.PUT,
                new HttpEntity<>(authHeaders(workerToken)),
                JobResponse.class
        );
        assertThat(notificationRepository.count()).isEqualTo(2);
    }

    @Test
    @DisplayName("3. Authenticated user can list own notifications and unread notifications; cannot see others")
    void userCanListOwnNotificationsAndUnread() {
        Job job = createJobWithSteps("1706", "Welding");
        UUID stepId = jobStepRepository.findByJobIdOrderByStepOrderAsc(job.getId()).get(0).getId();

        restTemplate.exchange(
                baseUrl() + "/worker/job-steps/" + stepId + "/complete",
                HttpMethod.PUT,
                new HttpEntity<>(authHeaders(workerToken)),
                JobResponse.class
        );

        // Manager 1 gets notifications
        ResponseEntity<List<NotificationResponse>> listResp = restTemplate.exchange(
                baseUrl() + "/notifications",
                HttpMethod.GET,
                new HttpEntity<>(authHeaders(manager1Token)),
                new ParameterizedTypeReference<List<NotificationResponse>>() {}
        );
        assertThat(listResp.getStatusCode()).isEqualTo(HttpStatus.OK);
        assertThat(listResp.getBody()).hasSize(1);
        assertThat(listResp.getBody().get(0).isRead()).isFalse();

        // Worker has 0 notifications
        ResponseEntity<List<NotificationResponse>> workerListResp = restTemplate.exchange(
                baseUrl() + "/notifications",
                HttpMethod.GET,
                new HttpEntity<>(authHeaders(workerToken)),
                new ParameterizedTypeReference<List<NotificationResponse>>() {}
        );
        assertThat(workerListResp.getBody()).isEmpty();

        // Unread endpoint for manager 1 returns 1
        ResponseEntity<List<NotificationResponse>> unreadResp = restTemplate.exchange(
                baseUrl() + "/notifications/unread",
                HttpMethod.GET,
                new HttpEntity<>(authHeaders(manager1Token)),
                new ParameterizedTypeReference<List<NotificationResponse>>() {}
        );
        assertThat(unreadResp.getBody()).hasSize(1);
    }

    @Test
    @DisplayName("4. User can mark own notification as read; cannot mark another user's notification")
    void markAsReadPermissions() {
        Job job = createJobWithSteps("1707", "Welding");
        UUID stepId = jobStepRepository.findByJobIdOrderByStepOrderAsc(job.getId()).get(0).getId();

        restTemplate.exchange(
                baseUrl() + "/worker/job-steps/" + stepId + "/complete",
                HttpMethod.PUT,
                new HttpEntity<>(authHeaders(workerToken)),
                JobResponse.class
        );

        // Get notification id for manager 1
        List<com.doorworkflow.entity.Notification> m1Notifs = notificationRepository.findByUserId(activeManager1.getId());
        UUID notifId = m1Notifs.get(0).getId();

        // Manager 2 tries to mark Manager 1's notification as read -> 404 (not found for manager 2)
        ResponseEntity<String> forbiddenResp = restTemplate.exchange(
                baseUrl() + "/notifications/" + notifId + "/read",
                HttpMethod.PUT,
                new HttpEntity<>(authHeaders(manager2Token)),
                String.class
        );
        assertThat(forbiddenResp.getStatusCode()).isEqualTo(HttpStatus.NOT_FOUND);

        // Manager 1 marks own notification as read -> 200
        ResponseEntity<NotificationResponse> okResp = restTemplate.exchange(
                baseUrl() + "/notifications/" + notifId + "/read",
                HttpMethod.PUT,
                new HttpEntity<>(authHeaders(manager1Token)),
                NotificationResponse.class
        );
        assertThat(okResp.getStatusCode()).isEqualTo(HttpStatus.OK);
        assertThat(okResp.getBody().isRead()).isTrue();

        // Manager 1 unread endpoint now returns empty
        ResponseEntity<List<NotificationResponse>> unreadResp = restTemplate.exchange(
                baseUrl() + "/notifications/unread",
                HttpMethod.GET,
                new HttpEntity<>(authHeaders(manager1Token)),
                new ParameterizedTypeReference<List<NotificationResponse>>() {}
        );
        assertThat(unreadResp.getBody()).isEmpty();
    }

    @Test
    @DisplayName("5. Missing notification returns 404; Unauthenticated receives 401")
    void missingNotificationAndUnauthenticated() {
        ResponseEntity<String> notFoundResp = restTemplate.exchange(
                baseUrl() + "/notifications/" + UUID.randomUUID() + "/read",
                HttpMethod.PUT,
                new HttpEntity<>(authHeaders(manager1Token)),
                String.class
        );
        assertThat(notFoundResp.getStatusCode()).isEqualTo(HttpStatus.NOT_FOUND);

        HttpHeaders headers = new HttpHeaders();
        assertThat(restTemplate.exchange(baseUrl() + "/notifications", HttpMethod.GET,
                new HttpEntity<>(headers), String.class).getStatusCode()).isEqualTo(HttpStatus.UNAUTHORIZED);
        assertThat(restTemplate.exchange(baseUrl() + "/notifications/unread", HttpMethod.GET,
                new HttpEntity<>(headers), String.class).getStatusCode()).isEqualTo(HttpStatus.UNAUTHORIZED);
        assertThat(restTemplate.exchange(baseUrl() + "/notifications/" + UUID.randomUUID() + "/read", HttpMethod.PUT,
                new HttpEntity<>(headers), String.class).getStatusCode()).isEqualTo(HttpStatus.UNAUTHORIZED);
    }
}
