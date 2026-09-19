package com.doorworkflow.service;

import com.doorworkflow.entity.Job;
import com.doorworkflow.entity.User;
import com.doorworkflow.repository.FcmTokenRepository;
import com.doorworkflow.repository.UserRepository;
import com.google.firebase.messaging.BatchResponse;
import com.google.firebase.messaging.FirebaseMessaging;
import com.google.firebase.messaging.FirebaseMessagingException;
import com.google.firebase.messaging.MulticastMessage;
import com.google.firebase.messaging.Notification;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;

import java.util.List;
import java.util.stream.Collectors;

@Service
public class PushNotificationService {
    private static final Logger log = LoggerFactory.getLogger(PushNotificationService.class);
    private final FcmTokenRepository tokenRepository;
    private final UserRepository userRepository;

    public PushNotificationService(FcmTokenRepository tokenRepository,
                                   UserRepository userRepository) {
        this.tokenRepository = tokenRepository;
        this.userRepository = userRepository;
    }

    public void sendBendingCompletedNotification(Job job) {
        // Obtain FirebaseMessaging instance if FirebaseApp initialized
        FirebaseMessaging firebaseMessaging;
        try {
            firebaseMessaging = FirebaseMessaging.getInstance();
        } catch (IllegalStateException e) {
            log.warn("FirebaseMessaging not initialized; skipping push notification.");
            return;
        }

        // Gather tokens for active ADMIN and MANAGER users
        List<User> recipients = userRepository.findByRoleInAndIsActive(
                List.of(com.doorworkflow.enums.UserRole.ADMIN,
                        com.doorworkflow.enums.UserRole.MANAGER), true);
        if (recipients.isEmpty()) {
            log.info("No active admin/manager users for push notification.");
            return;
        }

        List<String> tokens = tokenRepository
                .findAllByUser_RoleInAndUser_IsActive(
                        List.of(com.doorworkflow.enums.UserRole.ADMIN,
                                com.doorworkflow.enums.UserRole.MANAGER), true)
                .stream()
                .map(t -> t.getToken())
                .collect(Collectors.toList());

        if (tokens.isEmpty()) {
            log.info("No FCM tokens registered for admin/manager users.");
            return;
        }

        String title = "Bending Completed";
        String body = "Bending for Job card " + job.getJobNumber() + " done. Please collect payment";

        MulticastMessage message = MulticastMessage.builder()
                .setNotification(Notification.builder()
                        .setTitle(title)
                        .setBody(body)
                        .build())
                .putData("jobId", job.getId().toString())
                .putData("jobNumber", job.getJobNumber())
                .addAllTokens(tokens)
                .build();

        try {
            BatchResponse response = firebaseMessaging.sendMulticast(message);
            var responses = response.getResponses();
            for (int i = 0; i < responses.size(); i++) {
                var resp = responses.get(i);
                if (!resp.isSuccessful()) {
                    String errorCode = resp.getException().getErrorCode().name();
                    if ("REGISTRATION_TOKEN_NOT_REGISTERED".equals(errorCode)
                            || "registration-token-not-registered".equalsIgnoreCase(errorCode)) {
                        String badToken = tokens.get(i);
                        tokenRepository.findByToken(badToken).ifPresent(tokenRepository::delete);
                        log.info("Removed unregistered FCM token: {}", badToken);
                    } else {
                        log.warn("FCM send error for token {}: {}", tokens.get(i), errorCode);
                    }
                }
            }
        } catch (FirebaseMessagingException e) {
            log.error("Failed to send bending completed notification", e);
        }
    }
}
