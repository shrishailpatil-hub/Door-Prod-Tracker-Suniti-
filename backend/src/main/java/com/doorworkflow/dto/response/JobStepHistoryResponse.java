package com.doorworkflow.dto.response;

import com.doorworkflow.enums.JobStepAction;

import java.time.Instant;
import java.util.UUID;

public record JobStepHistoryResponse(
        UUID id,
        UUID jobId,
        UUID jobStepId,
        String stepName,
        JobStepAction action,
        String performedBy,
        Instant createdAt
) {
}
