package com.doorworkflow.controller;

import com.doorworkflow.dto.request.CreateProcessStepRequest;
import com.doorworkflow.dto.request.UpdateProcessStepRequest;
import com.doorworkflow.dto.response.ProcessStepResponse;
import com.doorworkflow.service.AdminProcessStepService;
import jakarta.validation.Valid;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.UUID;

@RestController
@RequestMapping("/api/admin/process-steps")
@PreAuthorize("hasRole('ADMIN')")
public class AdminProcessStepController {

    private final AdminProcessStepService adminProcessStepService;

    public AdminProcessStepController(AdminProcessStepService adminProcessStepService) {
        this.adminProcessStepService = adminProcessStepService;
    }

    @PostMapping
    public ResponseEntity<ProcessStepResponse> create(@Valid @RequestBody CreateProcessStepRequest request) {
        ProcessStepResponse response = adminProcessStepService.createProcessStep(request);
        return ResponseEntity.ok(response);
    }

    @GetMapping
    public ResponseEntity<List<ProcessStepResponse>> list() {
        List<ProcessStepResponse> list = adminProcessStepService.listProcessSteps();
        return ResponseEntity.ok(list);
    }

    @GetMapping("/{id}")
    public ResponseEntity<ProcessStepResponse> get(@PathVariable UUID id) {
        ProcessStepResponse response = adminProcessStepService.getProcessStep(id);
        return ResponseEntity.ok(response);
    }

    @PutMapping("/{id}")
    public ResponseEntity<ProcessStepResponse> update(@PathVariable UUID id,
                                                      @Valid @RequestBody UpdateProcessStepRequest request) {
        ProcessStepResponse response = adminProcessStepService.updateProcessStep(id, request);
        return ResponseEntity.ok(response);
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<ProcessStepResponse> deactivate(@PathVariable UUID id) {
        ProcessStepResponse response = adminProcessStepService.deactivateProcessStep(id);
        return ResponseEntity.ok(response);
    }

    @PostMapping("/{id}/reactivate")
    public ResponseEntity<ProcessStepResponse> reactivate(@PathVariable UUID id) {
        ProcessStepResponse response = adminProcessStepService.reactivateProcessStep(id);
        return ResponseEntity.ok(response);
    }
}
