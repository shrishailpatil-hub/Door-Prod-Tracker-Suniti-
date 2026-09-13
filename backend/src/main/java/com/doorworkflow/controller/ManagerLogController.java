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
@RequestMapping("/api/manager/logs")
@PreAuthorize("hasRole('MANAGER')")
public class ManagerLogController {

    private final LogExportService logExportService;

    public ManagerLogController(LogExportService logExportService) {
        this.logExportService = logExportService;
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
