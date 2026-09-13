package com.doorworkflow.repository;

import com.doorworkflow.entity.JobStepHistory;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

public interface JobStepHistoryRepository extends JpaRepository<JobStepHistory, UUID> {
    List<JobStepHistory> findByJobId(UUID jobId);
    List<JobStepHistory> findByJobIdOrderByCreatedAtDesc(UUID jobId);
    List<JobStepHistory> findAllByOrderByCreatedAtDesc();

    @org.springframework.data.jpa.repository.Query("SELECT h FROM JobStepHistory h JOIN FETCH h.job j LEFT JOIN FETCH h.jobStep s JOIN FETCH h.performedBy u ORDER BY h.createdAt DESC, h.id DESC")
    List<JobStepHistory> findAllWithDetailsOrderByCreatedAtDesc();

    List<JobStepHistory> findByJobStepId(UUID jobStepId);
    Optional<JobStepHistory> findById(UUID id);
}
