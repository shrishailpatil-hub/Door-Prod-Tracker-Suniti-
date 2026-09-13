package com.doorworkflow.dto.request;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

public record AddChalanRequest(
        @NotBlank(message = "Chalan number is required")
        @Size(max = 100, message = "Chalan number must not exceed 100 characters")
        String chalanNumber
) {
}
