package com.doorworkflow.repository;

import com.doorworkflow.entity.User;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

public interface UserRepository extends JpaRepository<User, UUID> {
    Optional<User> findByEmail(String email);
    boolean existsByEmail(String email);
    boolean existsByIsActive(Boolean isActive);
    List<User> findByRoleAndIsActive(com.doorworkflow.enums.UserRole role, Boolean isActive);
}
