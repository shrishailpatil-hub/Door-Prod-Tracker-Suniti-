package com.doorworkflow.entity;

import com.doorworkflow.enums.JobStatus;
import jakarta.persistence.*;
import lombok.*;
import org.hibernate.annotations.CreationTimestamp;
import org.hibernate.annotations.UpdateTimestamp;

import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "jobs")
@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class Job {

    @Id
    @GeneratedValue
    private UUID id;

    @Column(name = "job_number", nullable = false, unique = true)
    private String jobNumber;

    @Column(name = "company_name", nullable = false)
    private String companyName;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    private JobStatus status;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "created_by", nullable = false)
    private User createdBy;

    @CreationTimestamp
    @Column(nullable = false, updatable = false)
    private Instant createdAt;

    @UpdateTimestamp
    private Instant updatedAt;

    @Column(name = "completed_at")
    private Instant completedAt;

    @Column(name = "chalan_number", length = 100)
    private String chalanNumber;

    @Column(name = "fr")
    private String fr;

    @Column(name = "delivery_address")
    private String deliveryAddress;

    @Column(name = "po_no")
    private String poNo;

    @Column(name = "gst_no")
    private String gstNo;

    @Column(name = "po_date")
    private java.time.LocalDate poDate;

    @Column(name = "order_date")
    private java.time.LocalDate orderDate;

    @Column(name = "delivery_date")
    private java.time.LocalDate deliveryDate;

    @Column(name = "doors")
    private String doors;

    @Column(name = "door_leaf")
    private String doorLeaf;

    @Column(name = "colour_shade")
    private String colourShade;

    @Column(name = "vehicle_details")
    private String vehicleDetails;
}
