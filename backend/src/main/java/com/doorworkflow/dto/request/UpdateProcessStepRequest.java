package com.doorworkflow.dto.request;

import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

/**
 * DTO for updating an existing process step.
 * Both fields are required as per the specification.
 */
public record UpdateProcessStepRequest(
        @NotBlank(message = "Name is required")
        @Size(max = 255, message = "Name must be at most 255 characters")
        String name,
        @NotNull(message = "Step order is required")
        @Min(value = 1, message = "Step order must be at least 1")
        Integer stepOrder) {
}
