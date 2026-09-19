package com.doorworkflow.controller;

import com.doorworkflow.dto.request.FcmTokenRequest;
import com.doorworkflow.service.FcmTokenService;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/fcm")
public class FcmTokenController {
    private final FcmTokenService tokenService;

    public FcmTokenController(FcmTokenService tokenService) {
        this.tokenService = tokenService;
    }

    @PostMapping("/token")
    public ResponseEntity<Void> registerToken(@RequestBody FcmTokenRequest request) {
        tokenService.registerToken(request.getToken());
        return ResponseEntity.ok().build();
    }
}
