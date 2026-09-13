package com.doorworkflow.service;

import com.doorworkflow.dto.request.AddChalanRequest;
import com.doorworkflow.dto.request.CreateJobRequest;
import com.doorworkflow.dto.request.ReopenJobRequest;
import com.doorworkflow.dto.response.JobResponse;
import com.doorworkflow.dto.response.JobStepHistoryResponse;
import com.doorworkflow.dto.response.JobStepResponse;
import com.doorworkflow.entity.Job;
import com.doorworkflow.entity.JobStep;
import com.doorworkflow.entity.JobStepHistory;
import com.doorworkflow.entity.Notification;
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
import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.security.access.AccessDeniedException;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

import java.util.ArrayList;
import java.util.Comparator;
import java.util.List;
import java.util.UUID;
import java.util.stream.Collectors;

@Service
public class JobService {

    private final JobRepository jobRepository;
    private final JobStepRepository jobStepRepository;
    private final JobStepHistoryRepository jobStepHistoryRepository;
    private final NotificationRepository notificationRepository;
    private final ProcessStepRepository processStepRepository;
    private final UserRepository userRepository;

    public JobService(JobRepository jobRepository,
                      JobStepRepository jobStepRepository,
                      JobStepHistoryRepository jobStepHistoryRepository,
                      NotificationRepository notificationRepository,
                      ProcessStepRepository processStepRepository,
                      UserRepository userRepository) {
        this.jobRepository = jobRepository;
        this.jobStepRepository = jobStepRepository;
        this.jobStepHistoryRepository = jobStepHistoryRepository;
        this.notificationRepository = notificationRepository;
        this.processStepRepository = processStepRepository;
        this.userRepository = userRepository;
    }

    private User getAuthenticatedManager(String accessDeniedMessage) {
        Authentication auth = SecurityContextHolder.getContext().getAuthentication();
        if (auth == null || !auth.isAuthenticated() || "anonymousUser".equals(auth.getPrincipal())) {
            throw new ResponseStatusException(HttpStatus.UNAUTHORIZED, "Authentication required");
        }

        User authenticatedUser = userRepository.findByEmail(auth.getName())
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.UNAUTHORIZED, "User not found"));

        if (authenticatedUser.getRole() != UserRole.MANAGER) {
            throw new AccessDeniedException(accessDeniedMessage);
        }
        return authenticatedUser;
    }

    private User getAuthenticatedWorker(String accessDeniedMessage) {
        Authentication auth = SecurityContextHolder.getContext().getAuthentication();
        if (auth == null || !auth.isAuthenticated() || "anonymousUser".equals(auth.getPrincipal())) {
            throw new ResponseStatusException(HttpStatus.UNAUTHORIZED, "Authentication required");
        }

        User authenticatedUser = userRepository.findByEmail(auth.getName())
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.UNAUTHORIZED, "User not found"));

        if (authenticatedUser.getRole() != UserRole.WORKER) {
            throw new AccessDeniedException(accessDeniedMessage);
        }
        return authenticatedUser;
    }

    @Transactional
    public JobResponse createJob(@Valid CreateJobRequest request) {
        String jobNumber = request.jobNumber().trim();
        String companyName = request.companyName().trim();

        // 1. Check duplicate job number
        if (jobRepository.findByJobNumber(jobNumber).isPresent()) {
            throw new ResponseStatusException(HttpStatus.CONFLICT, "Job number already exists");
        }

        // 2 & 3. Authenticated user and MANAGER role check
        User authenticatedUser = getAuthenticatedManager("Only managers can create jobs");

        // 4. Load current active process steps ordered by stepOrder
        List<ProcessStep> activeProcessSteps = processStepRepository.findByIsActive(true)
                .stream()
                .sorted(Comparator.comparingInt(ProcessStep::getStepOrder))
                .collect(Collectors.toList());

        // 5. Create new Job
        Job job = Job.builder()
                .jobNumber(jobNumber)
                .companyName(companyName)
                .status(JobStatus.IN_PROGRESS)
                .createdBy(authenticatedUser)
                .completedAt(null)
                .build();

        Job savedJob = jobRepository.save(job);

        // 6. Snapshot active process steps to JobSteps
        List<JobStep> jobStepsToSave = new ArrayList<>();
        for (ProcessStep ps : activeProcessSteps) {
            JobStep jobStep = JobStep.builder()
                    .job(savedJob)
                    .stepName(ps.getName())
                    .stepOrder(ps.getStepOrder())
                    .status(JobStepStatus.PENDING)
                    .completedBy(null)
                    .completedAt(null)
                    .build();
            jobStepsToSave.add(jobStep);
        }

        List<JobStep> savedJobSteps = jobStepsToSave.isEmpty()
                ? List.of()
                : jobStepRepository.saveAll(jobStepsToSave);

        // 7 & 8. Return response
        return mapToJobResponse(savedJob, savedJobSteps);
    }

    @Transactional
    public JobResponse cancelJob(UUID id) {
        getAuthenticatedManager("Only managers can cancel jobs");

        Job job = jobRepository.findById(id)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Job not found"));

        if (job.getStatus() == JobStatus.CANCELLED) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Job is already cancelled");
        }
        if (job.getStatus() == JobStatus.WORK_DONE || job.getStatus() == JobStatus.JOB_COMPLETED) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Cannot cancel a completed job");
        }

        job.setStatus(JobStatus.CANCELLED);
        Job savedJob = jobRepository.save(job);

        List<JobStep> steps = jobStepRepository.findByJobIdOrderByStepOrderAsc(savedJob.getId());
        return mapToJobResponse(savedJob, steps);
    }

    @Transactional
    public JobResponse reopenJob(UUID id, @Valid ReopenJobRequest request) {
        User manager = getAuthenticatedManager("Only managers can reopen jobs");

        Job job = jobRepository.findById(id)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Job not found"));

        if (job.getStatus() != JobStatus.WORK_DONE) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Only WORK_DONE jobs can be reopened");
        }

        UUID targetStepId = request.stepId();
        List<JobStep> steps = jobStepRepository.findByJobIdOrderByStepOrderAsc(job.getId());

        JobStep targetStep = steps.stream()
                .filter(s -> s.getId().equals(targetStepId))
                .findFirst()
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.BAD_REQUEST, "Step does not belong to this job"));

        int targetOrder = targetStep.getStepOrder();

        List<JobStep> stepsToUpdate = new ArrayList<>();
        for (JobStep step : steps) {
            if (step.getStepOrder() >= targetOrder) {
                step.setStatus(JobStepStatus.PENDING);
                step.setCompletedBy(null);
                step.setCompletedAt(null);
                stepsToUpdate.add(step);
            }
        }

        jobStepRepository.saveAll(stepsToUpdate);

        // Update Job state
        job.setStatus(JobStatus.IN_PROGRESS);
        job.setCompletedAt(null);
        Job savedJob = jobRepository.save(job);

        // Record history entry for the reopening action
        JobStepHistory history = JobStepHistory.builder()
                .job(savedJob)
                .jobStep(targetStep)
                .action(JobStepAction.REOPENED)
                .performedBy(manager)
                .build();
        jobStepHistoryRepository.save(history);

        return mapToJobResponse(savedJob, steps);
    }

    @Transactional(readOnly = true)
    public List<JobResponse> listJobs() {
        List<Job> jobs = jobRepository.findAllByOrderByCreatedAtDesc();
        return jobs.stream()
                .map(job -> {
                    List<JobStep> steps = jobStepRepository.findByJobIdOrderByStepOrderAsc(job.getId());
                    return mapToJobResponse(job, steps);
                })
                .collect(Collectors.toList());
    }

    @Transactional(readOnly = true)
    public JobResponse getJob(UUID id) {
        Job job = jobRepository.findById(id)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Job not found"));
        List<JobStep> steps = jobStepRepository.findByJobIdOrderByStepOrderAsc(job.getId());
        return mapToJobResponse(job, steps);
    }

    @Transactional(readOnly = true)
    public List<JobResponse> listActiveJobsForWorker() {
        getAuthenticatedWorker("Only workers can access active worker jobs");
        List<Job> activeJobs = jobRepository.findByStatusOrderByCreatedAtDesc(JobStatus.IN_PROGRESS);
        return activeJobs.stream()
                .map(job -> {
                    List<JobStep> steps = jobStepRepository.findByJobIdOrderByStepOrderAsc(job.getId());
                    return mapToJobResponse(job, steps);
                })
                .collect(Collectors.toList());
    }

    @Transactional(readOnly = true)
    public JobResponse getWorkerJob(UUID id) {
        getAuthenticatedWorker("Only workers can access worker job details");
        return getJob(id);
    }

    @Transactional
    public JobResponse completeJobStep(UUID stepId) {
        User worker = getAuthenticatedWorker("Only workers can complete job steps");

        JobStep step = jobStepRepository.findById(stepId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Job step not found"));

        Job job = step.getJob();
        if (job.getStatus() != JobStatus.IN_PROGRESS) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Cannot modify step for a job that is not IN_PROGRESS");
        }

        if (step.getStatus() == JobStepStatus.COMPLETED) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Step is already completed");
        }

        List<JobStep> allSteps = jobStepRepository.findByJobIdOrderByStepOrderAsc(job.getId());

        // Find the FIRST pending step in stepOrder
        JobStep firstPending = allSteps.stream()
                .filter(s -> s.getStatus() == JobStepStatus.PENDING)
                .findFirst()
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.BAD_REQUEST, "No pending steps found"));

        if (!firstPending.getId().equals(step.getId())) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Cannot complete a later step before earlier steps");
        }

        java.time.Instant now = java.time.Instant.now();
        step.setStatus(JobStepStatus.COMPLETED);
        step.setCompletedBy(worker);
        step.setCompletedAt(now);
        jobStepRepository.save(step);

        // Check if this was the final pending step
        boolean hasRemainingPending = allSteps.stream()
                .anyMatch(s -> !s.getId().equals(step.getId()) && s.getStatus() == JobStepStatus.PENDING);

        if (!hasRemainingPending) {
            job.setStatus(JobStatus.WORK_DONE);
            job.setCompletedAt(now);
            jobRepository.save(job);
        }

        // Record history entry
        JobStepHistory history = JobStepHistory.builder()
                .job(job)
                .jobStep(step)
                .action(JobStepAction.COMPLETED)
                .performedBy(worker)
                .build();
        jobStepHistoryRepository.save(history);

        // PART B: Database notifications for active managers
        List<User> activeManagers = userRepository.findByRoleAndIsActive(UserRole.MANAGER, true);
        String workerName = worker.getName();
        String notifMessage = "Job #" + job.getJobNumber() + ": " + step.getStepName() + " completed by " + workerName + ".";
        List<Notification> notificationsToSave = new ArrayList<>();
        for (User manager : activeManagers) {
            Notification notification = Notification.builder()
                    .user(manager)
                    .job(job)
                    .message(notifMessage)
                    .isRead(false)
                    .build();
            notificationsToSave.add(notification);
        }
        if (!notificationsToSave.isEmpty()) {
            notificationRepository.saveAll(notificationsToSave);
        }

        List<JobStep> updatedSteps = jobStepRepository.findByJobIdOrderByStepOrderAsc(job.getId());
        return mapToJobResponse(job, updatedSteps);
    }

    @Transactional(readOnly = true)
    public List<JobStepHistoryResponse> getJobLogs(UUID jobId) {
        getAuthenticatedManager("Only managers can view job logs");
        if (jobId != null) {
            if (!jobRepository.existsById(jobId)) {
                throw new ResponseStatusException(HttpStatus.NOT_FOUND, "Job not found");
            }
            return jobStepHistoryRepository.findByJobIdOrderByCreatedAtDesc(jobId)
                    .stream()
                    .map(this::mapToHistoryResponse)
                    .collect(Collectors.toList());
        } else {
            return jobStepHistoryRepository.findAllByOrderByCreatedAtDesc()
                    .stream()
                    .map(this::mapToHistoryResponse)
                    .collect(Collectors.toList());
        }
    }

    private JobStepHistoryResponse mapToHistoryResponse(JobStepHistory h) {
        return new JobStepHistoryResponse(
                h.getId(),
                h.getJob() != null ? h.getJob().getId() : null,
                h.getJobStep() != null ? h.getJobStep().getId() : null,
                h.getJobStep() != null ? h.getJobStep().getStepName() : null,
                h.getAction(),
                h.getPerformedBy() != null ? h.getPerformedBy().getName() : null,
                h.getCreatedAt()
        );
    }

    @Transactional
    public JobResponse undoJobStep(UUID stepId) {
        User worker = getAuthenticatedWorker("Only workers can undo job steps");

        JobStep step = jobStepRepository.findById(stepId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Job step not found"));

        Job job = step.getJob();
        if (job.getStatus() != JobStatus.IN_PROGRESS) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Cannot undo step when job is not IN_PROGRESS");
        }

        if (step.getStatus() != JobStepStatus.COMPLETED) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Step is not completed");
        }

        List<JobStep> allSteps = jobStepRepository.findByJobIdOrderByStepOrderAsc(job.getId());

        // Find the LATEST completed step (highest stepOrder among completed steps)
        JobStep latestCompleted = allSteps.stream()
                .filter(s -> s.getStatus() == JobStepStatus.COMPLETED)
                .max(Comparator.comparingInt(JobStep::getStepOrder))
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.BAD_REQUEST, "No completed steps found"));

        if (!latestCompleted.getId().equals(step.getId())) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Cannot undo an earlier step while a later step remains completed");
        }

        step.setStatus(JobStepStatus.PENDING);
        step.setCompletedBy(null);
        step.setCompletedAt(null);
        jobStepRepository.save(step);

        // Record history entry
        JobStepHistory history = JobStepHistory.builder()
                .job(job)
                .jobStep(step)
                .action(JobStepAction.UNDONE)
                .performedBy(worker)
                .build();
        jobStepHistoryRepository.save(history);

        List<JobStep> updatedSteps = jobStepRepository.findByJobIdOrderByStepOrderAsc(job.getId());
        return mapToJobResponse(job, updatedSteps);
    }

    @Transactional
    public JobResponse addChalan(UUID jobId, @Valid AddChalanRequest request) {
        User worker = getAuthenticatedWorker("Only workers can add chalan number");

        Job job = jobRepository.findById(jobId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Job not found"));

        if (job.getStatus() == JobStatus.IN_PROGRESS) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Chalan number can only be added when job is in WORK_DONE status");
        }
        if (job.getStatus() == JobStatus.CANCELLED) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Cannot add chalan to a cancelled job");
        }
        if (job.getStatus() == JobStatus.JOB_COMPLETED) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Cannot modify chalan after job is completed");
        }
        if (job.getStatus() != JobStatus.WORK_DONE) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Chalan number can only be added when job is in WORK_DONE status");
        }

        if (request == null || request.chalanNumber() == null || request.chalanNumber().trim().isEmpty()) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Chalan number cannot be blank");
        }

        String trimmedChalan = request.chalanNumber().trim();
        if (trimmedChalan.length() > 100) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Chalan number cannot exceed 100 characters");
        }

        job.setChalanNumber(trimmedChalan);
        Job savedJob = jobRepository.save(job);

        // Record history entry
        JobStepHistory history = JobStepHistory.builder()
                .job(savedJob)
                .jobStep(null)
                .action(JobStepAction.CHALAN_ADDED)
                .performedBy(worker)
                .build();
        jobStepHistoryRepository.save(history);

        List<JobStep> steps = jobStepRepository.findByJobIdOrderByStepOrderAsc(savedJob.getId());
        return mapToJobResponse(savedJob, steps);
    }

    @Transactional
    public JobResponse completeJob(UUID jobId) {
        User worker = getAuthenticatedWorker("Only workers can perform final job completion");

        Job job = jobRepository.findById(jobId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Job not found"));

        if (job.getStatus() == JobStatus.JOB_COMPLETED) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Job is already completed");
        }
        if (job.getStatus() == JobStatus.CANCELLED) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Cannot complete a cancelled job");
        }
        if (job.getStatus() == JobStatus.IN_PROGRESS) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Cannot complete job that is IN_PROGRESS");
        }
        if (job.getStatus() != JobStatus.WORK_DONE) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Job must be in WORK_DONE status to complete");
        }

        List<JobStep> steps = jobStepRepository.findByJobIdOrderByStepOrderAsc(job.getId());
        boolean anyPending = steps.stream().anyMatch(s -> s.getStatus() != JobStepStatus.COMPLETED);
        if (anyPending) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "All manufacturing steps must be completed before final job completion");
        }

        if (job.getChalanNumber() == null || job.getChalanNumber().trim().isEmpty()) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Chalan number is required before final job completion");
        }

        job.setStatus(JobStatus.JOB_COMPLETED);
        job.setCompletedAt(java.time.Instant.now());
        Job savedJob = jobRepository.save(job);

        // Record history entry
        JobStepHistory history = JobStepHistory.builder()
                .job(savedJob)
                .jobStep(null)
                .action(JobStepAction.JOB_COMPLETED)
                .performedBy(worker)
                .build();
        jobStepHistoryRepository.save(history);

        return mapToJobResponse(savedJob, steps);
    }

    private JobResponse mapToJobResponse(Job job, List<JobStep> steps) {
        List<JobStepResponse> stepResponses = steps.stream()
                .sorted(Comparator.comparingInt(JobStep::getStepOrder))
                .map(s -> new JobStepResponse(
                        s.getId(),
                        s.getStepName(),
                        s.getStepOrder(),
                        s.getStatus(),
                        s.getCompletedBy() != null ? s.getCompletedBy().getName() : null,
                        s.getCompletedAt()
                ))
                .collect(Collectors.toList());

        return new JobResponse(
                job.getId(),
                job.getJobNumber(),
                job.getCompanyName(),
                job.getStatus(),
                job.getCreatedBy() != null ? job.getCreatedBy().getName() : null,
                job.getCreatedAt(),
                job.getUpdatedAt(),
                job.getCompletedAt(),
                job.getChalanNumber(),
                stepResponses
        );
    }
}
