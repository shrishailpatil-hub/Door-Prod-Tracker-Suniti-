package com.doorworkflow.entity;

import com.doorworkflow.enums.JobStepAction;
import jakarta.persistence.*;
import lombok.*;
import org.hibernate.annotations.CreationTimestamp;

import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "job_step_history")
@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class JobStepHistory {

    @Id
    @GeneratedValue
    private UUID id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "job_id", nullable = false)
    private Job job;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "job_step_id", nullable = true)
    private JobStep jobStep;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    private JobStepAction action;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "performed_by", nullable = false)
    private User performedBy;

    @CreationTimestamp
    @Column(nullable = false, updatable = false)
    private Instant createdAt;
}
