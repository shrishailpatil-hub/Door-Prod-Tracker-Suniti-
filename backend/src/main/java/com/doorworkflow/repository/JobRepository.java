package com.doorworkflow.repository;

import com.doorworkflow.entity.Job;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

public interface JobRepository extends JpaRepository<Job, UUID> {
    Optional<Job> findByJobNumber(String jobNumber);
    List<Job> findByStatus(com.doorworkflow.enums.JobStatus status);
    List<Job> findByStatusOrderByCreatedAtDesc(com.doorworkflow.enums.JobStatus status);
    List<Job> findAllByOrderByCreatedAtDesc();
}
