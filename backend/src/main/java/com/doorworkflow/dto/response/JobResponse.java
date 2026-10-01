package com.doorworkflow.dto.response;

import com.doorworkflow.enums.JobStatus;

import java.time.Instant;
import java.util.List;
import java.util.UUID;

public record JobResponse(
        UUID id,
        String jobNumber,
        String companyName,
        JobStatus status,
        String createdBy,
        Instant createdAt,
        Instant updatedAt,
        Instant completedAt,
        String chalanNumber,
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
        String vehicleDetails,
        List<JobStepResponse> steps
) {
}
