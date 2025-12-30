-- ===========================================================
-- 986_sps_utilitysearch.sql
-- Search & Utility Stored Procedures
-- ===========================================================

-- ===========================================================
-- Drop existing functions first to avoid return type conflicts
-- ===========================================================

-- Drop Global Search Functions
DROP FUNCTION IF EXISTS sp_global_search(UUID, VARCHAR);
DROP FUNCTION IF EXISTS sp_search_clients(UUID, VARCHAR);
DROP FUNCTION IF EXISTS sp_search_appointments(UUID, VARCHAR);
DROP FUNCTION IF EXISTS sp_search_policies(UUID, VARCHAR);
DROP FUNCTION IF EXISTS sp_search_reminders(UUID, VARCHAR);
DROP FUNCTION IF EXISTS sp_get_search_suggestions(UUID, VARCHAR, INTEGER);
DROP FUNCTION IF EXISTS sp_save_search_history(UUID, VARCHAR);
DROP FUNCTION IF EXISTS sp_get_search_history(UUID, INTEGER);

-- Drop Validation Service Functions
DROP FUNCTION IF EXISTS sp_validate_email(VARCHAR);
DROP FUNCTION IF EXISTS sp_validate_national_id(VARCHAR);
DROP FUNCTION IF EXISTS sp_validate_date(DATE, DATE, DATE);
DROP FUNCTION IF EXISTS sp_validate_time_range(TIME, TIME);
DROP FUNCTION IF EXISTS sp_check_data_integrity(UUID);
DROP FUNCTION IF EXISTS sp_format_phone_number(VARCHAR, VARCHAR);

-- Drop Utility Service Functions
-- ⚠️ Do not drop fn_calculate_age or fn_days_until_expiry (already created in 001_create_tables.sql)

DROP FUNCTION IF EXISTS fn_format_client_name(VARCHAR, VARCHAR, VARCHAR);
DROP FUNCTION IF EXISTS fn_format_currency(DECIMAL);
DROP FUNCTION IF EXISTS fn_generate_id();
DROP FUNCTION IF EXISTS sp_get_greeting();
DROP FUNCTION IF EXISTS fn_get_status_color(VARCHAR);
DROP FUNCTION IF EXISTS fn_get_priority_color(VARCHAR);
DROP FUNCTION IF EXISTS fn_get_appointment_type_icon(VARCHAR);
DROP FUNCTION IF EXISTS sp_parse_template(TEXT, VARCHAR, VARCHAR, VARCHAR, DATE, VARCHAR);
DROP FUNCTION IF EXISTS sp_generate_random_password(INTEGER);

-- Drop Notification Service Functions
DROP FUNCTION IF EXISTS sp_send_email_notification(UUID, VARCHAR, VARCHAR, TEXT);
DROP FUNCTION IF EXISTS sp_send_sms_notification(UUID, VARCHAR, TEXT);
DROP FUNCTION IF EXISTS sp_send_whatsapp_notification(UUID, VARCHAR, TEXT);
DROP FUNCTION IF EXISTS sp_send_push_notification(UUID, VARCHAR, TEXT);
DROP FUNCTION IF EXISTS sp_schedule_notification(UUID, TIMESTAMPTZ, VARCHAR, VARCHAR, VARCHAR, TEXT);
DROP FUNCTION IF EXISTS sp_cancel_scheduled_notification(UUID, UUID);
DROP FUNCTION IF EXISTS sp_process_scheduled_notifications();
DROP FUNCTION IF EXISTS sp_get_notification_history(UUID, DATE, DATE, VARCHAR, VARCHAR, INTEGER, INTEGER);
DROP FUNCTION IF EXISTS sp_update_notification_status(UUID, VARCHAR, VARCHAR);

-- ===========================================================
-- Ensure search_history table exists
-- ===========================================================
CREATE TABLE IF NOT EXISTS search_history (
    search_history_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    agent_id UUID NOT NULL,
    search_term VARCHAR(500) NOT NULL,
    search_count INTEGER DEFAULT 1,
    last_searched TIMESTAMPTZ DEFAULT NOW(),
    created_date TIMESTAMPTZ DEFAULT NOW(),
    FOREIGN KEY (agent_id) REFERENCES agent(agent_id) ON DELETE CASCADE,
    UNIQUE(agent_id, search_term)
);

-- ===========================================================
-- Global Search Functions
-- ===========================================================

-- Global Search (clients, appointments, policies, reminders)
CREATE OR REPLACE FUNCTION sp_global_search(
    p_agent_id UUID,
    p_search_term VARCHAR(500)
)
RETURNS TABLE(
    entity_type VARCHAR(50),
    entity_id UUID,
    title VARCHAR(500),
    subtitle VARCHAR(500),
    detail1 VARCHAR(500),
    detail2 VARCHAR(500),
    status VARCHAR(100)
) AS $$
BEGIN
    RETURN QUERY
    -- Search Clients
    SELECT 
        'Client'::VARCHAR(50),
        c.client_id,
        (c.first_name || ' ' || c.surname)::VARCHAR(500),
        c.email::VARCHAR(500),
        c.phone_number::VARCHAR(500),
        c.address::VARCHAR(500),
        CASE WHEN c.is_client = TRUE THEN 'Client' ELSE 'Prospect' END
    FROM clients c
    WHERE c.agent_id = p_agent_id 
      AND c.is_active = TRUE
      AND (
          c.first_name ILIKE '%' || p_search_term || '%' OR
          c.surname ILIKE '%' || p_search_term || '%' OR
          c.last_name ILIKE '%' || p_search_term || '%' OR
          c.email ILIKE '%' || p_search_term || '%' OR
          c.phone_number ILIKE '%' || p_search_term || '%' OR
          c.national_id ILIKE '%' || p_search_term || '%'
      )

    UNION ALL
    -- Search Appointments
    SELECT 
        'Appointment',
        a.appointment_id,
        a.title,
        a.client_name,
        a.appointment_date::TEXT,
        a.location,
        a.status
    FROM appointments a
    INNER JOIN clients c ON a.client_id = c.client_id
    WHERE c.agent_id = p_agent_id 
      AND a.is_active = TRUE
      AND (
          a.title ILIKE '%' || p_search_term || '%' OR
          a.client_name ILIKE '%' || p_search_term || '%' OR
          a.description ILIKE '%' || p_search_term || '%' OR
          a.location ILIKE '%' || p_search_term || '%'
      )

    UNION ALL
    -- Search Policies
    SELECT 
        'Policy',
        pc.policy_catalog_id,
        pc.policy_name,
        pc.policy_type,
        pc.company_name,
        ''::VARCHAR(500),
        CASE WHEN pc.is_active = TRUE THEN 'Active' ELSE 'Inactive' END
    FROM policy_catalog pc
    WHERE pc.agent_id = p_agent_id
      AND (
          pc.policy_name ILIKE '%' || p_search_term || '%' OR
          pc.policy_type ILIKE '%' || p_search_term || '%' OR
          pc.company_name ILIKE '%' || p_search_term || '%' OR
          pc.notes ILIKE '%' || p_search_term || '%'
      )

    UNION ALL
    -- Search Reminders
    SELECT 
        'Reminder',
        r.reminder_id,
        r.title,
        r.client_name,
        r.reminder_date::TEXT,
        r.reminder_type,
        r.status
    FROM reminders r
    WHERE r.agent_id = p_agent_id
      AND (
          r.title ILIKE '%' || p_search_term || '%' OR
          r.client_name ILIKE '%' || p_search_term || '%' OR
          r.description ILIKE '%' || p_search_term || '%' OR
          r.reminder_type ILIKE '%' || p_search_term || '%'
      )
    ORDER BY entity_type, title;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION sp_search_clients(
    p_agent_id UUID,
    p_search_term VARCHAR(500)
) RETURNS TABLE(
    client_id UUID,
    first_name VARCHAR(50),
    surname VARCHAR(50),
    last_name VARCHAR(50),
    phone_number VARCHAR(20),
    email VARCHAR(100),
    address VARCHAR(500),  -- Match the actual table column type
    national_id VARCHAR(50),
    date_of_birth DATE,
    is_client BOOLEAN,
    insurance_type VARCHAR(100),
    notes TEXT,
    created_date TIMESTAMPTZ,
    modified_date TIMESTAMPTZ,
    client_type TEXT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        c.client_id,
        c.first_name,
        c.surname,
        c.last_name,
        c.phone_number,
        c.email,
        c.address::VARCHAR(500),  -- Explicit cast to match return type
        c.national_id,
        c.date_of_birth,
        c.is_client,
        c.insurance_type,
        c.notes,
        c.created_date,
        c.modified_date,
        CASE WHEN c.is_client = TRUE THEN 'Client'::TEXT ELSE 'Prospect'::TEXT END
    FROM clients c
    WHERE c.agent_id = p_agent_id
       AND c.is_active = TRUE
       AND (
           c.first_name ILIKE '%' || p_search_term || '%' OR
           c.surname ILIKE '%' || p_search_term || '%' OR
           c.last_name ILIKE '%' || p_search_term || '%' OR
           c.email ILIKE '%' || p_search_term || '%' OR
           c.phone_number ILIKE '%' || p_search_term || '%' OR
           c.national_id ILIKE '%' || p_search_term || '%' OR
           c.address ILIKE '%' || p_search_term || '%' OR
           c.insurance_type ILIKE '%' || p_search_term || '%'
       )
    ORDER BY c.is_client DESC, c.first_name, c.surname;
END;
$$ LANGUAGE plpgsql;
-- Search Appointments
CREATE OR REPLACE FUNCTION sp_search_appointments(
    p_agent_id UUID,
    p_search_term VARCHAR(500)
)
RETURNS TABLE(
    appointment_id UUID,
    client_id UUID,
    client_name VARCHAR(100),
    client_phone VARCHAR(20),
    title VARCHAR(200),
    description TEXT,
    appointment_date DATE,
    start_time TIME,
    end_time TIME,
    location VARCHAR(200),
    type VARCHAR(50),
    status VARCHAR(50),
    priority VARCHAR(20),
    notes TEXT,
    created_date TIMESTAMPTZ
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        a.appointment_id,
        a.client_id,
        a.client_name,
        a.client_phone,
        a.title,
        a.description,
        a.appointment_date,
        a.start_time,
        a.end_time,
        a.location,
        a.type,
        a.status,
        a.priority,
        a.notes,
        a.created_date
    FROM appointments a
    INNER JOIN clients c ON a.client_id = c.client_id
    WHERE c.agent_id = p_agent_id 
        AND a.is_active = TRUE
        AND (
            a.title ILIKE '%' || p_search_term || '%' OR
            a.client_name ILIKE '%' || p_search_term || '%' OR
            a.description ILIKE '%' || p_search_term || '%' OR
            a.location ILIKE '%' || p_search_term || '%' OR
            a.type ILIKE '%' || p_search_term || '%'
        )
    ORDER BY a.appointment_date DESC, a.start_time;
END;
$$ LANGUAGE plpgsql;

-- Search Policies
CREATE OR REPLACE FUNCTION sp_search_policies(
    p_agent_id UUID,
    p_search_term VARCHAR(500)
)
RETURNS TABLE(
    policy_catalog_id UUID,
    policy_name VARCHAR(200),
    policy_type VARCHAR(100),
    company_id UUID,
    company_name VARCHAR(100),
    notes TEXT,
    is_active BOOLEAN,
    created_date TIMESTAMPTZ,
    modified_date TIMESTAMPTZ
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        pc.policy_catalog_id,
        pc.policy_name,
        pc.policy_type,
        pc.company_id,
        pc.company_name,
        pc.notes,
        pc.is_active,
        pc.created_date,
        pc.modified_date
    FROM policy_catalog pc
    WHERE pc.agent_id = p_agent_id
        AND (
            pc.policy_name ILIKE '%' || p_search_term || '%' OR
            pc.policy_type ILIKE '%' || p_search_term || '%' OR
            pc.company_name ILIKE '%' || p_search_term || '%' OR
            pc.notes ILIKE '%' || p_search_term || '%'
        )
    ORDER BY pc.policy_name;
END;
$$ LANGUAGE plpgsql;

-- Search Reminders
CREATE OR REPLACE FUNCTION sp_search_reminders(
    p_agent_id UUID,
    p_search_term VARCHAR(500)
)
RETURNS TABLE(
    reminder_id UUID,
    client_id UUID,
    appointment_id UUID,
    reminder_type VARCHAR(50),
    title VARCHAR(200),
    description TEXT,
    reminder_date DATE,
    reminder_time TIME,
    client_name VARCHAR(100),
    priority VARCHAR(20),
    status VARCHAR(50),
    notes TEXT,
    created_date TIMESTAMPTZ
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        r.reminder_id,
        r.client_id,
        r.appointment_id,
        r.reminder_type,
        r.title,
        r.description,
        r.reminder_date,
        r.reminder_time,
        r.client_name,
        r.priority,
        r.status,
        r.notes,
        r.created_date
    FROM reminders r
    WHERE r.agent_id = p_agent_id
        AND (
            r.title ILIKE '%' || p_search_term || '%' OR
            r.client_name ILIKE '%' || p_search_term || '%' OR
            r.description ILIKE '%' || p_search_term || '%' OR
            r.reminder_type ILIKE '%' || p_search_term || '%' OR
            r.notes ILIKE '%' || p_search_term || '%'
        )
    ORDER BY r.reminder_date DESC;
END;
$$ LANGUAGE plpgsql;

-- Get Search Suggestions
CREATE OR REPLACE FUNCTION sp_get_search_suggestions(
    p_agent_id UUID,
    p_search_term VARCHAR(500),
    p_max_results INTEGER DEFAULT 10
)
RETURNS TABLE(suggestion VARCHAR(500)) AS $$
BEGIN
    RETURN QUERY
    SELECT DISTINCT suggestions.suggestion
    FROM (
        SELECT c.first_name::VARCHAR(500) AS suggestion FROM clients c WHERE c.agent_id = p_agent_id AND c.first_name ILIKE p_search_term || '%'
        UNION
        SELECT c.surname::VARCHAR(500) FROM clients c WHERE c.agent_id = p_agent_id AND c.surname ILIKE p_search_term || '%'
        UNION
        SELECT c.email::VARCHAR(500) FROM clients c WHERE c.agent_id = p_agent_id AND c.email ILIKE p_search_term || '%'
        UNION
        SELECT c.insurance_type::VARCHAR(500) FROM clients c WHERE c.agent_id = p_agent_id AND c.insurance_type ILIKE p_search_term || '%'
        UNION
        SELECT pc.policy_name::VARCHAR(500) FROM policy_catalog pc WHERE pc.agent_id = p_agent_id AND pc.policy_name ILIKE p_search_term || '%'
        UNION
        SELECT pc.policy_type::VARCHAR(500) FROM policy_catalog pc WHERE pc.agent_id = p_agent_id AND pc.policy_type ILIKE p_search_term || '%'
        UNION
        SELECT pc.company_name::VARCHAR(500) FROM policy_catalog pc WHERE pc.agent_id = p_agent_id AND pc.company_name ILIKE p_search_term || '%'
    ) AS suggestions
    ORDER BY suggestion
    LIMIT p_max_results;
END;
$$ LANGUAGE plpgsql;

-- Save Search History
CREATE OR REPLACE FUNCTION sp_save_search_history(
    p_agent_id UUID,
    p_search_term VARCHAR(500)
)
RETURNS VOID AS $$
BEGIN
    INSERT INTO search_history (agent_id, search_term)
    VALUES (p_agent_id, p_search_term)
    ON CONFLICT (agent_id, search_term)
    DO UPDATE SET 
        search_count = search_history.search_count + 1,
        last_searched = NOW();
END;
$$ LANGUAGE plpgsql;

-- Get Search History
CREATE OR REPLACE FUNCTION sp_get_search_history(
    p_agent_id UUID,
    p_max_results INTEGER DEFAULT 20
)
RETURNS TABLE(
    search_term VARCHAR(500),
    search_count INTEGER,
    last_searched TIMESTAMPTZ
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        sh.search_term,
        sh.search_count,
        sh.last_searched
    FROM search_history sh
    WHERE sh.agent_id = p_agent_id
    ORDER BY sh.last_searched DESC
    LIMIT p_max_results;
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- Validation Service Functions
-- ============================================

-- Validate Email
CREATE OR REPLACE FUNCTION sp_validate_email(p_email VARCHAR(100))
RETURNS TABLE(is_valid BOOLEAN, validation_message VARCHAR(200)) AS $$
DECLARE
    v_is_valid BOOLEAN := FALSE;
    v_validation_message VARCHAR(200) := '';
BEGIN
    IF p_email IS NULL OR p_email = '' THEN
        v_validation_message := 'Email cannot be empty';
    ELSIF POSITION('@' IN p_email) = 0 OR POSITION('.' IN p_email) = 0 THEN
        v_validation_message := 'Invalid email format';
    ELSIF LENGTH(p_email) > 100 THEN
        v_validation_message := 'Email too long (max 100 characters)';
    ELSE
        v_is_valid := TRUE;
        v_validation_message := 'Valid email';
    END IF;
    
    RETURN QUERY SELECT v_is_valid, v_validation_message;
END;
$$ LANGUAGE plpgsql;

-- Validate National ID (Kenya format)
CREATE OR REPLACE FUNCTION sp_validate_national_id(p_national_id VARCHAR(20))
RETURNS TABLE(is_valid BOOLEAN, validation_message VARCHAR(200), formatted_national_id VARCHAR(20)) AS $$
DECLARE
    v_is_valid BOOLEAN := FALSE;
    v_validation_message VARCHAR(200) := '';
    v_formatted_id VARCHAR(20);
BEGIN
    -- Remove spaces and convert to upper case
    v_formatted_id := UPPER(REPLACE(p_national_id, ' ', ''));
    
    IF p_national_id IS NULL OR p_national_id = '' THEN
        v_validation_message := 'National ID cannot be empty';
    ELSIF LENGTH(v_formatted_id) < 7 OR LENGTH(v_formatted_id) > 8 THEN
        v_validation_message := 'National ID must be 7-8 characters long';
    ELSIF v_formatted_id !~ '^[0-9]{7,8}$' THEN
        v_validation_message := 'National ID must contain only numbers';
    ELSE
        v_is_valid := TRUE;
        v_validation_message := 'Valid National ID';
    END IF;
    
    RETURN QUERY SELECT v_is_valid, v_validation_message, v_formatted_id;
END;
$$ LANGUAGE plpgsql;

-- Validate Date
CREATE OR REPLACE FUNCTION sp_validate_date(
    p_date_value DATE,
    p_min_date DATE DEFAULT '1900-01-01',
    p_max_date DATE DEFAULT '2100-12-31'
)
RETURNS TABLE(is_valid BOOLEAN, validation_message VARCHAR(200)) AS $$
DECLARE
    v_is_valid BOOLEAN := FALSE;
    v_validation_message VARCHAR(200) := '';
BEGIN
    IF p_date_value IS NULL THEN
        v_validation_message := 'Date cannot be null';
    ELSIF p_date_value < p_min_date THEN
        v_validation_message := 'Date is too early (minimum: ' || p_min_date::TEXT || ')';
    ELSIF p_date_value > p_max_date THEN
        v_validation_message := 'Date is too late (maximum: ' || p_max_date::TEXT || ')';
    ELSE
        v_is_valid := TRUE;
        v_validation_message := 'Valid date';
    END IF;
    
    RETURN QUERY SELECT v_is_valid, v_validation_message;
END;
$$ LANGUAGE plpgsql;

-- Validate Time Range
CREATE OR REPLACE FUNCTION sp_validate_time_range(
    p_start_time TIME,
    p_end_time TIME
)
RETURNS TABLE(is_valid BOOLEAN, validation_message VARCHAR(200)) AS $$
DECLARE
    v_is_valid BOOLEAN := FALSE;
    v_validation_message VARCHAR(200) := '';
    v_duration INTERVAL;
BEGIN
    IF p_start_time IS NULL OR p_end_time IS NULL THEN
        v_validation_message := 'Start time and end time cannot be null';
    ELSIF p_start_time >= p_end_time THEN
        v_validation_message := 'Start time must be before end time';
    ELSE
        v_duration := p_end_time - p_start_time;
        
        IF EXTRACT(EPOCH FROM v_duration) < 900 THEN -- 15 minutes in seconds
            v_validation_message := 'Time range must be at least 15 minutes';
        ELSIF EXTRACT(EPOCH FROM v_duration) > 43200 THEN -- 12 hours in seconds
            v_validation_message := 'Time range cannot exceed 12 hours';
        ELSE
            v_is_valid := TRUE;
            v_validation_message := 'Valid time range';
        END IF;
    END IF;
    
    RETURN QUERY SELECT v_is_valid, v_validation_message;
END;
$$ LANGUAGE plpgsql;

-- Check Data Integrity
CREATE OR REPLACE FUNCTION sp_check_data_integrity(p_agent_id UUID)
RETURNS TABLE(
    issue_type VARCHAR(50),
    issue_count BIGINT,
    description VARCHAR(100)
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        'OrphanedAppointments'::VARCHAR(50) AS issue_type,
        COUNT(*)::BIGINT AS issue_count,
        'Appointments without valid clients'::VARCHAR(100) AS description
    FROM appointments a
    LEFT JOIN clients c ON a.client_id = c.client_id
    WHERE c.client_id IS NULL
    
    UNION ALL
    
    SELECT 
        'OrphanedPolicies'::VARCHAR(50),
        COUNT(*)::BIGINT,
        'Client policies without valid clients'::VARCHAR(100)
    FROM client_policies cp
    LEFT JOIN clients c ON cp.client_id = c.client_id
    WHERE c.client_id IS NULL
    
    UNION ALL
    
    SELECT 
        'OrphanedReminders'::VARCHAR(50),
        COUNT(*)::BIGINT,
        'Reminders without valid clients'::VARCHAR(100)
    FROM reminders r
    LEFT JOIN clients c ON r.client_id = c.client_id
    WHERE r.client_id IS NOT NULL AND c.client_id IS NULL
    
    UNION ALL
    
    SELECT 
        'DuplicateEmails'::VARCHAR(50),
        (COUNT(*) - COUNT(DISTINCT email))::BIGINT,
        'Clients with duplicate email addresses'::VARCHAR(100)
    FROM clients
    WHERE agent_id = p_agent_id AND is_active = TRUE
    
    UNION ALL
    
    SELECT 
        'DuplicatePhones'::VARCHAR(50),
        (COUNT(*) - COUNT(DISTINCT phone_number))::BIGINT,
        'Clients with duplicate phone numbers'::VARCHAR(100)
    FROM clients
    WHERE agent_id = p_agent_id AND is_active = TRUE
    
    UNION ALL
    
    SELECT 
        'DuplicateNationalIds'::VARCHAR(50),
        (COUNT(*) - COUNT(DISTINCT national_id))::BIGINT,
        'Clients with duplicate national IDs'::VARCHAR(100)
    FROM clients
    WHERE agent_id = p_agent_id AND is_active = TRUE
    
    UNION ALL
    
    SELECT 
        'FutureAppointments'::VARCHAR(50),
        COUNT(*)::BIGINT,
        'Appointments scheduled more than 1 year in future'::VARCHAR(100)
    FROM appointments a
    INNER JOIN clients c ON a.client_id = c.client_id
    WHERE c.agent_id = p_agent_id 
        AND a.appointment_date > (NOW() + INTERVAL '1 year')
    
    UNION ALL
    
    SELECT 
        'ExpiredActiveReminders'::VARCHAR(50),
        COUNT(*)::BIGINT,
        'Active reminders with past dates'::VARCHAR(100)
    FROM reminders r
    WHERE r.agent_id = p_agent_id 
        AND r.status = 'Active'
        AND r.reminder_date < CURRENT_DATE;
END;
$$ LANGUAGE plpgsql;

-- Format Phone Number
CREATE OR REPLACE FUNCTION sp_format_phone_number(
    p_phone_number VARCHAR(20),
    p_country_code VARCHAR(5) DEFAULT '+254'
)
RETURNS TABLE(formatted_phone_number VARCHAR(20)) AS $$
DECLARE
    v_formatted_number VARCHAR(20) := '';
    v_clean_number VARCHAR(20);
BEGIN
    -- Remove spaces, dashes, and other formatting
    v_clean_number := REPLACE(REPLACE(REPLACE(p_phone_number, ' ', ''), '-', ''), '(', '');
    v_clean_number := REPLACE(REPLACE(REPLACE(v_clean_number, ')', ''), '+', ''), '.', '');
    
    -- Format for Kenya
    IF LENGTH(v_clean_number) = 10 AND LEFT(v_clean_number, 1) = '0' THEN
        v_formatted_number := p_country_code || RIGHT(v_clean_number, 9);
    ELSIF LENGTH(v_clean_number) = 9 THEN
        v_formatted_number := p_country_code || v_clean_number;
    ELSIF LENGTH(v_clean_number) = 13 AND LEFT(v_clean_number, 3) = '254' THEN
        v_formatted_number := '+' || v_clean_number;
    ELSE
        v_formatted_number := p_phone_number;
    END IF;
    
    RETURN QUERY SELECT v_formatted_number;
END;
$$ LANGUAGE plpgsql;


-- ===========================================================
-- Utility Service Functions (Safe rewrite)
-- ===========================================================

-- Format Client Name Function
CREATE OR REPLACE FUNCTION fn_format_client_name(
    p_first_name VARCHAR(50),
    p_surname VARCHAR(50),
    p_last_name VARCHAR(50) DEFAULT NULL
)
RETURNS VARCHAR(152) AS $$
BEGIN
    RETURN TRIM(p_first_name) || ' ' || 
           TRIM(p_surname) || 
           CASE 
               WHEN p_last_name IS NOT NULL AND p_last_name <> '' 
               THEN ' ' || TRIM(p_last_name)
               ELSE ''
           END;
END;
$$ LANGUAGE plpgsql;

-- Format Currency
CREATE OR REPLACE FUNCTION fn_format_currency(p_amount DECIMAL(10,2))
RETURNS VARCHAR(20) AS $$
BEGIN
    RETURN 'KSH ' || TO_CHAR(p_amount, 'FM999,999,990.00');
END;
$$ LANGUAGE plpgsql;

-- Generate ID
CREATE OR REPLACE FUNCTION fn_generate_id()
RETURNS UUID AS $$
BEGIN
    RETURN gen_random_uuid();
END;
$$ LANGUAGE plpgsql;

-- Get Greeting
CREATE OR REPLACE FUNCTION sp_get_greeting()
RETURNS TABLE(greeting VARCHAR(20)) AS $$
DECLARE
    v_current_hour INTEGER;
BEGIN
    v_current_hour := EXTRACT(HOUR FROM NOW());
    
    RETURN QUERY 
    SELECT CASE 
        WHEN v_current_hour < 12 THEN 'Good Morning'
        WHEN v_current_hour < 17 THEN 'Good Afternoon'
        ELSE 'Good Evening'
    END;
END;
$$ LANGUAGE plpgsql;

-- Get Status Color
CREATE OR REPLACE FUNCTION fn_get_status_color(p_status VARCHAR(20))
RETURNS VARCHAR(20) AS $$
BEGIN
    RETURN CASE p_status
        WHEN 'Active'     THEN 'success'
        WHEN 'Completed'  THEN 'success'
        WHEN 'Confirmed'  THEN 'info'
        WHEN 'Scheduled'  THEN 'primary'
        WHEN 'In Progress' THEN 'warning'
        WHEN 'Cancelled'  THEN 'danger'
        WHEN 'Expired'    THEN 'danger'
        WHEN 'Inactive'   THEN 'secondary'
        WHEN 'Lapsed'     THEN 'danger'
        ELSE 'secondary'
    END;
END;
$$ LANGUAGE plpgsql;

-- Get Priority Color
CREATE OR REPLACE FUNCTION fn_get_priority_color(p_priority VARCHAR(10))
RETURNS VARCHAR(20) AS $$
BEGIN
    RETURN CASE p_priority
        WHEN 'High'   THEN 'danger'
        WHEN 'Medium' THEN 'warning'
        WHEN 'Low'    THEN 'info'
        ELSE 'secondary'
    END;
END;
$$ LANGUAGE plpgsql;

-- Get Appointment Type Icon
CREATE OR REPLACE FUNCTION fn_get_appointment_type_icon(p_type VARCHAR(50))
RETURNS VARCHAR(20) AS $$
BEGIN
    RETURN CASE p_type
        WHEN 'Call'             THEN 'phone'
        WHEN 'Meeting'          THEN 'users'
        WHEN 'Site Visit'       THEN 'map-pin'
        WHEN 'Policy Review'    THEN 'file-text'
        WHEN 'Claim Processing' THEN 'clipboard'
        ELSE 'calendar'
    END;
END;
$$ LANGUAGE plpgsql;

-- Parse Template - FIXED parameter order
CREATE OR REPLACE FUNCTION sp_parse_template(
    p_template TEXT,
    p_client_name VARCHAR(150) DEFAULT NULL,
    p_agent_name VARCHAR(100) DEFAULT NULL,
    p_policy_type VARCHAR(50) DEFAULT NULL,
    p_expiry_date DATE DEFAULT NULL,
    p_company_name VARCHAR(100) DEFAULT NULL
)
RETURNS TABLE(parsed_template TEXT) AS $$
DECLARE
    v_parsed_template TEXT := p_template;
BEGIN
    v_parsed_template := REPLACE(v_parsed_template, '{name}',          COALESCE(p_client_name, '{name}'));
    v_parsed_template := REPLACE(v_parsed_template, '{client_name}',   COALESCE(p_client_name, '{client_name}'));
    v_parsed_template := REPLACE(v_parsed_template, '{agent_name}',    COALESCE(p_agent_name, '{agent_name}'));
    v_parsed_template := REPLACE(v_parsed_template, '{policy_type}',   COALESCE(p_policy_type, '{policy_type}'));
    v_parsed_template := REPLACE(v_parsed_template, '{expiry_date}',   COALESCE(p_expiry_date::TEXT, '{expiry_date}'));
    v_parsed_template := REPLACE(v_parsed_template, '{company_name}',  COALESCE(p_company_name, '{company_name}'));
    v_parsed_template := REPLACE(v_parsed_template, '{current_date}',  CURRENT_DATE::TEXT);
    v_parsed_template := REPLACE(v_parsed_template, '{current_year}',  EXTRACT(YEAR FROM NOW())::TEXT);

    RETURN QUERY SELECT v_parsed_template;
END;
$$ LANGUAGE plpgsql;

-- Generate Random Password
CREATE OR REPLACE FUNCTION sp_generate_random_password(p_length INTEGER DEFAULT 12)
RETURNS TABLE(random_password VARCHAR(50)) AS $$
DECLARE
    v_password VARCHAR(50) := '';
    v_characters CONSTANT VARCHAR := 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789!@#$%^&*';
    v_char_length INTEGER := LENGTH(v_characters);
BEGIN
    FOR i IN 1..p_length LOOP
        v_password := v_password || SUBSTRING(v_characters FROM (FLOOR(RANDOM() * v_char_length) + 1) FOR 1);
    END LOOP;
    RETURN QUERY SELECT v_password;
END;
$$ LANGUAGE plpgsql;

-- ===========================================================
-- Notification Service Functions
-- ===========================================================

-- Create Notifications Table (if not exists)
CREATE TABLE IF NOT EXISTS notifications (
    notification_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    agent_id UUID NOT NULL,
    notification_type VARCHAR(20) NOT NULL CHECK (notification_type IN ('Email', 'SMS', 'WhatsApp', 'Push')),
    recipient VARCHAR(200) NOT NULL,
    subject VARCHAR(200),
    body TEXT NOT NULL,
    status VARCHAR(20) DEFAULT 'Pending' CHECK (status IN ('Pending', 'Sent', 'Failed', 'Cancelled')),
    scheduled_time TIMESTAMPTZ,
    sent_time TIMESTAMPTZ,
    error_message VARCHAR(500),
    retry_count INTEGER DEFAULT 0,
    created_date TIMESTAMPTZ DEFAULT NOW(),
    FOREIGN KEY (agent_id) REFERENCES agent(agent_id) ON DELETE CASCADE
);

-- Send Email Notification
CREATE OR REPLACE FUNCTION sp_send_email_notification(
    p_agent_id UUID,
    p_to_email VARCHAR(200),
    p_subject VARCHAR(200),
    p_body TEXT
)
RETURNS TABLE(notification_id UUID, success BOOLEAN) AS $$
DECLARE
    v_notification_id UUID := gen_random_uuid();
BEGIN
    INSERT INTO notifications (
        notification_id, agent_id, notification_type, recipient, subject, body, status
    ) VALUES (
        v_notification_id, p_agent_id, 'Email', p_to_email, p_subject, p_body, 'Pending'
    );

    UPDATE notifications 
    SET status = 'Sent', sent_time = NOW()
    WHERE notification_id = v_notification_id;

    RETURN QUERY SELECT v_notification_id, TRUE;
END;
$$ LANGUAGE plpgsql;

-- Send SMS Notification
CREATE OR REPLACE FUNCTION sp_send_sms_notification(
    p_agent_id UUID,
    p_phone_number VARCHAR(20),
    p_message TEXT
)
RETURNS TABLE(notification_id UUID, success BOOLEAN) AS $$
DECLARE
    v_notification_id UUID := gen_random_uuid();
    v_success BOOLEAN := (RANDOM() > 0.1); -- Simulated 90% success
BEGIN
    INSERT INTO notifications (
        notification_id, agent_id, notification_type, recipient, body, status
    ) VALUES (
        v_notification_id, p_agent_id, 'SMS', p_phone_number, p_message, 'Pending'
    );

    IF v_success THEN
        UPDATE notifications 
        SET status = 'Sent', sent_time = NOW()
        WHERE notification_id = v_notification_id;
    ELSE
        UPDATE notifications 
        SET status = 'Failed', error_message = 'Simulated SMS delivery failure'
        WHERE notification_id = v_notification_id;
    END IF;

    RETURN QUERY SELECT v_notification_id, v_success;
END;
$$ LANGUAGE plpgsql;

-- Send WhatsApp Notification
CREATE OR REPLACE FUNCTION sp_send_whatsapp_notification(
    p_agent_id UUID,
    p_phone_number VARCHAR(20),
    p_message TEXT
)
RETURNS TABLE(notification_id UUID, success BOOLEAN) AS $$
DECLARE
    v_notification_id UUID := gen_random_uuid();
BEGIN
    INSERT INTO notifications (
        notification_id, agent_id, notification_type, recipient, body, status
    )
    VALUES (
        v_notification_id, p_agent_id, 'WhatsApp', p_phone_number, p_message, 'Pending'
    );
    
    UPDATE notifications 
    SET status = 'Sent', sent_time = NOW()
    WHERE notification_id = v_notification_id;
    
    RETURN QUERY SELECT v_notification_id, TRUE;
END;
$$ LANGUAGE plpgsql;

-- Send Push Notification
CREATE OR REPLACE FUNCTION sp_send_push_notification(
    p_agent_id UUID,
    p_title VARCHAR(200),
    p_body TEXT
)
RETURNS TABLE(notification_id UUID, success BOOLEAN) AS $$
DECLARE
    v_notification_id UUID := gen_random_uuid();
BEGIN
    INSERT INTO notifications (
        notification_id, agent_id, notification_type, recipient, subject, body, status
    )
    VALUES (
        v_notification_id, p_agent_id, 'Push', p_agent_id::TEXT, p_title, p_body, 'Pending'
    );
    
    UPDATE notifications 
    SET status = 'Sent', sent_time = NOW()
    WHERE notification_id = v_notification_id;
    
    RETURN QUERY SELECT v_notification_id, TRUE;
END;
$$ LANGUAGE plpgsql;

-- Schedule Notification - FIXED parameter order
CREATE OR REPLACE FUNCTION sp_schedule_notification(
    p_agent_id UUID,
    p_scheduled_time TIMESTAMPTZ,
    p_notification_type VARCHAR(20),
    p_recipient VARCHAR(200),
    p_body TEXT,
    p_subject VARCHAR(200) DEFAULT NULL
)
RETURNS TABLE(notification_id UUID) AS $$
DECLARE
    v_notification_id UUID := gen_random_uuid();
BEGIN
    INSERT INTO notifications (
        notification_id, agent_id, notification_type, recipient, subject, body, scheduled_time, status
    )
    VALUES (
        v_notification_id, p_agent_id, p_notification_type, p_recipient, p_subject, p_body, p_scheduled_time, 'Pending'
    );
    
    RETURN QUERY SELECT v_notification_id;
END;
$$ LANGUAGE plpgsql;

-- Cancel Scheduled Notification
CREATE OR REPLACE FUNCTION sp_cancel_scheduled_notification(
    p_notification_id UUID,
    p_agent_id UUID
)
RETURNS TABLE(rows_affected INTEGER) AS $$
DECLARE
    v_rows_affected INTEGER;
BEGIN
    UPDATE notifications 
    SET status = 'Cancelled'
    WHERE notification_id = p_notification_id 
      AND agent_id = p_agent_id 
      AND status = 'Pending';
    
    GET DIAGNOSTICS v_rows_affected = ROW_COUNT;
    
    RETURN QUERY SELECT v_rows_affected;
END;
$$ LANGUAGE plpgsql;

-- Process Scheduled Notifications
CREATE OR REPLACE FUNCTION sp_process_scheduled_notifications()
RETURNS TABLE(
    notification_id UUID,
    agent_id UUID,
    notification_type VARCHAR(20),
    recipient VARCHAR(200),
    subject VARCHAR(200),
    body TEXT,
    scheduled_time TIMESTAMPTZ
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        n.notification_id,
        n.agent_id,
        n.notification_type,
        n.recipient,
        n.subject,
        n.body,
        n.scheduled_time
    FROM notifications n
    WHERE n.status = 'Pending'
      AND n.scheduled_time IS NOT NULL
      AND n.scheduled_time <= NOW()
    ORDER BY n.scheduled_time ASC;
END;
$$ LANGUAGE plpgsql;

-- Get Notification History - FIXED parameter order
CREATE OR REPLACE FUNCTION sp_get_notification_history(
    p_agent_id UUID,
    p_page_size INTEGER DEFAULT 50,
    p_page_number INTEGER DEFAULT 1,
    p_start_date DATE DEFAULT NULL,
    p_end_date DATE DEFAULT NULL,
    p_notification_type VARCHAR(20) DEFAULT NULL,
    p_status VARCHAR(20) DEFAULT NULL
)
RETURNS TABLE(
    notification_id UUID,
    notification_type VARCHAR(20),
    recipient VARCHAR(200),
    subject VARCHAR(200),
    body TEXT,
    status VARCHAR(20),
    scheduled_time TIMESTAMPTZ,
    sent_time TIMESTAMPTZ,
    error_message VARCHAR(500),
    retry_count INTEGER,
    created_date TIMESTAMPTZ,
    total_records BIGINT
) AS $$
DECLARE
    v_start_date DATE;
    v_end_date DATE;
    v_offset INTEGER;
    v_total_records BIGINT;
BEGIN
    v_start_date := COALESCE(p_start_date, CURRENT_DATE - INTERVAL '30 days');
    v_end_date := COALESCE(p_end_date, CURRENT_DATE);
    v_offset := (p_page_number - 1) * p_page_size;
    
    -- Get total count
    SELECT COUNT(*)
    INTO v_total_records
    FROM notifications n
    WHERE 
        n.agent_id = p_agent_id
        AND n.created_date::DATE BETWEEN v_start_date AND v_end_date
        AND (p_notification_type IS NULL OR n.notification_type = p_notification_type)
        AND (p_status IS NULL OR n.status = p_status);
    
    RETURN QUERY
    SELECT 
        n.notification_id,
        n.notification_type,
        n.recipient,
        n.subject,
        n.body,
        n.status,
        n.scheduled_time,
        n.sent_time,
        n.error_message,
        n.retry_count,
        n.created_date,
        v_total_records
    FROM notifications n
    WHERE 
        n.agent_id = p_agent_id
        AND n.created_date::DATE BETWEEN v_start_date AND v_end_date
        AND (p_notification_type IS NULL OR n.notification_type = p_notification_type)
        AND (p_status IS NULL OR n.status = p_status)
    ORDER BY n.created_date DESC
    LIMIT p_page_size OFFSET v_offset;
END;
$$ LANGUAGE plpgsql;

-- Update Notification Status - FIXED parameter order
CREATE OR REPLACE FUNCTION sp_update_notification_status(
    p_notification_id UUID,
    p_status VARCHAR(20),
    p_error_message VARCHAR(500) DEFAULT NULL
)
RETURNS TABLE(rows_affected INTEGER) AS $$
DECLARE
    v_rows_affected INTEGER;
BEGIN
    UPDATE notifications 
    SET 
        status = p_status,
        sent_time = CASE WHEN p_status = 'Sent' THEN NOW() ELSE sent_time END,
        error_message = p_error_message,
        retry_count = CASE WHEN p_status = 'Failed' THEN retry_count + 1 ELSE retry_count END
    WHERE notification_id = p_notification_id;
    
    GET DIAGNOSTICS v_rows_affected = ROW_COUNT;
    
    RETURN QUERY SELECT v_rows_affected;
END;
$$ LANGUAGE plpgsql;