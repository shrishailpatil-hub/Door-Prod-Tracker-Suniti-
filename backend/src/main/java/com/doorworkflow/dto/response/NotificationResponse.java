package com.doorworkflow.dto.response;

import java.time.Instant;
import java.util.UUID;

public record NotificationResponse(
        UUID id,
        UUID jobId,
        String message,
        Boolean isRead,
        Instant createdAt
) {
}
