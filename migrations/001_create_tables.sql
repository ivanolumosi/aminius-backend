-- ============================================
-- PostgreSQL Database Schema
-- ============================================

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- Agent Table
CREATE TABLE agent (
    agent_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    first_name VARCHAR(50) NOT NULL,
    last_name VARCHAR(50) NOT NULL,
    email VARCHAR(100) NOT NULL UNIQUE,
    password_hash VARCHAR(256) NOT NULL, -- store securely hashed password
    phone VARCHAR(20) NOT NULL,
    avatar TEXT, -- Base64 or file path
    created_date TIMESTAMPTZ DEFAULT NOW(),
    modified_date TIMESTAMPTZ DEFAULT NOW(),
    is_active BOOLEAN DEFAULT TRUE
);
CREATE TABLE agent_settings (
    setting_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    agent_id UUID NOT NULL,
    dark_mode BOOLEAN DEFAULT FALSE,
    email_notifications BOOLEAN DEFAULT TRUE,
    sms_notifications BOOLEAN DEFAULT TRUE,
    whatsapp_notifications BOOLEAN DEFAULT TRUE,
    push_notifications BOOLEAN DEFAULT TRUE,
    sound_enabled BOOLEAN DEFAULT TRUE,
    created_date TIMESTAMPTZ DEFAULT NOW(),
    modified_date TIMESTAMPTZ DEFAULT NOW(),
    CONSTRAINT fk_agent FOREIGN KEY (agent_id) 
        REFERENCES agent(agent_id) 
        ON DELETE CASCADE
);
CREATE EXTENSION IF NOT EXISTS pgcrypto;


-- ============================================
-- Client Management Tables
-- ============================================

-- Policy Types Table (referenced by other tables, so create first)
CREATE TABLE policy_types (
    type_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    type_name VARCHAR(50) NOT NULL,
    is_active BOOLEAN DEFAULT TRUE,
    created_date TIMESTAMPTZ DEFAULT NOW()
);

-- Policy Categories Table
CREATE TABLE policy_categories (
    category_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    category_name VARCHAR(50) NOT NULL,
    description VARCHAR(200),
    is_active BOOLEAN DEFAULT TRUE,
    created_date TIMESTAMPTZ DEFAULT NOW()
);

-- Insurance Companies Table
CREATE TABLE insurance_companies (
    company_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_name VARCHAR(100) NOT NULL,
    is_active BOOLEAN DEFAULT TRUE,
    created_date TIMESTAMPTZ DEFAULT NOW()
);

-- Policy Catalog Table
CREATE TABLE policy_catalog (
    policy_catalog_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    agent_id UUID NOT NULL,
    policy_name VARCHAR(100) NOT NULL,
    company_id UUID NOT NULL,
    notes TEXT,
    is_active BOOLEAN DEFAULT TRUE,
    created_date TIMESTAMPTZ DEFAULT NOW(),
    modified_date TIMESTAMPTZ,
    category_id UUID,
    type_id UUID,
    CONSTRAINT fk_policy_catalog_agent FOREIGN KEY (agent_id) REFERENCES agent(agent_id) ON DELETE CASCADE,
    CONSTRAINT fk_policy_catalog_company FOREIGN KEY (company_id) REFERENCES insurance_companies(company_id),
    CONSTRAINT fk_policy_catalog_category FOREIGN KEY (category_id) REFERENCES policy_categories(category_id),
    CONSTRAINT fk_policy_catalog_type FOREIGN KEY (type_id) REFERENCES policy_types(type_id)
);

-- Policy Templates Table
CREATE TABLE policy_templates (
    template_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    agent_id UUID NOT NULL,
    template_name VARCHAR(100) NOT NULL,
    default_term_months INTEGER,
    default_premium DECIMAL(18, 2),
    coverage_description TEXT,
    terms TEXT,
    is_active BOOLEAN DEFAULT TRUE,
    created_date TIMESTAMPTZ DEFAULT NOW(),
    category_id UUID,
    policy_catalog_id UUID,
    type_id UUID,
    CONSTRAINT fk_policy_templates_agent FOREIGN KEY (agent_id) REFERENCES agent(agent_id) ON DELETE CASCADE,
    CONSTRAINT fk_policy_templates_category FOREIGN KEY (category_id) REFERENCES policy_categories(category_id),
    CONSTRAINT fk_policy_templates_catalog FOREIGN KEY (policy_catalog_id) REFERENCES policy_catalog(policy_catalog_id),
    CONSTRAINT fk_policy_templates_type FOREIGN KEY (type_id) REFERENCES policy_types(type_id)
);

-- Clients Table
CREATE TABLE clients (
    client_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    agent_id UUID NOT NULL,
    first_name VARCHAR(50) NOT NULL,
    surname VARCHAR(50) NOT NULL,
    last_name VARCHAR(50) NOT NULL,
    phone_number VARCHAR(20) NOT NULL,
    email VARCHAR(100) NOT NULL,
    address VARCHAR(500) NOT NULL,
    national_id VARCHAR(20) NOT NULL,
    date_of_birth DATE NOT NULL,
    is_client BOOLEAN NOT NULL DEFAULT FALSE, -- FALSE = Prospect, TRUE = Client
    insurance_type VARCHAR(50) NOT NULL DEFAULT 'N/A',
    notes TEXT,
    created_date TIMESTAMPTZ DEFAULT NOW(),
    modified_date TIMESTAMPTZ DEFAULT NOW(),
    is_active BOOLEAN DEFAULT TRUE,
    CONSTRAINT fk_clients_agent FOREIGN KEY (agent_id) REFERENCES agent(agent_id) ON DELETE CASCADE
);

-- Client Policies Table
CREATE TABLE client_policies (
    policy_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    client_id UUID NOT NULL,
    policy_name VARCHAR(100) NOT NULL,
    status VARCHAR(20) NOT NULL,
    start_date DATE NOT NULL,
    end_date DATE NOT NULL,
    notes TEXT,
    created_date TIMESTAMPTZ DEFAULT NOW(),
    modified_date TIMESTAMPTZ,
    is_active BOOLEAN DEFAULT TRUE,
    policy_catalog_id UUID,
    type_id UUID,
    company_id UUID,
    CONSTRAINT fk_client_policies_client FOREIGN KEY (client_id) REFERENCES clients(client_id) ON DELETE CASCADE,
    CONSTRAINT fk_client_policies_catalog FOREIGN KEY (policy_catalog_id) REFERENCES policy_catalog(policy_catalog_id),
    CONSTRAINT fk_client_policies_type FOREIGN KEY (type_id) REFERENCES policy_types(type_id),
    CONSTRAINT fk_client_policies_company FOREIGN KEY (company_id) REFERENCES insurance_companies(company_id)
);

-- Appointments Table
CREATE TABLE appointments (
    appointment_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    client_id UUID NOT NULL,
    agent_id UUID NOT NULL,
    client_name VARCHAR(150) NOT NULL, -- Computed from client names
    client_phone VARCHAR(20),
    title VARCHAR(200) NOT NULL,
    description TEXT,
    appointment_date DATE NOT NULL,
    start_time TIME NOT NULL,
    end_time TIME NOT NULL,
    location VARCHAR(200),
    type VARCHAR(50) NOT NULL CHECK (type IN ('Call', 'Meeting', 'Site Visit', 'Policy Review', 'Claim Processing')),
    status VARCHAR(20) NOT NULL CHECK (status IN ('Scheduled', 'Confirmed', 'In Progress', 'Completed', 'Cancelled', 'Rescheduled')),
    priority VARCHAR(10) NOT NULL CHECK (priority IN ('High', 'Medium', 'Low')),
    notes TEXT,
    reminder_set BOOLEAN DEFAULT FALSE,
    created_date TIMESTAMPTZ DEFAULT NOW(),
    modified_date TIMESTAMPTZ DEFAULT NOW(),
    is_active BOOLEAN DEFAULT TRUE,
    CONSTRAINT fk_appointments_client FOREIGN KEY (client_id) REFERENCES clients(client_id),
    CONSTRAINT fk_appointments_agent FOREIGN KEY (agent_id) REFERENCES agent(agent_id)
);

-- ============================================
-- Reminders and Messaging Tables
-- ============================================

-- Reminder Settings Table
CREATE TABLE reminder_settings (
    reminder_setting_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    agent_id UUID NOT NULL,
    reminder_type VARCHAR(50) NOT NULL CHECK (reminder_type IN ('Policy Expiry', 'Birthday', 'Appointment', 'Call', 'Visit')),
    is_enabled BOOLEAN DEFAULT TRUE,
    days_before INTEGER DEFAULT 1,
    time_of_day TIME DEFAULT '09:00',
    repeat_daily BOOLEAN DEFAULT FALSE,
    created_date TIMESTAMPTZ DEFAULT NOW(),
    modified_date TIMESTAMPTZ DEFAULT NOW(),
    CONSTRAINT fk_reminder_settings_agent FOREIGN KEY (agent_id) REFERENCES agent(agent_id) ON DELETE CASCADE
);

-- Reminders Table
CREATE TABLE reminders (
    reminder_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    client_id UUID,
    appointment_id UUID,
    agent_id UUID NOT NULL,
    reminder_type VARCHAR(50) NOT NULL CHECK (reminder_type IN ('Call', 'Visit', 'Policy Expiry', 'Birthday', 'Holiday', 'Custom')),
    title VARCHAR(200) NOT NULL,
    description TEXT,
    reminder_date DATE NOT NULL,
    reminder_time TIME,
    client_name VARCHAR(150),
    priority VARCHAR(10) NOT NULL CHECK (priority IN ('High', 'Medium', 'Low')) DEFAULT 'Medium',
    status VARCHAR(20) NOT NULL CHECK (status IN ('Active', 'Completed', 'Cancelled')) DEFAULT 'Active',
    enable_sms BOOLEAN DEFAULT FALSE,
    enable_whatsapp BOOLEAN DEFAULT FALSE,
    enable_push_notification BOOLEAN DEFAULT TRUE,
    advance_notice VARCHAR(20) DEFAULT '1 day',
    custom_message TEXT,
    auto_send BOOLEAN DEFAULT FALSE,
    notes TEXT,
    created_date TIMESTAMPTZ DEFAULT NOW(),
    modified_date TIMESTAMPTZ DEFAULT NOW(),
    completed_date TIMESTAMPTZ,
    CONSTRAINT fk_reminders_client FOREIGN KEY (client_id) REFERENCES clients(client_id),
    CONSTRAINT fk_reminders_appointment FOREIGN KEY (appointment_id) REFERENCES appointments(appointment_id),
    CONSTRAINT fk_reminders_agent FOREIGN KEY (agent_id) REFERENCES agent(agent_id) ON DELETE CASCADE
);

-- Automated Messages Table
CREATE TABLE automated_messages (
    message_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    agent_id UUID NOT NULL,
    message_type VARCHAR(50) NOT NULL CHECK (message_type IN ('Birthday', 'Holiday', 'Policy Expiry', 'Appointment', 'Custom')),
    title VARCHAR(200) NOT NULL,
    template TEXT NOT NULL,
    scheduled_date TIMESTAMPTZ NOT NULL,
    delivery_method VARCHAR(20) NOT NULL CHECK (delivery_method IN ('SMS', 'WhatsApp', 'Both')),
    status VARCHAR(20) NOT NULL CHECK (status IN ('Scheduled', 'Sent', 'Failed')) DEFAULT 'Scheduled',
    recipients TEXT, -- JSON array of phone numbers
    created_date TIMESTAMPTZ DEFAULT NOW(),
    modified_date TIMESTAMPTZ DEFAULT NOW(),
    sent_date TIMESTAMPTZ,
    CONSTRAINT fk_automated_messages_agent FOREIGN KEY (agent_id) REFERENCES agent(agent_id) ON DELETE CASCADE
);

-- Message Recipients Table (For tracking individual message deliveries)
CREATE TABLE message_recipients (
    recipient_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    message_id UUID NOT NULL,
    client_id UUID,
    phone_number VARCHAR(20) NOT NULL,
    delivery_status VARCHAR(20) DEFAULT 'Pending' CHECK (delivery_status IN ('Pending', 'Sent', 'Delivered', 'Failed')),
    delivery_date TIMESTAMPTZ,
    error_message VARCHAR(500),
    CONSTRAINT fk_message_recipients_message FOREIGN KEY (message_id) REFERENCES automated_messages(message_id) ON DELETE CASCADE,
    CONSTRAINT fk_message_recipients_client FOREIGN KEY (client_id) REFERENCES clients(client_id)
);

-- Daily Notes Table
CREATE TABLE daily_notes (
    note_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    agent_id UUID NOT NULL,
    note_date DATE NOT NULL,
    notes TEXT,
    created_date TIMESTAMPTZ DEFAULT NOW(),
    modified_date TIMESTAMPTZ DEFAULT NOW(),
    CONSTRAINT fk_daily_notes_agent FOREIGN KEY (agent_id) REFERENCES agent(agent_id) ON DELETE CASCADE,
    CONSTRAINT uq_daily_notes_agent_date UNIQUE(agent_id, note_date) -- One note per agent per day
);

-- ============================================
-- Analytics and Dashboard Tables
-- ============================================

-- Activity Log Table (For tracking all user activities)
CREATE TABLE activity_log (
    activity_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    agent_id UUID NOT NULL,
    activity_type VARCHAR(50) NOT NULL, -- 'appointment_created', 'client_added', 'reminder_completed', etc.
    entity_type VARCHAR(50), -- 'client', 'appointment', 'reminder', etc.
    entity_id UUID,
    description VARCHAR(500),
    activity_date TIMESTAMPTZ DEFAULT NOW(),
    additional_data TEXT, -- JSON data for complex activity details
    CONSTRAINT fk_activity_log_agent FOREIGN KEY (agent_id) REFERENCES agent(agent_id) ON DELETE CASCADE
);

-- Dashboard Statistics Table (For caching daily statistics)
CREATE TABLE dashboard_statistics (
    stat_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    agent_id UUID NOT NULL,
    stat_date DATE NOT NULL,
    total_clients INTEGER DEFAULT 0,
    total_prospects INTEGER DEFAULT 0,
    active_policies INTEGER DEFAULT 0,
    today_appointments INTEGER DEFAULT 0,
    week_appointments INTEGER DEFAULT 0,
    month_appointments INTEGER DEFAULT 0,
    completed_appointments INTEGER DEFAULT 0,
    pending_reminders INTEGER DEFAULT 0,
    today_birthdays INTEGER DEFAULT 0,
    expiring_policies INTEGER DEFAULT 0,
    created_date TIMESTAMPTZ DEFAULT NOW(),
    updated_date TIMESTAMPTZ DEFAULT NOW(),
    CONSTRAINT fk_dashboard_statistics_agent FOREIGN KEY (agent_id) REFERENCES agent(agent_id) ON DELETE CASCADE,
    CONSTRAINT uq_dashboard_statistics_agent_date UNIQUE(agent_id, stat_date)
);

-- Performance Metrics Table (For tracking agent performance over time)
CREATE TABLE performance_metrics (
    metric_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    agent_id UUID NOT NULL,
    metric_date DATE NOT NULL,
    new_clients_added INTEGER DEFAULT 0,
    prospects_converted INTEGER DEFAULT 0,
    appointments_completed INTEGER DEFAULT 0,
    policies_sold INTEGER DEFAULT 0,
    reminders_completed INTEGER DEFAULT 0,
    messages_sent INTEGER DEFAULT 0,
    client_interactions INTEGER DEFAULT 0,
    created_date TIMESTAMPTZ DEFAULT NOW(),
    CONSTRAINT fk_performance_metrics_agent FOREIGN KEY (agent_id) REFERENCES agent(agent_id) ON DELETE CASCADE,
    CONSTRAINT uq_performance_metrics_agent_date UNIQUE(agent_id, metric_date)
);

-- Task Summary Table (For dashboard task tracking)
CREATE TABLE task_summary (
    task_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    agent_id UUID NOT NULL,
    task_date DATE NOT NULL,
    task_type VARCHAR(50) NOT NULL, -- 'call', 'visit', 'follow_up', 'renewal'
    task_description VARCHAR(500),
    priority VARCHAR(10) CHECK (priority IN ('High', 'Medium', 'Low')) DEFAULT 'Medium',
    status VARCHAR(20) CHECK (status IN ('Pending', 'In Progress', 'Completed', 'Cancelled')) DEFAULT 'Pending',
    client_id UUID,
    appointment_id UUID,
    due_time TIME,
    completed_date TIMESTAMPTZ,
    created_date TIMESTAMPTZ DEFAULT NOW(),
    CONSTRAINT fk_task_summary_agent FOREIGN KEY (agent_id) REFERENCES agent(agent_id) ON DELETE CASCADE,
    CONSTRAINT fk_task_summary_client FOREIGN KEY (client_id) REFERENCES clients(client_id),
    CONSTRAINT fk_task_summary_appointment FOREIGN KEY (appointment_id) REFERENCES appointments(appointment_id)
);

-- Monthly Reports Table (For generating monthly performance reports)
CREATE TABLE monthly_reports (
    report_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    agent_id UUID NOT NULL,
    report_month DATE NOT NULL, -- First day of the month
    total_clients_added INTEGER DEFAULT 0,
    total_prospects_added INTEGER DEFAULT 0,
    prospects_converted INTEGER DEFAULT 0,
    total_appointments INTEGER DEFAULT 0,
    completed_appointments INTEGER DEFAULT 0,
    cancelled_appointments INTEGER DEFAULT 0,
    total_reminders INTEGER DEFAULT 0,
    completed_reminders INTEGER DEFAULT 0,
    messages_sent INTEGER DEFAULT 0,
    new_policies INTEGER DEFAULT 0,
    renewed_policies INTEGER DEFAULT 0,
    expired_policies INTEGER DEFAULT 0,
    generated_date TIMESTAMPTZ DEFAULT NOW(),
    CONSTRAINT fk_monthly_reports_agent FOREIGN KEY (agent_id) REFERENCES agent(agent_id) ON DELETE CASCADE,
    CONSTRAINT uq_monthly_reports_agent_month UNIQUE(agent_id, report_month)
);

-- Dashboard Views Cache Table (For caching complex dashboard queries)
CREATE TABLE dashboard_views_cache (
    cache_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    agent_id UUID NOT NULL,
    view_name VARCHAR(100) NOT NULL, -- 'today_appointments', 'today_birthdays', etc.
    cache_date DATE NOT NULL,
    cache_data TEXT, -- JSON data
    expires_at TIMESTAMPTZ,
    created_date TIMESTAMPTZ DEFAULT NOW(),
    CONSTRAINT fk_dashboard_views_cache_agent FOREIGN KEY (agent_id) REFERENCES agent(agent_id) ON DELETE CASCADE,
    CONSTRAINT uq_dashboard_views_cache_agent_view_date UNIQUE(agent_id, view_name, cache_date)
);

-- ============================================
-- Helper Functions
-- ============================================

-- Function to calculate age from date of birth
CREATE OR REPLACE FUNCTION fn_calculate_age(birth_date DATE)
RETURNS INTEGER AS $$
BEGIN
    RETURN DATE_PART('year', AGE(CURRENT_DATE, birth_date))::INTEGER;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- Function to calculate days until expiry
CREATE OR REPLACE FUNCTION fn_days_until_expiry(expiry_date DATE)
RETURNS INTEGER AS $$
BEGIN
    RETURN (expiry_date - CURRENT_DATE)::INTEGER;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- ============================================
-- Triggers and Functions
-- ============================================

-- Function to update modified_date
CREATE OR REPLACE FUNCTION update_modified_date()
RETURNS TRIGGER AS $$
BEGIN
    NEW.modified_date = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Triggers for updating modified_date
CREATE TRIGGER tr_agent_modified_date
    BEFORE UPDATE ON agent
    FOR EACH ROW
    EXECUTE FUNCTION update_modified_date();

CREATE TRIGGER tr_clients_modified_date
    BEFORE UPDATE ON clients
    FOR EACH ROW
    EXECUTE FUNCTION update_modified_date();

CREATE TRIGGER tr_appointments_modified_date
    BEFORE UPDATE ON appointments
    FOR EACH ROW
    EXECUTE FUNCTION update_modified_date();

CREATE TRIGGER tr_reminder_settings_modified_date
    BEFORE UPDATE ON reminder_settings
    FOR EACH ROW
    EXECUTE FUNCTION update_modified_date();

CREATE TRIGGER tr_reminders_modified_date
    BEFORE UPDATE ON reminders
    FOR EACH ROW
    EXECUTE FUNCTION update_modified_date();

CREATE TRIGGER tr_automated_messages_modified_date
    BEFORE UPDATE ON automated_messages
    FOR EACH ROW
    EXECUTE FUNCTION update_modified_date();

CREATE TRIGGER tr_daily_notes_modified_date
    BEFORE UPDATE ON daily_notes
    FOR EACH ROW
    EXECUTE FUNCTION update_modified_date();

-- Function to update insurance_type when client policies are inserted/updated
CREATE OR REPLACE FUNCTION update_client_insurance_type()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE clients
    SET insurance_type = NEW.policy_name
    WHERE client_id = NEW.client_id;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger to update insurance type
CREATE TRIGGER tr_update_insurance_type
    AFTER INSERT OR UPDATE ON client_policies
    FOR EACH ROW
    EXECUTE FUNCTION update_client_insurance_type();

-- ============================================
-- Indexes for Performance
-- ============================================

-- Agent indexes
CREATE INDEX idx_agent_email ON agent(email);
CREATE INDEX idx_agent_is_active ON agent(is_active);

-- Client indexes
CREATE INDEX idx_clients_agent_id ON clients(agent_id);
CREATE INDEX idx_clients_is_active ON clients(is_active);
CREATE INDEX idx_clients_is_client ON clients(is_client);
CREATE INDEX idx_clients_national_id ON clients(national_id);
CREATE INDEX idx_clients_phone_number ON clients(phone_number);
CREATE INDEX idx_clients_email ON clients(email);

-- Appointment indexes
CREATE INDEX idx_appointments_client_id ON appointments(client_id);
CREATE INDEX idx_appointments_agent_id ON appointments(agent_id);
CREATE INDEX idx_appointments_date ON appointments(appointment_date);
CREATE INDEX idx_appointments_status ON appointments(status);
CREATE INDEX idx_appointments_type ON appointments(type);

-- Policy indexes
CREATE INDEX idx_client_policies_client_id ON client_policies(client_id);
CREATE INDEX idx_client_policies_status ON client_policies(status);
CREATE INDEX idx_client_policies_end_date ON client_policies(end_date);

-- Reminder indexes
CREATE INDEX idx_reminders_agent_id ON reminders(agent_id);
CREATE INDEX idx_reminders_client_id ON reminders(client_id);
CREATE INDEX idx_reminders_date ON reminders(reminder_date);
CREATE INDEX idx_reminders_status ON reminders(status);
CREATE INDEX idx_reminders_type ON reminders(reminder_type);

-- Activity log indexes
CREATE INDEX idx_activity_log_agent_id ON activity_log(agent_id);
CREATE INDEX idx_activity_log_date ON activity_log(activity_date);
CREATE INDEX idx_activity_log_type ON activity_log(activity_type);

-- Dashboard statistics indexes
CREATE INDEX idx_dashboard_statistics_agent_id ON dashboard_statistics(agent_id);
CREATE INDEX idx_dashboard_statistics_date ON dashboard_statistics(stat_date);

-- Performance metrics indexes
CREATE INDEX idx_performance_metrics_agent_id ON performance_metrics(agent_id);
CREATE INDEX idx_performance_metrics_date ON performance_metrics(metric_date);

-- ============================================
-- Views for Common Queries
-- ============================================

-- View for client summary with policy count
CREATE VIEW client_summary AS
SELECT 
    c.client_id,
    c.agent_id,
    c.first_name,
    c.surname,
    c.last_name,
    c.phone_number,
    c.email,
    c.is_client,
    c.insurance_type,
    c.created_date,
    fn_calculate_age(c.date_of_birth) as age,
    COUNT(cp.policy_id) as policy_count,
    COUNT(CASE WHEN cp.status = 'Active' THEN 1 END) as active_policies,
    MAX(cp.end_date) as latest_policy_expiry
FROM clients c
LEFT JOIN client_policies cp ON c.client_id = cp.client_id AND cp.is_active = TRUE
WHERE c.is_active = TRUE
GROUP BY c.client_id, c.agent_id, c.first_name, c.surname, c.last_name, 
         c.phone_number, c.email, c.is_client, c.insurance_type, c.created_date, c.date_of_birth;

-- View for today's appointments
CREATE VIEW todays_appointments AS
SELECT 
    a.appointment_id,
    a.agent_id,
    a.client_name,
    a.title,
    a.start_time,
    a.end_time,
    a.type,
    a.status,
    a.priority,
    a.location
FROM appointments a
WHERE a.appointment_date = CURRENT_DATE
    AND a.is_active = TRUE
ORDER BY a.start_time;

-- View for expiring policies (next 30 days)
CREATE VIEW expiring_policies AS
SELECT 
    cp.policy_id,
    cp.client_id,
    c.agent_id,
    c.first_name,
    c.surname,
    c.phone_number,
    cp.policy_name,
    cp.end_date,
    fn_days_until_expiry(cp.end_date) as days_until_expiry
FROM client_policies cp
INNER JOIN clients c ON cp.client_id = c.client_id
WHERE cp.end_date BETWEEN CURRENT_DATE AND (CURRENT_DATE + INTERVAL '30 days')
    AND cp.status = 'Active'
    AND cp.is_active = TRUE
    AND c.is_active = TRUE
ORDER BY cp.end_date;