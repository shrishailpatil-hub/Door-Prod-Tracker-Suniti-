package com.doorworkflow.controller;

import com.doorworkflow.config.TestRestTemplateConfig;
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
import org.apache.poi.ss.usermodel.*;
import org.apache.poi.xssf.usermodel.XSSFWorkbook;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.web.client.TestRestTemplate;
import org.springframework.boot.test.web.server.LocalServerPort;
import org.springframework.context.annotation.Import;
import org.springframework.http.*;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.security.crypto.password.PasswordEncoder;

import java.io.ByteArrayInputStream;
import java.io.IOException;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;

import static org.assertj.core.api.Assertions.assertThat;

@Import(TestRestTemplateConfig.class)
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
class LogExportIntegrationTest {

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

    @Autowired
    private JdbcTemplate jdbcTemplate;

    private String adminToken;
    private String managerToken;
    private String workerToken;
    private User adminUser;
    private User managerUser;
    private User workerUser;

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
    }

    private Workbook downloadAndParseWorkbook(String endpoint, String token) throws IOException {
        ResponseEntity<byte[]> response = restTemplate.exchange(
                baseUrl() + endpoint,
                HttpMethod.GET,
                new HttpEntity<>(authHeaders(token)),
                byte[].class
        );
        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.OK);
        assertThat(response.getBody()).isNotNull();
        return new XSSFWorkbook(new ByteArrayInputStream(response.getBody()));
    }

    @Test
    @DisplayName("1. ADMIN can download Excel log export")
    void adminCanDownloadExcel() {
        ResponseEntity<byte[]> response = restTemplate.exchange(
                baseUrl() + "/admin/logs/export",
                HttpMethod.GET,
                new HttpEntity<>(authHeaders(adminToken)),
                byte[].class
        );
        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.OK);
        assertThat(response.getBody()).isNotEmpty();
    }

    @Test
    @DisplayName("2. MANAGER can download Excel log export")
    void managerCanDownloadExcel() {
        ResponseEntity<byte[]> response = restTemplate.exchange(
                baseUrl() + "/manager/logs/export",
                HttpMethod.GET,
                new HttpEntity<>(authHeaders(managerToken)),
                byte[].class
        );
        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.OK);
        assertThat(response.getBody()).isNotEmpty();
    }

    @Test
    @DisplayName("3. WORKER receives 403 on admin and manager export endpoints")
    void workerReceives403() {
        ResponseEntity<String> adminExport = restTemplate.exchange(
                baseUrl() + "/admin/logs/export",
                HttpMethod.GET,
                new HttpEntity<>(authHeaders(workerToken)),
                String.class
        );
        assertThat(adminExport.getStatusCode()).isEqualTo(HttpStatus.FORBIDDEN);

        ResponseEntity<String> managerExport = restTemplate.exchange(
                baseUrl() + "/manager/logs/export",
                HttpMethod.GET,
                new HttpEntity<>(authHeaders(workerToken)),
                String.class
        );
        assertThat(managerExport.getStatusCode()).isEqualTo(HttpStatus.FORBIDDEN);
    }

    @Test
    @DisplayName("4. Unauthenticated request receives 401 on export endpoints")
    void unauthenticatedReceives401() {
        ResponseEntity<String> adminExport = restTemplate.exchange(
                baseUrl() + "/admin/logs/export",
                HttpMethod.GET,
                HttpEntity.EMPTY,
                String.class
        );
        assertThat(adminExport.getStatusCode()).isEqualTo(HttpStatus.UNAUTHORIZED);

        ResponseEntity<String> managerExport = restTemplate.exchange(
                baseUrl() + "/manager/logs/export",
                HttpMethod.GET,
                HttpEntity.EMPTY,
                String.class
        );
        assertThat(managerExport.getStatusCode()).isEqualTo(HttpStatus.UNAUTHORIZED);
    }

    @Test
    @DisplayName("5. Response content-type is correct for Excel spreadsheet")
    void responseContentTypeIsCorrect() {
        ResponseEntity<byte[]> response = restTemplate.exchange(
                baseUrl() + "/admin/logs/export",
                HttpMethod.GET,
                new HttpEntity<>(authHeaders(adminToken)),
                byte[].class
        );
        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.OK);
        assertThat(response.getHeaders().getContentType())
                .isEqualTo(MediaType.parseMediaType("application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"));
    }

    @Test
    @DisplayName("6. Response Content-Disposition indicates attachment with filename job_logs.xlsx")
    void responseContentDispositionIsAttachment() {
        ResponseEntity<byte[]> response = restTemplate.exchange(
                baseUrl() + "/manager/logs/export",
                HttpMethod.GET,
                new HttpEntity<>(authHeaders(managerToken)),
                byte[].class
        );
        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.OK);
        assertThat(response.getHeaders().getFirst(HttpHeaders.CONTENT_DISPOSITION))
                .isEqualTo("attachment; filename=\"job_logs.xlsx\"");
    }

    @Test
    @DisplayName("7. Excel contains Job Logs sheet with 8 headers and frozen top row")
    void excelContainsJobLogsSheetWithCorrectHeaders() throws IOException {
        try (Workbook wb = downloadAndParseWorkbook("/admin/logs/export", adminToken)) {
            Sheet sheet = wb.getSheet("Job Logs");
            assertThat(sheet).isNotNull();

            // Check freeze pane
            assertThat(sheet.getPaneInformation()).isNotNull();
            assertThat(sheet.getPaneInformation().isFreezePane()).isTrue();

            // Check headers
            Row headerRow = sheet.getRow(0);
            assertThat(headerRow).isNotNull();
            assertThat(headerRow.getCell(0).getStringCellValue()).isEqualTo("Job Number");
            assertThat(headerRow.getCell(1).getStringCellValue()).isEqualTo("Company Name");
            assertThat(headerRow.getCell(2).getStringCellValue()).isEqualTo("Job Status");
            assertThat(headerRow.getCell(3).getStringCellValue()).isEqualTo("Chalan Number");
            assertThat(headerRow.getCell(4).getStringCellValue()).isEqualTo("Step Name");
            assertThat(headerRow.getCell(5).getStringCellValue()).isEqualTo("Action");
            assertThat(headerRow.getCell(6).getStringCellValue()).isEqualTo("Performed By");
            assertThat(headerRow.getCell(7).getStringCellValue()).isEqualTo("Timestamp");
        }
    }

    @Test
    @DisplayName("8. Export includes logs from multiple jobs")
    void exportIncludesLogsFromMultipleJobs() throws IOException {
        Job job1 = createJob("JOB-101", "Acme Doors", JobStatus.IN_PROGRESS, null);
        Job job2 = createJob("JOB-102", "Zenith Ent", JobStatus.IN_PROGRESS, null);

        JobStep step1 = createStep(job1, "Cutting", 1, JobStepStatus.COMPLETED);
        JobStep step2 = createStep(job2, "Framing", 1, JobStepStatus.COMPLETED);

        createHistory(job1, step1, JobStepAction.COMPLETED, workerUser);
        createHistory(job2, step2, JobStepAction.COMPLETED, workerUser);

        try (Workbook wb = downloadAndParseWorkbook("/manager/logs/export", managerToken)) {
            Sheet sheet = wb.getSheet("Job Logs");
            List<String> jobNumbers = new ArrayList<>();
            for (int r = 1; r <= sheet.getLastRowNum(); r++) {
                jobNumbers.add(sheet.getRow(r).getCell(0).getStringCellValue());
            }
            assertThat(jobNumbers).contains("JOB-101", "JOB-102");
        }
    }

    @Test
    @DisplayName("9. Export includes normal step actions: COMPLETED, UNDONE, REOPENED")
    void exportIncludesNormalStepActions() throws IOException {
        Job job = createJob("JOB-STEPS", "Doors Inc", JobStatus.IN_PROGRESS, null);
        JobStep step = createStep(job, "Painting", 1, JobStepStatus.PENDING);

        createHistory(job, step, JobStepAction.COMPLETED, workerUser);
        createHistory(job, step, JobStepAction.UNDONE, workerUser);
        createHistory(job, step, JobStepAction.REOPENED, managerUser);

        try (Workbook wb = downloadAndParseWorkbook("/admin/logs/export", adminToken)) {
            Sheet sheet = wb.getSheet("Job Logs");
            List<String> actions = new ArrayList<>();
            for (int r = 1; r <= sheet.getLastRowNum(); r++) {
                actions.add(sheet.getRow(r).getCell(5).getStringCellValue());
                assertThat(sheet.getRow(r).getCell(4).getStringCellValue()).isEqualTo("Painting");
            }
            assertThat(actions).contains("COMPLETED", "UNDONE", "REOPENED");
        }
    }

    @Test
    @DisplayName("10. Export includes CHALAN_ADDED with blank Step Name")
    void exportIncludesChalanAdded() throws IOException {
        Job job = createJob("JOB-CHALAN", "Build Corp", JobStatus.WORK_DONE, "CH-9999");
        createHistory(job, null, JobStepAction.CHALAN_ADDED, workerUser);

        try (Workbook wb = downloadAndParseWorkbook("/manager/logs/export", managerToken)) {
            Sheet sheet = wb.getSheet("Job Logs");
            Row row = sheet.getRow(1);
            assertThat(row.getCell(0).getStringCellValue()).isEqualTo("JOB-CHALAN");
            assertThat(row.getCell(3).getStringCellValue()).isEqualTo("CH-9999");
            assertThat(row.getCell(4).getStringCellValue()).isEmpty(); // Blank Step Name
            assertThat(row.getCell(5).getStringCellValue()).isEqualTo("CHALAN_ADDED");
            assertThat(row.getCell(6).getStringCellValue()).isEqualTo("Worker Bob");
        }
    }

    @Test
    @DisplayName("11. Export includes JOB_COMPLETED with blank Step Name")
    void exportIncludesJobCompleted() throws IOException {
        Job job = createJob("JOB-DONE", "Build Corp", JobStatus.JOB_COMPLETED, "CH-8888");
        createHistory(job, null, JobStepAction.JOB_COMPLETED, workerUser);

        try (Workbook wb = downloadAndParseWorkbook("/admin/logs/export", adminToken)) {
            Sheet sheet = wb.getSheet("Job Logs");
            Row row = sheet.getRow(1);
            assertThat(row.getCell(0).getStringCellValue()).isEqualTo("JOB-DONE");
            assertThat(row.getCell(2).getStringCellValue()).isEqualTo("JOB_COMPLETED");
            assertThat(row.getCell(3).getStringCellValue()).isEqualTo("CH-8888");
            assertThat(row.getCell(4).getStringCellValue()).isEmpty(); // Blank Step Name
            assertThat(row.getCell(5).getStringCellValue()).isEqualTo("JOB_COMPLETED");
            assertThat(row.getCell(6).getStringCellValue()).isEqualTo("Worker Bob");
        }
    }

    @Test
    @DisplayName("12. Job-level events correctly have blank Step Name")
    void jobLevelEventsHaveBlankStepName() throws IOException {
        Job job = createJob("JOB-BLANK-STEP", "Wood Co", JobStatus.JOB_COMPLETED, "CH-123");
        createHistory(job, null, JobStepAction.CHALAN_ADDED, workerUser);
        createHistory(job, null, JobStepAction.JOB_COMPLETED, workerUser);

        try (Workbook wb = downloadAndParseWorkbook("/manager/logs/export", managerToken)) {
            Sheet sheet = wb.getSheet("Job Logs");
            for (int r = 1; r <= sheet.getLastRowNum(); r++) {
                Row row = sheet.getRow(r);
                String action = row.getCell(5).getStringCellValue();
                if ("CHALAN_ADDED".equals(action) || "JOB_COMPLETED".equals(action)) {
                    assertThat(row.getCell(4).getStringCellValue()).isBlank();
                }
            }
        }
    }

    @Test
    @DisplayName("13. Chalan number appears as text in the export")
    void chalanNumberAppearsInExport() throws IOException {
        Job job = createJob("JOB-TEXT-CH", "Glass & Wood", JobStatus.WORK_DONE, "CH-TEXT-456");
        createHistory(job, null, JobStepAction.CHALAN_ADDED, workerUser);

        try (Workbook wb = downloadAndParseWorkbook("/admin/logs/export", adminToken)) {
            Sheet sheet = wb.getSheet("Job Logs");
            Row row = sheet.getRow(1);
            Cell chalanCell = row.getCell(3);
            assertThat(chalanCell.getCellType()).isEqualTo(CellType.STRING);
            assertThat(chalanCell.getStringCellValue()).isEqualTo("CH-TEXT-456");
        }
    }

    @Test
    @DisplayName("14. Cancelled jobs are included in the export")
    void cancelledJobsAreIncluded() throws IOException {
        Job job = createJob("JOB-CANCELLED", "Fail Safe Co", JobStatus.CANCELLED, null);
        JobStep step = createStep(job, "Initial Cut", 1, JobStepStatus.COMPLETED);
        createHistory(job, step, JobStepAction.COMPLETED, workerUser);

        try (Workbook wb = downloadAndParseWorkbook("/manager/logs/export", managerToken)) {
            Sheet sheet = wb.getSheet("Job Logs");
            Row row = sheet.getRow(1);
            assertThat(row.getCell(0).getStringCellValue()).isEqualTo("JOB-CANCELLED");
            assertThat(row.getCell(2).getStringCellValue()).isEqualTo("CANCELLED");
        }
    }

    @Test
    @DisplayName("15. Reopened job history is included in the export")
    void reopenedJobHistoryIsIncluded() throws IOException {
        Job job = createJob("JOB-REOPEN-HIST", "Precision Doors", JobStatus.IN_PROGRESS, null);
        JobStep step = createStep(job, "Final Polish", 3, JobStepStatus.PENDING);
        createHistory(job, step, JobStepAction.REOPENED, managerUser);

        try (Workbook wb = downloadAndParseWorkbook("/admin/logs/export", adminToken)) {
            Sheet sheet = wb.getSheet("Job Logs");
            Row row = sheet.getRow(1);
            assertThat(row.getCell(0).getStringCellValue()).isEqualTo("JOB-REOPEN-HIST");
            assertThat(row.getCell(4).getStringCellValue()).isEqualTo("Final Polish");
            assertThat(row.getCell(5).getStringCellValue()).isEqualTo("REOPENED");
            assertThat(row.getCell(6).getStringCellValue()).isEqualTo("Manager Alice");
        }
    }

    @Test
    @DisplayName("16. Ordering is deterministic newest-first")
    void orderingIsDeterministicNewestFirst() throws IOException {
        // Ensure test isolation: clear any pre‑existing JobStepHistory rows that could affect ordering
        jobStepHistoryRepository.deleteAll();
        Job job = createJob("JOB-ORDER", "Fast Doors", JobStatus.IN_PROGRESS, null);
        JobStep step1 = createStep(job, "Step 1", 1, JobStepStatus.COMPLETED);
        JobStep step2 = createStep(job, "Step 2", 2, JobStepStatus.COMPLETED);

        Instant now = Instant.now();
        // Older log
        JobStepHistory older = JobStepHistory.builder()
                .job(job)
                .jobStep(step1)
                .action(JobStepAction.COMPLETED)
                .performedBy(workerUser)
                .createdAt(now.minus(1, ChronoUnit.HOURS))
                .build();
        older = jobStepHistoryRepository.save(older);

        // Newer log
        JobStepHistory newer = JobStepHistory.builder()
                .job(job)
                .jobStep(step2)
                .action(JobStepAction.COMPLETED)
                .performedBy(workerUser)
                .createdAt(now)
                .build();
        newer = jobStepHistoryRepository.save(newer);

        // @CreationTimestamp owns the insert-time value, so set known database
        // timestamps after persistence to exercise the export ordering contract.
        jdbcTemplate.update(
                "UPDATE job_step_history SET created_at = ? WHERE id = ?",
                now.minus(1, ChronoUnit.HOURS),
                older.getId()
        );
        jdbcTemplate.update(
                "UPDATE job_step_history SET created_at = ? WHERE id = ?",
                now,
                newer.getId()
        );

        try (Workbook wb = downloadAndParseWorkbook("/manager/logs/export", managerToken)) {
            Sheet sheet = wb.getSheet("Job Logs");
            // Collect rows for this job number
            List<Row> jobRows = new ArrayList<>();
            for (int i = 1; i <= sheet.getLastRowNum(); i++) {
                Row row = sheet.getRow(i);
                if (row == null) continue;
                Cell jobNumberCell = row.getCell(0);
                if (jobNumberCell != null && "JOB-ORDER".equals(jobNumberCell.getStringCellValue())) {
                    jobRows.add(row);
                }
            }
            assertThat(jobRows).hasSize(2);
            // Newer log should appear first
            assertThat(jobRows.get(0).getCell(4).getStringCellValue()).isEqualTo("Step 2");
            assertThat(jobRows.get(1).getCell(4).getStringCellValue()).isEqualTo("Step 1");
        }
    }

    private Job createJob(String jobNumber, String companyName, JobStatus status, String chalan) {
        Job job = Job.builder()
                .jobNumber(jobNumber)
                .companyName(companyName)
                .status(status)
                .chalanNumber(chalan)
                .createdBy(managerUser)
                .build();
        return jobRepository.save(job);
    }

    private JobStep createStep(Job job, String name, int order, JobStepStatus status) {
        JobStep step = JobStep.builder()
                .job(job)
                .stepName(name)
                .stepOrder(order)
                .status(status)
                .build();
        return jobStepRepository.save(step);
    }

    private JobStepHistory createHistory(Job job, JobStep step, JobStepAction action, User performer) {
        JobStepHistory h = JobStepHistory.builder()
                .job(job)
                .jobStep(step)
                .action(action)
                .performedBy(performer)
                .build();
        return jobStepHistoryRepository.save(h);
    }

    @Test
    @DisplayName("GET /api/admin/logs - Admin retrieves logs successfully ordered newest first")
    void adminCanGetLogsOrderedNewestFirst() {
        Job job = createJob("JOB-ADM-1", "Admin Corp", JobStatus.IN_PROGRESS, null);
        JobStep step1 = createStep(job, "Cutting", 1, JobStepStatus.COMPLETED);
        JobStep step2 = createStep(job, "Welding", 2, JobStepStatus.PENDING);

        JobStepHistory h1 = createHistory(job, step1, JobStepAction.COMPLETED, workerUser);
        JobStepHistory h2 = createHistory(job, step2, JobStepAction.UNDONE, workerUser);

        jdbcTemplate.update("UPDATE job_step_history SET created_at = ? WHERE id = ?",
                Instant.now().minus(10, ChronoUnit.MINUTES), h1.getId());
        jdbcTemplate.update("UPDATE job_step_history SET created_at = ? WHERE id = ?",
                Instant.now(), h2.getId());

        ResponseEntity<List> response = restTemplate.exchange(
                baseUrl() + "/admin/logs",
                HttpMethod.GET,
                new HttpEntity<>(authHeaders(adminToken)),
                List.class
        );

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.OK);
        List<Map<String, Object>> logs = response.getBody();
        assertThat(logs).hasSize(2);
        // Newest first: h2 (action UNDONE) then h1 (action COMPLETED)
        assertThat(logs.get(0).get("action")).isEqualTo("UNDONE");
        assertThat(logs.get(0).get("stepName")).isEqualTo("Welding");
        assertThat(logs.get(0).get("performedBy")).isEqualTo("Worker Bob");
        assertThat(logs.get(1).get("action")).isEqualTo("COMPLETED");
        assertThat(logs.get(1).get("stepName")).isEqualTo("Cutting");
    }

    @Test
    @DisplayName("GET /api/admin/logs - Unauthenticated request returns 401")
    void unauthenticatedAdminLogsReturns401() {
        ResponseEntity<Map> response = restTemplate.exchange(
                baseUrl() + "/admin/logs",
                HttpMethod.GET,
                null,
                Map.class
        );
        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.UNAUTHORIZED);
    }

    @Test
    @DisplayName("GET /api/admin/logs - Worker request returns 403")
    void workerAdminLogsReturns403() {
        ResponseEntity<Map> response = restTemplate.exchange(
                baseUrl() + "/admin/logs",
                HttpMethod.GET,
                new HttpEntity<>(authHeaders(workerToken)),
                Map.class
        );
        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.FORBIDDEN);
    }

    @Test
    @DisplayName("GET /api/admin/logs - Manager request returns 403")
    void managerAdminLogsReturns403() {
        ResponseEntity<Map> response = restTemplate.exchange(
                baseUrl() + "/admin/logs",
                HttpMethod.GET,
                new HttpEntity<>(authHeaders(managerToken)),
                Map.class
        );
        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.FORBIDDEN);
    }
}
