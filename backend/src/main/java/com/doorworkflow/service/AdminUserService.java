package com.doorworkflow.service;

import com.doorworkflow.dto.request.CreateUserRequest;
import com.doorworkflow.dto.request.UpdateUserRequest;
import com.doorworkflow.dto.request.UpdateUserStatusRequest;
import com.doorworkflow.dto.response.UserResponse;
import com.doorworkflow.entity.User;
import com.doorworkflow.exception.EmailAlreadyExistsException;
import com.doorworkflow.repository.UserRepository;

import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.web.server.ResponseStatusException;

import java.util.List;
import java.util.UUID;
import java.util.stream.Collectors;

import static org.springframework.http.HttpStatus.*;

@Service
public class AdminUserService {

    private final UserRepository userRepository;
    private final PasswordEncoder passwordEncoder;

    public AdminUserService(UserRepository userRepository, PasswordEncoder passwordEncoder) {
        this.userRepository = userRepository;
        this.passwordEncoder = passwordEncoder;
    }

    public UserResponse createUser(CreateUserRequest request) {
        if (userRepository.existsByEmail(request.email())) {
            throw new EmailAlreadyExistsException("Email already exists");
        }
        User user = User.builder()
                .name(request.name())
                .email(request.email())
                .password(passwordEncoder.encode(request.password()))
                .role(request.role())
                .isActive(true)
                .build();
        User saved = userRepository.save(user);
        return mapToResponse(saved);
    }

    public List<UserResponse> listUsers() {
        return userRepository.findAll()
                .stream()
                .map(this::mapToResponse)
                .collect(Collectors.toList());
    }

    public UserResponse getUser(UUID id) {
        User user = userRepository.findById(id)
                .orElseThrow(() -> new ResponseStatusException(NOT_FOUND, "User not found"));
        return mapToResponse(user);
    }

    public UserResponse updateUser(UUID id, UpdateUserRequest request) {
        User user = userRepository.findById(id)
                .orElseThrow(() -> new ResponseStatusException(NOT_FOUND, "User not found"));
        if (!user.getEmail().equals(request.email())) {
            if (userRepository.existsByEmail(request.email())) {
                throw new EmailAlreadyExistsException("Email already exists");
            }
            user.setEmail(request.email());
        }
        user.setName(request.name());
        user.setRole(request.role());
        if (request.password() != null && !request.password().isBlank()) {
            user.setPassword(passwordEncoder.encode(request.password()));
        }
        User saved = userRepository.save(user);
        return mapToResponse(saved);
    }

    public UserResponse updateStatus(UUID id, UpdateUserStatusRequest request) {
        User target = userRepository.findById(id)
                .orElseThrow(() -> new ResponseStatusException(NOT_FOUND, "User not found"));
        var auth = SecurityContextHolder.getContext().getAuthentication();
        if (auth != null && auth.getName().equals(target.getEmail())) {
            if (Boolean.FALSE.equals(request.isActive())) {
                throw new ResponseStatusException(BAD_REQUEST, "Admin cannot deactivate own account");
            }
        }
        target.setIsActive(request.isActive());
        User saved = userRepository.save(target);
        return mapToResponse(saved);
    }

    private UserResponse mapToResponse(User user) {
        return new UserResponse(
                user.getId(),
                user.getName(),
                user.getEmail(),
                user.getRole(),
                user.getIsActive(),
                user.getCreatedAt(),
                user.getUpdatedAt()
        );
    }
}
