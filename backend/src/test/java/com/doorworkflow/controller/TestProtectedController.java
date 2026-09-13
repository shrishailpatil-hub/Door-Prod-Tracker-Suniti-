package com.doorworkflow.controller;

import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
public class TestProtectedController {

    @GetMapping("/api/admin/test")
    @PreAuthorize("hasRole('ADMIN')")
    public String adminEndpoint() {
        return "admin ok";
    }

    @GetMapping("/api/manager/test")
    @PreAuthorize("hasRole('MANAGER')")
    public String managerEndpoint() {
        return "manager ok";
    }

    @GetMapping("/api/worker/test")
    @PreAuthorize("hasRole('WORKER')")
    public String workerEndpoint() {
        return "worker ok";
    }
}
