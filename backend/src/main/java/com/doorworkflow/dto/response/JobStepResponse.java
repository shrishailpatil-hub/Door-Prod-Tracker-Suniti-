package com.doorworkflow.dto.response;

import com.doorworkflow.enums.JobStepStatus;

import java.time.Instant;
import java.util.UUID;

public record JobStepResponse(
        UUID id,
        String stepName,
        Integer stepOrder,
        JobStepStatus status,
        String completedBy,
        Instant completedAt
) {
}
