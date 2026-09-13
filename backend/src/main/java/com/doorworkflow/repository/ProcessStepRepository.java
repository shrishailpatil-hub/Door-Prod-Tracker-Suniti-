package com.doorworkflow.repository;

import com.doorworkflow.entity.ProcessStep;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

public interface ProcessStepRepository extends JpaRepository<ProcessStep, UUID> {
    List<ProcessStep> findByIsActive(Boolean isActive);
    List<ProcessStep> findAllByOrderByStepOrderAsc();
    Optional<ProcessStep> findById(UUID id);
}
