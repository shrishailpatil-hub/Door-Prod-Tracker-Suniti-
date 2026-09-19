package com.doorworkflow.service;

import com.doorworkflow.entity.FcmToken;
import com.doorworkflow.entity.User;
import com.doorworkflow.repository.FcmTokenRepository;
import com.doorworkflow.repository.UserRepository;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.web.server.ResponseStatusException;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContextHolder;
import java.util.Optional;

@Service
public class FcmTokenService {
    private final FcmTokenRepository tokenRepository;
    private final UserRepository userRepository;

    public FcmTokenService(FcmTokenRepository tokenRepository, UserRepository userRepository) {
        this.tokenRepository = tokenRepository;
        this.userRepository = userRepository;
    }

    // Register or update token for the currently authenticated user
    public void registerToken(String token) {
        User user = getAuthenticatedUser();
        Optional<FcmToken> existing = tokenRepository.findByToken(token);
        if (existing.isPresent()) {
            FcmToken fcmToken = existing.get();
            fcmToken.setUser(user);
            tokenRepository.save(fcmToken);
        } else {
            FcmToken fcmToken = FcmToken.builder()
                    .user(user)
                    .token(token)
                    .build();
            tokenRepository.save(fcmToken);
        }
    }

    public void removeToken(String token) {
        tokenRepository.findByToken(token).ifPresent(tokenRepository::delete);
    }

    private User getAuthenticatedUser() {
        Authentication auth = SecurityContextHolder.getContext().getAuthentication();
        if (auth == null || !auth.isAuthenticated() || "anonymousUser".equals(auth.getPrincipal())) {
            throw new ResponseStatusException(HttpStatus.UNAUTHORIZED, "Authentication required");
        }
        String email = auth.getName();
        return userRepository.findByEmail(email)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.UNAUTHORIZED, "User not found"));
    }
}
