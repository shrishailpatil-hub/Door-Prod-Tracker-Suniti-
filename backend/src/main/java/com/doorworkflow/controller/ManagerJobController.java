package com.doorworkflow.controller;

import com.doorworkflow.dto.request.CreateJobRequest;
import com.doorworkflow.dto.response.JobResponse;
import com.doorworkflow.service.JobService;
import jakarta.validation.Valid;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.UUID;

@RestController
@RequestMapping("/api/manager/jobs")
@PreAuthorize("hasRole('MANAGER')")
public class ManagerJobController {

    private final JobService jobService;

    public ManagerJobController(JobService jobService) {
        this.jobService = jobService;
    }

    @PostMapping
    public ResponseEntity<JobResponse> createJob(@Valid @RequestBody CreateJobRequest request) {
        JobResponse response = jobService.createJob(request);
        return ResponseEntity.ok(response);
    }

    @GetMapping
    public ResponseEntity<List<JobResponse>> listJobs() {
        List<JobResponse> jobs = jobService.listJobs();
        return ResponseEntity.ok(jobs);
    }

    @GetMapping("/{id}")
    public ResponseEntity<JobResponse> getJob(@PathVariable UUID id) {
        JobResponse response = jobService.getJob(id);
        return ResponseEntity.ok(response);
    }

    @PutMapping("/{id}/cancel")
    public ResponseEntity<JobResponse> cancelJob(@PathVariable UUID id) {
        JobResponse response = jobService.cancelJob(id);
        return ResponseEntity.ok(response);
    }

    @PutMapping("/{id}/reopen")
    public ResponseEntity<JobResponse> reopenJob(@PathVariable UUID id,
                                                 @Valid @RequestBody com.doorworkflow.dto.request.ReopenJobRequest request) {
        JobResponse response = jobService.reopenJob(id, request);
        return ResponseEntity.ok(response);
    }

    @GetMapping("/logs")
    public ResponseEntity<List<com.doorworkflow.dto.response.JobStepHistoryResponse>> getAllLogs() {
        List<com.doorworkflow.dto.response.JobStepHistoryResponse> logs = jobService.getJobLogs(null);
        return ResponseEntity.ok(logs);
    }

    @GetMapping("/{id}/logs")
    public ResponseEntity<List<com.doorworkflow.dto.response.JobStepHistoryResponse>> getJobLogs(@PathVariable UUID id) {
        List<com.doorworkflow.dto.response.JobStepHistoryResponse> logs = jobService.getJobLogs(id);
        return ResponseEntity.ok(logs);
    }
}
