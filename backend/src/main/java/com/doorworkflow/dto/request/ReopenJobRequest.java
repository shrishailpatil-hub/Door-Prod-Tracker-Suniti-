package com.doorworkflow.dto.request;

import jakarta.validation.constraints.NotNull;

import java.util.UUID;

public record ReopenJobRequest(
        @NotNull(message = "Step ID is required")
        UUID stepId
) {
}
