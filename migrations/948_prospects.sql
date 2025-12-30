CREATE OR REPLACE FUNCTION sp_add_prospect(
    p_agent_id UUID,
    p_first_name VARCHAR,
    p_surname VARCHAR,
    p_last_name VARCHAR,
    p_phone VARCHAR,
    p_email VARCHAR,
    p_notes TEXT
)
RETURNS UUID AS $$
DECLARE
    new_id UUID;
BEGIN
    INSERT INTO prospects (agent_id, first_name, surname, last_name, phone_number, email, notes)
    VALUES (p_agent_id, p_first_name, p_surname, p_last_name, p_phone, p_email, p_notes)
    RETURNING prospect_id INTO new_id;
    RETURN new_id;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION sp_add_prospect_policy(
    p_prospect_id UUID,
    p_company_name VARCHAR,
    p_policy_number VARCHAR,
    p_policy_type VARCHAR,
    p_expiry_date DATE,
    p_notes TEXT
)
RETURNS UUID AS $$
DECLARE
    new_id UUID;
BEGIN
    INSERT INTO prospect_external_policies (prospect_id, company_name, policy_number, policy_type, expiry_date, notes)
    VALUES (p_prospect_id, p_company_name, p_policy_number, p_policy_type, p_expiry_date, p_notes)
    RETURNING ext_policy_id INTO new_id;
    RETURN new_id;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION sp_update_prospect(
    p_prospect_id UUID,
    p_first_name VARCHAR,
    p_surname VARCHAR,
    p_last_name VARCHAR,
    p_phone VARCHAR,
    p_email VARCHAR,
    p_notes TEXT
)
RETURNS VOID AS $$
BEGIN
    UPDATE prospects
    SET first_name = p_first_name,
        surname = p_surname,
        last_name = p_last_name,
        phone_number = p_phone,
        email = p_email,
        notes = p_notes,
        modified_date = NOW()
    WHERE prospect_id = p_prospect_id;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION sp_delete_prospect(p_prospect_id UUID)
RETURNS VOID AS $$
BEGIN
    DELETE FROM prospects WHERE prospect_id = p_prospect_id;
END;
$$ LANGUAGE plpgsql;

-- Improved conversion function with better data handling
CREATE OR REPLACE FUNCTION sp_convert_prospect_to_client(
    p_prospect_id UUID,
    p_address VARCHAR DEFAULT 'To be provided',
    p_national_id VARCHAR DEFAULT 'To be provided',
    p_date_of_birth DATE DEFAULT NULL
)
RETURNS UUID AS $$
DECLARE
    new_client_id UUID;
    prospect_record RECORD;
BEGIN
    -- Fetch prospect info
    SELECT * INTO prospect_record
    FROM prospects
    WHERE prospect_id = p_prospect_id AND is_active = TRUE;
    
    -- Check if prospect exists
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Prospect with ID % not found or inactive', p_prospect_id;
    END IF;

    -- Insert into clients with better defaults
    INSERT INTO clients (
        agent_id, 
        first_name, 
        surname, 
        last_name, 
        phone_number, 
        email, 
        address, 
        national_id, 
        date_of_birth, 
        is_client,
        notes
    )
    VALUES (
        prospect_record.agent_id,
        prospect_record.first_name,
        COALESCE(prospect_record.surname, ''),
        COALESCE(prospect_record.last_name, ''),
        COALESCE(prospect_record.phone_number, ''),
        COALESCE(prospect_record.email, ''),
        p_address,
        p_national_id,
        COALESCE(p_date_of_birth, CURRENT_DATE - INTERVAL '30 years'), -- More reasonable default
        TRUE,
        CONCAT('Converted from prospect. Original notes: ', COALESCE(prospect_record.notes, ''))
    )
    RETURNING client_id INTO new_client_id;

    -- Mark prospect as inactive (don't delete to maintain history)
    UPDATE prospects 
    SET is_active = FALSE, 
        modified_date = NOW(),
        notes = CONCAT(COALESCE(notes, ''), ' [CONVERTED TO CLIENT: ', new_client_id, ']')
    WHERE prospect_id = p_prospect_id;

    -- Log the conversion activity
    INSERT INTO activity_log (agent_id, activity_type, entity_type, entity_id, description)
    VALUES (
        prospect_record.agent_id,
        'prospect_converted',
        'client',
        new_client_id,
        'Prospect converted to client: ' || prospect_record.first_name || ' ' || COALESCE(prospect_record.last_name, '')
    );

    RETURN new_client_id;
END;
$$ LANGUAGE plpgsql;
CREATE OR REPLACE VIEW expiring_prospect_policies AS
SELECT 
    p.prospect_id,
    p.first_name,
    p.last_name,
    e.company_name,
    e.policy_number,
    e.expiry_date,
    fn_days_until_expiry(e.expiry_date) AS days_until_expiry
FROM prospects p
JOIN prospect_external_policies e ON p.prospect_id = e.prospect_id
WHERE e.expiry_date BETWEEN CURRENT_DATE AND (CURRENT_DATE + INTERVAL '30 days')
  AND e.is_active = TRUE
  AND p.is_active = TRUE
ORDER BY e.expiry_date;
