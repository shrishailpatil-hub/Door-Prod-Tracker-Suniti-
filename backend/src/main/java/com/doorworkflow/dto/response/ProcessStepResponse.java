package com.doorworkflow.dto.response;

import java.time.Instant;
import java.util.UUID;

/**
 * DTO representing a process step, used in responses.
 */
public record ProcessStepResponse(
        UUID id,
        String name,
        Integer stepOrder,
        Boolean isActive,
        Instant createdAt,
        Instant updatedAt) {
}
