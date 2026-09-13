package com.doorworkflow.dto.response;

import com.doorworkflow.enums.UserRole;
import java.time.Instant;
import java.util.UUID;

public record UserResponse(
        UUID id,
        String name,
        String email,
        UserRole role,
        Boolean isActive,
        Instant createdAt,
        Instant updatedAt
) {}
