package com.doorworkflow.dto.request;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

public record CreateJobRequest(
        @NotBlank(message = "Job number is required")
        @Size(max = 255, message = "Job number must be at most 255 characters")
        String jobNumber,

        @NotBlank(message = "Company name is required")
        @Size(max = 255, message = "Company name must be at most 255 characters")
        String companyName,

        String fr,
        String deliveryAddress,
        String poNo,
        String gstNo,
        java.time.LocalDate poDate,
        java.time.LocalDate orderDate,
        java.time.LocalDate deliveryDate,
        String doors,
        String doorLeaf,
        String colourShade,
        String vehicleDetails
) {
}
