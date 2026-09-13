-- Flyway migration V2: Add chalan_number to jobs and support job-level audit in job_step_history

ALTER TABLE jobs ADD COLUMN chalan_number VARCHAR(100);

-- Allow job_step_id to be NULL so job-level actions (CHALAN_ADDED, JOB_COMPLETED) can be recorded in history
ALTER TABLE job_step_history ALTER COLUMN job_step_id DROP NOT NULL;
