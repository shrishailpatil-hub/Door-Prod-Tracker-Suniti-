package com.doorworkflow.controller;

import com.doorworkflow.dto.response.JobResponse;
import com.doorworkflow.service.JobService;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.UUID;

@RestController
@RequestMapping("/api/worker")
@PreAuthorize("hasRole('WORKER')")
public class WorkerJobController {

    private final JobService jobService;

    public WorkerJobController(JobService jobService) {
        this.jobService = jobService;
    }

    @GetMapping("/jobs")
    public ResponseEntity<List<JobResponse>> listJobs() {
        List<JobResponse> jobs = jobService.listActiveJobsForWorker();
        return ResponseEntity.ok(jobs);
    }

    @GetMapping("/jobs/{id}")
    public ResponseEntity<JobResponse> getJob(@PathVariable UUID id) {
        JobResponse response = jobService.getWorkerJob(id);
        return ResponseEntity.ok(response);
    }

    @PutMapping("/job-steps/{stepId}/complete")
    public ResponseEntity<JobResponse> completeJobStep(@PathVariable UUID stepId) {
        JobResponse response = jobService.completeJobStep(stepId);
        return ResponseEntity.ok(response);
    }

    @PutMapping("/job-steps/{stepId}/undo")
    public ResponseEntity<JobResponse> undoJobStep(@PathVariable UUID stepId) {
        JobResponse response = jobService.undoJobStep(stepId);
        return ResponseEntity.ok(response);
    }

    @PutMapping("/jobs/{id}/chalan")
    public ResponseEntity<JobResponse> addChalan(
            @PathVariable UUID id,
            @jakarta.validation.Valid @RequestBody com.doorworkflow.dto.request.AddChalanRequest request) {
        JobResponse response = jobService.addChalan(id, request);
        return ResponseEntity.ok(response);
    }

    @PutMapping("/jobs/{id}/complete")
    public ResponseEntity<JobResponse> completeJob(@PathVariable UUID id) {
        JobResponse response = jobService.completeJob(id);
        return ResponseEntity.ok(response);
    }
}
