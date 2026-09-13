package com.doorworkflow.controller;

import com.doorworkflow.service.LogExportService;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/admin/logs")
@PreAuthorize("hasRole('ADMIN')")
public class AdminLogController {

    private final LogExportService logExportService;
    private final com.doorworkflow.repository.JobStepHistoryRepository jobStepHistoryRepository;

    public AdminLogController(LogExportService logExportService,
                              com.doorworkflow.repository.JobStepHistoryRepository jobStepHistoryRepository) {
        this.logExportService = logExportService;
        this.jobStepHistoryRepository = jobStepHistoryRepository;
    }

    @GetMapping
    public ResponseEntity<java.util.List<com.doorworkflow.dto.response.JobStepHistoryResponse>> getAllLogs() {
        java.util.List<com.doorworkflow.dto.response.JobStepHistoryResponse> logs = jobStepHistoryRepository.findAllByOrderByCreatedAtDesc()
                .stream()
                .map(h -> new com.doorworkflow.dto.response.JobStepHistoryResponse(
                        h.getId(),
                        h.getJob() != null ? h.getJob().getId() : null,
                        h.getJobStep() != null ? h.getJobStep().getId() : null,
                        h.getJobStep() != null ? h.getJobStep().getStepName() : null,
                        h.getAction(),
                        h.getPerformedBy() != null ? h.getPerformedBy().getName() : null,
                        h.getCreatedAt()
                ))
                .collect(java.util.stream.Collectors.toList());
        return ResponseEntity.ok(logs);
    }

    @GetMapping("/export")
    public ResponseEntity<byte[]> exportLogs() {
        byte[] excelBytes = logExportService.generateJobLogsExcel();
        return ResponseEntity.ok()
                .contentType(MediaType.parseMediaType("application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"))
                .header(HttpHeaders.CONTENT_DISPOSITION, "attachment; filename=\"job_logs.xlsx\"")
                .body(excelBytes);
    }
}
