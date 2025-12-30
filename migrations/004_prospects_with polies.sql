CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

CREATE TABLE prospects (
    prospect_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    agent_id UUID NOT NULL REFERENCES agent(agent_id) ON DELETE CASCADE,
    first_name VARCHAR(50) NOT NULL,
    surname VARCHAR(50),
    last_name VARCHAR(50),
    phone_number VARCHAR(20),
    email VARCHAR(100),
    notes TEXT,
    created_date TIMESTAMPTZ DEFAULT NOW(),
    modified_date TIMESTAMPTZ DEFAULT NOW(),
    is_active BOOLEAN DEFAULT TRUE
);


CREATE TABLE prospect_external_policies (
    ext_policy_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    prospect_id UUID NOT NULL REFERENCES prospects(prospect_id) ON DELETE CASCADE,
    company_name VARCHAR(100) NOT NULL,
    policy_number VARCHAR(100),
    policy_type VARCHAR(100),
    expiry_date DATE,
    notes TEXT,
    created_date TIMESTAMPTZ DEFAULT NOW(),
    modified_date TIMESTAMPTZ DEFAULT NOW(),
    is_active BOOLEAN DEFAULT TRUE
);

-- Get prospect statistics for dashboard
CREATE OR REPLACE FUNCTION sp_get_prospect_statistics(p_agent_id UUID)
RETURNS TABLE (
    total_prospects INTEGER,
    prospects_with_policies INTEGER,
    expiring_in_7_days INTEGER,
    expiring_in_30_days INTEGER,
    expired_policies INTEGER
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        COUNT(DISTINCT p.prospect_id)::INTEGER as total_prospects,
        COUNT(DISTINCT CASE WHEN e.ext_policy_id IS NOT NULL THEN p.prospect_id END)::INTEGER as prospects_with_policies,
        COUNT(DISTINCT CASE WHEN e.expiry_date BETWEEN CURRENT_DATE AND (CURRENT_DATE + INTERVAL '7 days') THEN p.prospect_id END)::INTEGER as expiring_in_7_days,
        COUNT(DISTINCT CASE WHEN e.expiry_date BETWEEN CURRENT_DATE AND (CURRENT_DATE + INTERVAL '30 days') THEN p.prospect_id END)::INTEGER as expiring_in_30_days,
        COUNT(DISTINCT CASE WHEN e.expiry_date < CURRENT_DATE THEN p.prospect_id END)::INTEGER as expired_policies
    FROM prospects p
    LEFT JOIN prospect_external_policies e ON p.prospect_id = e.prospect_id AND e.is_active = TRUE
    WHERE p.agent_id = p_agent_id AND p.is_active = TRUE;
END;
$$ LANGUAGE plpgsql;

-- Auto-create reminders for expiring prospect policies
CREATE OR REPLACE FUNCTION sp_auto_create_prospect_reminders(p_agent_id UUID)
RETURNS INTEGER AS $$
DECLARE
    reminder_count INTEGER := 0;
    prospect_policy RECORD;
BEGIN
    -- Loop through prospects with policies expiring in next 30 days
    FOR prospect_policy IN
        SELECT 
            p.prospect_id,
            p.agent_id,
            CONCAT(p.first_name, ' ', COALESCE(p.last_name, '')) as full_name,
            e.policy_type,
            e.company_name,
            e.expiry_date,
            fn_days_until_expiry(e.expiry_date) as days_until_expiry
        FROM prospects p
        JOIN prospect_external_policies e ON p.prospect_id = e.prospect_id
        WHERE p.agent_id = p_agent_id
          AND e.expiry_date BETWEEN CURRENT_DATE AND (CURRENT_DATE + INTERVAL '30 days')
          AND e.is_active = TRUE
          AND p.is_active = TRUE
          -- Only create if reminder doesn't already exist
          AND NOT EXISTS (
              SELECT 1 FROM reminders r 
              WHERE r.client_id = p.prospect_id 
                AND r.reminder_type = 'Policy Expiry'
                AND r.reminder_date = e.expiry_date
                AND r.status = 'Active'
          )
    LOOP
        -- Insert reminder for this prospect policy
        INSERT INTO reminders (
            client_id, -- Using client_id field for prospect_id (reusing existing structure)
            agent_id,
            reminder_type,
            title,
            description,
            reminder_date,
            client_name,
            priority,
            status,
            enable_push_notification,
            advance_notice
        ) VALUES (
            prospect_policy.prospect_id,
            prospect_policy.agent_id,
            'Policy Expiry',
            'Prospect Policy Expiry - ' || prospect_policy.policy_type,
            'Policy with ' || prospect_policy.company_name || ' expires. Contact to offer renewal/new policy.',
            prospect_policy.expiry_date,
            prospect_policy.full_name,
            CASE 
                WHEN prospect_policy.days_until_expiry <= 7 THEN 'High'
                WHEN prospect_policy.days_until_expiry <= 15 THEN 'Medium'
                ELSE 'Low'
            END,
            'Active',
            TRUE,
            CASE 
                WHEN prospect_policy.days_until_expiry <= 7 THEN '1 day'
                ELSE '3 days'
            END
        );
        
        reminder_count := reminder_count + 1;
    END LOOP;
    
    RETURN reminder_count;
END;
$$ LANGUAGE plpgsql;

-- Get prospects with expiring policies (simple list for services)
CREATE OR REPLACE FUNCTION sp_get_expiring_prospect_policies(
    p_agent_id UUID,
    p_days_ahead INTEGER DEFAULT 30
)
RETURNS TABLE (
    prospect_id UUID,
    full_name TEXT,
    phone_number VARCHAR,
    email VARCHAR,
    policy_type VARCHAR,
    company_name VARCHAR,
    expiry_date DATE,
    days_until_expiry INTEGER,
    priority VARCHAR
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        p.prospect_id,
        CONCAT(p.first_name, ' ', COALESCE(p.last_name, '')) as full_name,
        p.phone_number,
        p.email,
        e.policy_type,
        e.company_name,
        e.expiry_date,
        fn_days_until_expiry(e.expiry_date) as days_until_expiry,
        CASE 
            WHEN fn_days_until_expiry(e.expiry_date) <= 7 THEN 'High'
            WHEN fn_days_until_expiry(e.expiry_date) <= 15 THEN 'Medium'
            ELSE 'Low'
        END as priority
    FROM prospects p
    JOIN prospect_external_policies e ON p.prospect_id = e.prospect_id
    WHERE p.agent_id = p_agent_id
      AND e.expiry_date BETWEEN CURRENT_DATE AND (CURRENT_DATE + INTERVAL '%s days')
      AND e.is_active = TRUE
      AND p.is_active = TRUE
    ORDER BY e.expiry_date;
END;
$$ LANGUAGE plpgsql;




-- Indexes for prospects table
CREATE INDEX idx_prospects_agent_id ON prospects(agent_id);
CREATE INDEX idx_prospects_is_active ON prospects(is_active);
CREATE INDEX idx_prospects_phone ON prospects(phone_number);
CREATE INDEX idx_prospects_email ON prospects(email);

-- Indexes for external policies
CREATE INDEX idx_prospect_external_policies_prospect_id ON prospect_external_policies(prospect_id);
CREATE INDEX idx_prospect_external_policies_expiry_date ON prospect_external_policies(expiry_date);
CREATE INDEX idx_prospect_external_policies_is_active ON prospect_external_policies(is_active);