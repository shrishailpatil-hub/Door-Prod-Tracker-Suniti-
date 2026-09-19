package com.doorworkflow.repository;

import com.doorworkflow.entity.FcmToken;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.Optional;
import java.util.UUID;
import java.util.List;

@Repository
public interface FcmTokenRepository extends JpaRepository<FcmToken, UUID> {
    Optional<FcmToken> findByToken(String token);
    List<FcmToken> findAllByUser_RoleInAndUser_IsActive(List<com.doorworkflow.enums.UserRole> roles, boolean isActive);
}
