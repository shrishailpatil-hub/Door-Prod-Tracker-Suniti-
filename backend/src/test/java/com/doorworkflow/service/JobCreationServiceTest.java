package com.doorworkflow.service;

import com.doorworkflow.dto.request.CreateJobRequest;
import com.doorworkflow.dto.response.JobResponse;
import com.doorworkflow.dto.response.JobStepResponse;
import com.doorworkflow.entity.Job;
import com.doorworkflow.entity.JobStep;
import com.doorworkflow.entity.ProcessStep;
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
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Captor;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.http.HttpStatus;
import org.springframework.security.access.AccessDeniedException;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.web.server.ResponseStatusException;

import java.time.Instant;
import java.util.*;

import static org.assertj.core.api.Assertions.assertThat;
import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyList;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class JobCreationServiceTest {

    @Mock
    private JobRepository jobRepository;

    @Mock
    private JobStepRepository jobStepRepository;

    @Mock
    private JobStepHistoryRepository jobStepHistoryRepository;

    @Mock
    private NotificationRepository notificationRepository;

    @Mock
    private ProcessStepRepository processStepRepository;

    @Mock
    private UserRepository userRepository;

    @InjectMocks
    private JobService jobService;

    @Captor
    private ArgumentCaptor<Job> jobCaptor;

    @Captor
    private ArgumentCaptor<List<JobStep>> jobStepsCaptor;

    private User managerUser;

    @BeforeEach
    void setUp() {
        managerUser = User.builder()
                .id(UUID.randomUUID())
                .name("Alice Manager")
                .email("manager@example.com")
                .role(UserRole.MANAGER)
                .isActive(true)
                .build();

        UsernamePasswordAuthenticationToken auth =
                new UsernamePasswordAuthenticationToken(managerUser.getEmail(), null, List.of());
        SecurityContextHolder.getContext().setAuthentication(auth);
    }

    @AfterEach
    void tearDown() {
        SecurityContextHolder.clearContext();
    }

    private void mockManagerInRepo() {
        when(userRepository.findByEmail("manager@example.com")).thenReturn(Optional.of(managerUser));
    }

    @Test
    @DisplayName("1. Creates job with IN_PROGRESS status")
    void createsJobWithInProgressStatus() {
        mockManagerInRepo();
        when(jobRepository.findByJobNumber("JOB-100")).thenReturn(Optional.empty());
        when(processStepRepository.findByIsActive(true)).thenReturn(List.of());

        when(jobRepository.save(any(Job.class))).thenAnswer(invocation -> {
            Job j = invocation.getArgument(0);
            j.setId(UUID.randomUUID());
            return j;
        });

        CreateJobRequest request = new CreateJobRequest("JOB-100", "Acme Doors");
        JobResponse response = jobService.createJob(request);

        verify(jobRepository).save(jobCaptor.capture());
        assertThat(jobCaptor.getValue().getStatus()).isEqualTo(JobStatus.IN_PROGRESS);
        assertThat(response.status()).isEqualTo(JobStatus.IN_PROGRESS);
    }

    @Test
    @DisplayName("2. Uses authenticated manager as createdBy")
    void usesAuthenticatedManagerAsCreatedBy() {
        mockManagerInRepo();
        when(jobRepository.findByJobNumber("JOB-101")).thenReturn(Optional.empty());
        when(processStepRepository.findByIsActive(true)).thenReturn(List.of());

        when(jobRepository.save(any(Job.class))).thenAnswer(invocation -> {
            Job j = invocation.getArgument(0);
            j.setId(UUID.randomUUID());
            return j;
        });

        CreateJobRequest request = new CreateJobRequest("JOB-101", "Acme Doors");
        JobResponse response = jobService.createJob(request);

        verify(jobRepository).save(jobCaptor.capture());
        assertThat(jobCaptor.getValue().getCreatedBy()).isEqualTo(managerUser);
        assertThat(response.createdBy()).isEqualTo("Alice Manager");
    }

    @Test
    @DisplayName("3. Snapshots all active master process steps")
    void snapshotsAllActiveMasterProcessSteps() {
        mockManagerInRepo();
        when(jobRepository.findByJobNumber("JOB-102")).thenReturn(Optional.empty());

        ProcessStep s1 = ProcessStep.builder().id(UUID.randomUUID()).name("Cutting").stepOrder(1).isActive(true).build();
        ProcessStep s2 = ProcessStep.builder().id(UUID.randomUUID()).name("Bending").stepOrder(2).isActive(true).build();
        ProcessStep s3 = ProcessStep.builder().id(UUID.randomUUID()).name("Welding").stepOrder(3).isActive(true).build();
        when(processStepRepository.findByIsActive(true)).thenReturn(List.of(s1, s2, s3));

        when(jobRepository.save(any(Job.class))).thenAnswer(invocation -> {
            Job j = invocation.getArgument(0);
            j.setId(UUID.randomUUID());
            return j;
        });
        when(jobStepRepository.saveAll(anyList())).thenAnswer(invocation -> invocation.getArgument(0));

        CreateJobRequest request = new CreateJobRequest("JOB-102", "Acme Doors");
        JobResponse response = jobService.createJob(request);

        verify(jobStepRepository).saveAll(jobStepsCaptor.capture());
        List<JobStep> savedSteps = jobStepsCaptor.getValue();
        assertThat(savedSteps).hasSize(3);
        assertThat(savedSteps).extracting(JobStep::getStepName)
                .containsExactly("Cutting", "Bending", "Welding");
        assertThat(response.steps()).hasSize(3);
    }

    @Test
    @DisplayName("4. Snapshots steps in correct order")
    void snapshotsStepsInCorrectOrder() {
        mockManagerInRepo();
        when(jobRepository.findByJobNumber("JOB-103")).thenReturn(Optional.empty());

        // Process steps returned out of order from repo
        ProcessStep s2 = ProcessStep.builder().id(UUID.randomUUID()).name("Bending").stepOrder(2).isActive(true).build();
        ProcessStep s1 = ProcessStep.builder().id(UUID.randomUUID()).name("Cutting").stepOrder(1).isActive(true).build();
        ProcessStep s3 = ProcessStep.builder().id(UUID.randomUUID()).name("Welding").stepOrder(3).isActive(true).build();
        when(processStepRepository.findByIsActive(true)).thenReturn(List.of(s2, s1, s3));

        when(jobRepository.save(any(Job.class))).thenAnswer(invocation -> {
            Job j = invocation.getArgument(0);
            j.setId(UUID.randomUUID());
            return j;
        });
        when(jobStepRepository.saveAll(anyList())).thenAnswer(invocation -> invocation.getArgument(0));

        CreateJobRequest request = new CreateJobRequest("JOB-103", "Acme Doors");
        JobResponse response = jobService.createJob(request);

        verify(jobStepRepository).saveAll(jobStepsCaptor.capture());
        List<JobStep> savedSteps = jobStepsCaptor.getValue();
        assertThat(savedSteps).extracting(JobStep::getStepOrder).containsExactly(1, 2, 3);
        assertThat(savedSteps).extracting(JobStep::getStepName).containsExactly("Cutting", "Bending", "Welding");
        assertThat(response.steps()).extracting(JobStepResponse::stepOrder).containsExactly(1, 2, 3);
    }

    @Test
    @DisplayName("5. All created JobSteps start as PENDING")
    void allCreatedJobStepsStartAsPending() {
        mockManagerInRepo();
        when(jobRepository.findByJobNumber("JOB-104")).thenReturn(Optional.empty());

        ProcessStep s1 = ProcessStep.builder().id(UUID.randomUUID()).name("Cutting").stepOrder(1).isActive(true).build();
        when(processStepRepository.findByIsActive(true)).thenReturn(List.of(s1));

        when(jobRepository.save(any(Job.class))).thenAnswer(invocation -> {
            Job j = invocation.getArgument(0);
            j.setId(UUID.randomUUID());
            return j;
        });
        when(jobStepRepository.saveAll(anyList())).thenAnswer(invocation -> invocation.getArgument(0));

        CreateJobRequest request = new CreateJobRequest("JOB-104", "Acme Doors");
        JobResponse response = jobService.createJob(request);

        verify(jobStepRepository).saveAll(jobStepsCaptor.capture());
        List<JobStep> savedSteps = jobStepsCaptor.getValue();
        assertThat(savedSteps).allMatch(s -> s.getStatus() == JobStepStatus.PENDING);
        assertThat(response.steps()).allMatch(s -> s.status() == JobStepStatus.PENDING);
    }

    @Test
    @DisplayName("6. completedBy and completedAt are null initially")
    void completedByAndCompletedAtAreNullInitially() {
        mockManagerInRepo();
        when(jobRepository.findByJobNumber("JOB-105")).thenReturn(Optional.empty());

        ProcessStep s1 = ProcessStep.builder().id(UUID.randomUUID()).name("Cutting").stepOrder(1).isActive(true).build();
        when(processStepRepository.findByIsActive(true)).thenReturn(List.of(s1));

        when(jobRepository.save(any(Job.class))).thenAnswer(invocation -> {
            Job j = invocation.getArgument(0);
            j.setId(UUID.randomUUID());
            return j;
        });
        when(jobStepRepository.saveAll(anyList())).thenAnswer(invocation -> invocation.getArgument(0));

        CreateJobRequest request = new CreateJobRequest("JOB-105", "Acme Doors");
        JobResponse response = jobService.createJob(request);

        verify(jobStepRepository).saveAll(jobStepsCaptor.capture());
        JobStep savedStep = jobStepsCaptor.getValue().get(0);
        assertThat(savedStep.getCompletedBy()).isNull();
        assertThat(savedStep.getCompletedAt()).isNull();

        JobStepResponse stepResponse = response.steps().get(0);
        assertThat(stepResponse.completedBy()).isNull();
        assertThat(stepResponse.completedAt()).isNull();
        assertThat(response.completedAt()).isNull();
    }

    @Test
    @DisplayName("7. Inactive master process steps are NOT copied")
    void inactiveMasterProcessStepsAreNotCopied() {
        mockManagerInRepo();
        when(jobRepository.findByJobNumber("JOB-106")).thenReturn(Optional.empty());

        // ProcessStepRepository.findByIsActive(true) only returns active steps
        ProcessStep activeStep = ProcessStep.builder().id(UUID.randomUUID()).name("Cutting").stepOrder(1).isActive(true).build();
        when(processStepRepository.findByIsActive(true)).thenReturn(List.of(activeStep));

        when(jobRepository.save(any(Job.class))).thenAnswer(invocation -> {
            Job j = invocation.getArgument(0);
            j.setId(UUID.randomUUID());
            return j;
        });
        when(jobStepRepository.saveAll(anyList())).thenAnswer(invocation -> invocation.getArgument(0));

        CreateJobRequest request = new CreateJobRequest("JOB-106", "Acme Doors");
        JobResponse response = jobService.createJob(request);

        verify(processStepRepository).findByIsActive(true);
        verify(jobStepRepository).saveAll(jobStepsCaptor.capture());
        assertThat(jobStepsCaptor.getValue()).hasSize(1);
        assertThat(jobStepsCaptor.getValue().get(0).getStepName()).isEqualTo("Cutting");
    }

    @Test
    @DisplayName("8. Empty active process creates a job with zero JobSteps")
    void emptyActiveProcessCreatesJobWithZeroSteps() {
        mockManagerInRepo();
        when(jobRepository.findByJobNumber("JOB-107")).thenReturn(Optional.empty());
        when(processStepRepository.findByIsActive(true)).thenReturn(List.of());

        when(jobRepository.save(any(Job.class))).thenAnswer(invocation -> {
            Job j = invocation.getArgument(0);
            j.setId(UUID.randomUUID());
            return j;
        });

        CreateJobRequest request = new CreateJobRequest("JOB-107", "Acme Doors");
        JobResponse response = jobService.createJob(request);

        verify(jobStepRepository, never()).saveAll(anyList());
        assertThat(response.status()).isEqualTo(JobStatus.IN_PROGRESS);
        assertThat(response.steps()).isEmpty();
    }

    @Test
    @DisplayName("9. Duplicate job number returns 409")
    void duplicateJobNumberReturns409() {
        when(jobRepository.findByJobNumber("JOB-DUPE"))
                .thenReturn(Optional.of(Job.builder().jobNumber("JOB-DUPE").build()));

        CreateJobRequest request = new CreateJobRequest("JOB-DUPE", "Acme Doors");
        ResponseStatusException ex = assertThrows(ResponseStatusException.class, () -> jobService.createJob(request));

        assertThat(ex.getStatusCode()).isEqualTo(HttpStatus.CONFLICT);
        assertThat(ex.getReason()).contains("Job number already exists");
        verify(jobRepository, never()).save(any());
        verify(jobStepRepository, never()).saveAll(any());
    }

    @Test
    @DisplayName("10. Job number and company name are trimmed")
    void jobNumberAndCompanyNameAreTrimmed() {
        mockManagerInRepo();
        when(jobRepository.findByJobNumber("JOB-TRIM")).thenReturn(Optional.empty());
        when(processStepRepository.findByIsActive(true)).thenReturn(List.of());

        when(jobRepository.save(any(Job.class))).thenAnswer(invocation -> {
            Job j = invocation.getArgument(0);
            j.setId(UUID.randomUUID());
            return j;
        });

        CreateJobRequest request = new CreateJobRequest("   JOB-TRIM   ", "   Trimmed Company   ");
        jobService.createJob(request);

        verify(jobRepository).findByJobNumber("JOB-TRIM");
        verify(jobRepository).save(jobCaptor.capture());
        Job saved = jobCaptor.getValue();
        assertThat(saved.getJobNumber()).isEqualTo("JOB-TRIM");
        assertThat(saved.getCompanyName()).isEqualTo("Trimmed Company");
    }

    @Test
    @DisplayName("11. Snapshot remains independent from later ProcessStep changes")
    void snapshotRemainsIndependentFromLaterProcessStepChanges() {
        mockManagerInRepo();
        when(jobRepository.findByJobNumber("JOB-SNAP")).thenReturn(Optional.empty());

        ProcessStep ps1 = ProcessStep.builder().id(UUID.randomUUID()).name("Cutting").stepOrder(1).isActive(true).build();
        ProcessStep ps2 = ProcessStep.builder().id(UUID.randomUUID()).name("Bending").stepOrder(2).isActive(true).build();
        when(processStepRepository.findByIsActive(true)).thenReturn(new ArrayList<>(List.of(ps1, ps2)));

        when(jobRepository.save(any(Job.class))).thenAnswer(invocation -> {
            Job j = invocation.getArgument(0);
            j.setId(UUID.randomUUID());
            return j;
        });
        when(jobStepRepository.saveAll(anyList())).thenAnswer(invocation -> invocation.getArgument(0));

        CreateJobRequest request = new CreateJobRequest("JOB-SNAP", "Snapshot Co");
        JobResponse response = jobService.createJob(request);

        verify(jobStepRepository).saveAll(jobStepsCaptor.capture());
        List<JobStep> snapshotSteps = jobStepsCaptor.getValue();

        // Mutate the original master ProcessStep objects as if admin edited them later
        ps1.setName("Changed Cutting Name");
        ps1.setStepOrder(99);
        ps2.setName("Finishing");

        // The snapshot JobSteps must retain original values
        assertThat(snapshotSteps.get(0).getStepName()).isEqualTo("Cutting");
        assertThat(snapshotSteps.get(0).getStepOrder()).isEqualTo(1);
        assertThat(snapshotSteps.get(1).getStepName()).isEqualTo("Bending");
        assertThat(snapshotSteps.get(1).getStepOrder()).isEqualTo(2);

        // JobResponse also reflects original snapshot
        assertThat(response.steps().get(0).stepName()).isEqualTo("Cutting");
        assertThat(response.steps().get(1).stepName()).isEqualTo("Bending");
    }

    @Test
    @DisplayName("12. Job creation is transactional: if step save fails, exception propagates")
    void transactionRollbackOnStepFailure() {
        mockManagerInRepo();
        when(jobRepository.findByJobNumber("JOB-TX")).thenReturn(Optional.empty());

        ProcessStep ps = ProcessStep.builder().id(UUID.randomUUID()).name("Cutting").stepOrder(1).isActive(true).build();
        when(processStepRepository.findByIsActive(true)).thenReturn(List.of(ps));

        when(jobRepository.save(any(Job.class))).thenAnswer(invocation -> {
            Job j = invocation.getArgument(0);
            j.setId(UUID.randomUUID());
            return j;
        });
        when(jobStepRepository.saveAll(anyList())).thenThrow(new RuntimeException("DB error saving steps"));

        CreateJobRequest request = new CreateJobRequest("JOB-TX", "Acme Doors");

        RuntimeException thrown = assertThrows(RuntimeException.class, () -> jobService.createJob(request));
        assertThat(thrown.getMessage()).isEqualTo("DB error saving steps");
    }

    @Test
    @DisplayName("13. Non-manager authentication is rejected")
    void nonManagerAuthenticationIsRejected() {
        User workerUser = User.builder()
                .id(UUID.randomUUID())
                .name("Bob Worker")
                .email("worker@example.com")
                .role(UserRole.WORKER)
                .isActive(true)
                .build();

        UsernamePasswordAuthenticationToken auth =
                new UsernamePasswordAuthenticationToken(workerUser.getEmail(), null, List.of());
        SecurityContextHolder.getContext().setAuthentication(auth);

        when(jobRepository.findByJobNumber("JOB-REJECT")).thenReturn(Optional.empty());
        when(userRepository.findByEmail("worker@example.com")).thenReturn(Optional.of(workerUser));

        CreateJobRequest request = new CreateJobRequest("JOB-REJECT", "Acme Doors");

        assertThrows(AccessDeniedException.class, () -> jobService.createJob(request));
        verify(jobRepository, never()).save(any());
        verify(jobStepRepository, never()).saveAll(any());
    }

    @Test
    @DisplayName("14. Unauthenticated request is rejected")
    void unauthenticatedRequestIsRejected() {
        SecurityContextHolder.clearContext();

        when(jobRepository.findByJobNumber("JOB-NOAUTH")).thenReturn(Optional.empty());

        CreateJobRequest request = new CreateJobRequest("JOB-NOAUTH", "Acme Doors");

        ResponseStatusException ex = assertThrows(ResponseStatusException.class, () -> jobService.createJob(request));
        assertThat(ex.getStatusCode()).isEqualTo(HttpStatus.UNAUTHORIZED);
    }
}
