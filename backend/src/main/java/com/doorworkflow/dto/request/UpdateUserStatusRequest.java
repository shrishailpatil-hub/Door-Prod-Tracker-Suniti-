package com.doorworkflow.dto.request;

import jakarta.validation.constraints.NotNull;

public record UpdateUserStatusRequest(
        @NotNull(message = "isActive must be provided")
        Boolean isActive
) {}
