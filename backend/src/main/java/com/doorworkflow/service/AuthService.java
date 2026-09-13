package com.doorworkflow.service;

import com.doorworkflow.dto.request.LoginRequest;
import com.doorworkflow.dto.response.LoginResponse;
import com.doorworkflow.entity.User;
import com.doorworkflow.repository.UserRepository;
import com.doorworkflow.security.JwtService;
import org.springframework.security.authentication.BadCredentialsException;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;

import java.util.Optional;

@Service
public class AuthService {

    private final UserRepository userRepository;
    private final PasswordEncoder passwordEncoder;
    private final JwtService jwtService;

    public AuthService(UserRepository userRepository, PasswordEncoder passwordEncoder, JwtService jwtService) {
        this.userRepository = userRepository;
        this.passwordEncoder = passwordEncoder;
        this.jwtService = jwtService;
    }

    /**
     * Authenticate a user and return a {@link LoginResponse} containing JWT and user info.
     *
     * @param request login request containing email and password
     * @return login response DTO
     * @throws BadCredentialsException if credentials are invalid or user is inactive
     */
    public LoginResponse login(LoginRequest request) {
        Optional<User> optionalUser = userRepository.findByEmail(request.getEmail());
        User user = optionalUser.filter(User::getIsActive)
                .orElseThrow(() -> new BadCredentialsException("Invalid email or password"));

        if (!passwordEncoder.matches(request.getPassword(), user.getPassword())) {
            throw new BadCredentialsException("Invalid email or password");
        }

        String token = jwtService.generateToken(user);
        return new LoginResponse(token, user.getId(), user.getName(), user.getRole().name());
    }
}
