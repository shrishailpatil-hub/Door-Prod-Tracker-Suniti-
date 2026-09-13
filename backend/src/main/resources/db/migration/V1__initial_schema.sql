/* Flyway migration V1 - initial schema */
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Users table
CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(255) NOT NULL,
    email VARCHAR(255) NOT NULL UNIQUE,
    password VARCHAR(255) NOT NULL,
    role VARCHAR(50) NOT NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Process steps master table
CREATE TABLE process_steps (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(255) NOT NULL,
    step_order INTEGER NOT NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Jobs table
CREATE TABLE jobs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    job_number VARCHAR(100) NOT NULL UNIQUE,
    company_name VARCHAR(255) NOT NULL,
    status VARCHAR(50) NOT NULL,
    created_by UUID NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    completed_at TIMESTAMP WITH TIME ZONE,
    CONSTRAINT fk_job_created_by FOREIGN KEY (created_by) REFERENCES users(id)
);

-- Job steps (snapshot of process steps per job)
CREATE TABLE job_steps (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    job_id UUID NOT NULL,
    step_name VARCHAR(255) NOT NULL,
    step_order INTEGER NOT NULL,
    status VARCHAR(50) NOT NULL,
    completed_by UUID,
    completed_at TIMESTAMP WITH TIME ZONE,
    version BIGINT NOT NULL,
    CONSTRAINT fk_jobstep_job FOREIGN KEY (job_id) REFERENCES jobs(id),
    CONSTRAINT fk_jobstep_completed_by FOREIGN KEY (completed_by) REFERENCES users(id)
);

-- Notifications
CREATE TABLE notifications (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL,
    job_id UUID NOT NULL,
    message TEXT NOT NULL,
    is_read BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_notification_user FOREIGN KEY (user_id) REFERENCES users(id),
    CONSTRAINT fk_notification_job FOREIGN KEY (job_id) REFERENCES jobs(id)
);

-- Job step history (audit trail)
CREATE TABLE job_step_history (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    job_id UUID NOT NULL,
    job_step_id UUID NOT NULL,
    action VARCHAR(50) NOT NULL,
    performed_by UUID NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_history_job FOREIGN KEY (job_id) REFERENCES jobs(id),
    CONSTRAINT fk_history_job_step FOREIGN KEY (job_step_id) REFERENCES job_steps(id),
    CONSTRAINT fk_history_performed_by FOREIGN KEY (performed_by) REFERENCES users(id)
);

-- Create indexes for foreign keys for performance
CREATE INDEX idx_job_created_by ON jobs(created_by);
CREATE INDEX idx_jobstep_job ON job_steps(job_id);
CREATE INDEX idx_jobstep_completed_by ON job_steps(completed_by);
CREATE INDEX idx_notification_user ON notifications(user_id);
CREATE INDEX idx_notification_job ON notifications(job_id);
CREATE INDEX idx_history_job ON job_step_history(job_id);
CREATE INDEX idx_history_job_step ON job_step_history(job_step_id);
CREATE INDEX idx_history_performed_by ON job_step_history(performed_by);
