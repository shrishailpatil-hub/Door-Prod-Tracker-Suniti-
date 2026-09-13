package com.doorworkflow.dto.request;

import com.doorworkflow.enums.UserRole;
import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

public record UpdateUserRequest(
        @NotBlank(message = "Name cannot be blank")
        String name,

        @NotBlank(message = "Email cannot be blank")
        @Email(message = "Invalid email format")
        String email,

        @NotNull(message = "Role is required")
        UserRole role,

        // Optional password; if present must be at least 8 characters
        @Size(min = 8, message = "Password must be at least 8 characters")
        String password
) {}
