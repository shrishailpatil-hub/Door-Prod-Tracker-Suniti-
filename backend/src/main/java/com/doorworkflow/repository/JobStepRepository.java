package com.doorworkflow.repository;

import com.doorworkflow.entity.JobStep;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

public interface JobStepRepository extends JpaRepository<JobStep, UUID> {
    List<JobStep> findByJobId(UUID jobId);
    List<JobStep> findByJobIdOrderByStepOrderAsc(UUID jobId);
    Optional<JobStep> findById(UUID id);
}
