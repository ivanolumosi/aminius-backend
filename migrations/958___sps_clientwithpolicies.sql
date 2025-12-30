CREATE OR REPLACE FUNCTION sp_get_clients_with_policies(
    p_agent_id UUID DEFAULT NULL,
    p_client_id UUID DEFAULT NULL,
    p_include_inactive BOOLEAN DEFAULT FALSE
) RETURNS TABLE(
    client_id UUID,
    agent_id UUID,
    first_name VARCHAR(50),
    surname VARCHAR(50),
    last_name VARCHAR(50),
    full_name VARCHAR(152),
    phone_number VARCHAR(20),
    email VARCHAR(100),
    address TEXT,
    national_id VARCHAR(20),
    date_of_birth DATE,
    is_client BOOLEAN,
    insurance_type VARCHAR(50),
    client_notes TEXT,
    client_created_date TIMESTAMPTZ,
    client_modified_date TIMESTAMPTZ,
    client_is_active BOOLEAN,
    policy_id UUID,
    policy_name VARCHAR(100),
    status VARCHAR(20),
    start_date DATE,
    end_date DATE,
    policy_notes TEXT,
    policy_created_date TIMESTAMPTZ,
    policy_modified_date TIMESTAMPTZ,
    policy_is_active BOOLEAN,
    policy_catalog_id UUID,
    catalog_policy_name VARCHAR(100),
    type_id UUID,
    type_name VARCHAR(50),
    company_id UUID,
    company_name VARCHAR(100),
    days_until_expiry INTEGER
)
AS $$
BEGIN
    RETURN QUERY
    SELECT
        c.client_id,
        c.agent_id,
        c.first_name,
        c.surname,
        c.last_name,
        (c.first_name || ' ' || c.surname || ' ' || c.last_name)::VARCHAR(152) AS full_name,
        c.phone_number,
        c.email,
        c.address::TEXT, -- ✅ Explicit cast to TEXT
        c.national_id,
        c.date_of_birth,
        c.is_client,
        c.insurance_type,
        c.notes AS client_notes,
        c.created_date AS client_created_date,
        c.modified_date AS client_modified_date,
        c.is_active AS client_is_active,
        cp.policy_id,
        cp.policy_name,
        cp.status,
        cp.start_date,
        cp.end_date,
        cp.notes AS policy_notes,
        cp.created_date AS policy_created_date,
        cp.modified_date AS policy_modified_date,
        cp.is_active AS policy_is_active,
        cp.policy_catalog_id,
        pc.policy_name AS catalog_policy_name,
        cp.type_id,
        pt.type_name,
        cp.company_id,
        ic.company_name,
        (cp.end_date - CURRENT_DATE)::INTEGER AS days_until_expiry
    FROM clients c
    INNER JOIN client_policies cp ON c.client_id = cp.client_id
        AND cp.policy_id IS NOT NULL
        AND cp.company_id IS NOT NULL
        AND cp.type_id IS NOT NULL
    LEFT JOIN policy_catalog pc ON cp.policy_catalog_id = pc.policy_catalog_id
    LEFT JOIN policy_types pt ON cp.type_id = pt.type_id
    LEFT JOIN insurance_companies ic ON cp.company_id = ic.company_id
    WHERE
        (p_agent_id IS NULL OR c.agent_id = p_agent_id)
        AND (p_client_id IS NULL OR c.client_id = p_client_id)
        AND (
            p_include_inactive = TRUE
            OR (COALESCE(c.is_active, TRUE) = TRUE AND COALESCE(cp.is_active, TRUE) = TRUE)
        )
    ORDER BY c.created_date DESC, cp.end_date DESC;
END;
$$ LANGUAGE plpgsql;
