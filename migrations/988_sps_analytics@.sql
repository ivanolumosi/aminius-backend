-- ===========================================================
-- Get Policy Statistics
-- ===========================================================
CREATE OR REPLACE FUNCTION sp_get_policy_statistics1(p_agent_id UUID)
RETURNS TABLE(
    active_policies BIGINT,
    expired_policies BIGINT,
    lapsed_policies BIGINT,
    expiring_policies BIGINT,
    policy_types BIGINT,
    insurance_companies BIGINT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        COUNT(CASE WHEN cp.status = 'Active' THEN 1 END) AS active_policies,
        COUNT(CASE WHEN cp.status = 'Expired' THEN 1 END) AS expired_policies,
        COUNT(CASE WHEN cp.status = 'Lapsed' THEN 1 END) AS lapsed_policies,
        COUNT(CASE WHEN cp.end_date BETWEEN CURRENT_DATE AND (CURRENT_DATE + INTERVAL '30 days') THEN 1 END) AS expiring_policies,
        COUNT(DISTINCT pt.type_id) AS policy_types,
        COUNT(DISTINCT ic.company_id) AS insurance_companies
    FROM client_policy cp
    INNER JOIN client c ON cp.client_id = c.client_id
    LEFT JOIN policy_types pt ON cp.type_id = pt.type_id
    LEFT JOIN insurance_companies ic ON cp.company_id = ic.company_id
    WHERE c.agent_id = p_agent_id AND cp.is_active = TRUE AND c.is_active = TRUE;
END;
$$ LANGUAGE plpgsql;

-- ===========================================================
-- Get Policy Statistics Detailed
-- ===========================================================
CREATE OR REPLACE FUNCTION sp_get_policy_statistics_detailed(p_agent_id UUID)
RETURNS TABLE(
    total_policies BIGINT,
    active_policies BIGINT,
    expired_policies BIGINT,
    lapsed_policies BIGINT,
    inactive_policies BIGINT,
    expiring_in_30_days BIGINT,
    expiring_in_7_days BIGINT,
    new_policies_this_month BIGINT,
    motor_policies BIGINT,
    life_policies BIGINT,
    health_policies BIGINT,
    travel_policies BIGINT,
    property_policies BIGINT,
    marine_policies BIGINT,
    business_policies BIGINT,
    catalog_policies BIGINT,
    policy_types BIGINT,
    insurance_companies BIGINT
) AS $$
DECLARE
    v_today DATE := CURRENT_DATE;
    v_month_start DATE := DATE_TRUNC('month', CURRENT_DATE)::DATE;
    v_month_end DATE := (DATE_TRUNC('month', CURRENT_DATE) + INTERVAL '1 month - 1 day')::DATE;
BEGIN
    RETURN QUERY
    SELECT 
        -- Total Policies
        COUNT(DISTINCT cp.policy_id) AS total_policies,
        COUNT(DISTINCT CASE WHEN cp.status = 'Active' THEN cp.policy_id END) AS active_policies,
        COUNT(DISTINCT CASE WHEN cp.status = 'Expired' THEN cp.policy_id END) AS expired_policies,
        COUNT(DISTINCT CASE WHEN cp.status = 'Lapsed' THEN cp.policy_id END) AS lapsed_policies,
        COUNT(DISTINCT CASE WHEN cp.status = 'Inactive' THEN cp.policy_id END) AS inactive_policies,

        -- Expiring Soon (next 30 days)
        COUNT(DISTINCT CASE WHEN cp.end_date BETWEEN v_today AND (v_today + INTERVAL '30 days') 
                             AND cp.status = 'Active' THEN cp.policy_id END) AS expiring_in_30_days,
        COUNT(DISTINCT CASE WHEN cp.end_date BETWEEN v_today AND (v_today + INTERVAL '7 days') 
                             AND cp.status = 'Active' THEN cp.policy_id END) AS expiring_in_7_days,

        -- New Policies This Month
        COUNT(DISTINCT CASE WHEN cp.start_date BETWEEN v_month_start AND v_month_end THEN cp.policy_id END) AS new_policies_this_month,

        -- Policies by Type (using joins to get actual type names)
        COUNT(DISTINCT CASE WHEN pt.type_name = 'Motor' THEN cp.policy_id END) AS motor_policies,
        COUNT(DISTINCT CASE WHEN pt.type_name = 'Life' THEN cp.policy_id END) AS life_policies,
        COUNT(DISTINCT CASE WHEN pt.type_name = 'Health' THEN cp.policy_id END) AS health_policies,
        COUNT(DISTINCT CASE WHEN pt.type_name = 'Travel' THEN cp.policy_id END) AS travel_policies,
        COUNT(DISTINCT CASE WHEN pt.type_name = 'Property' THEN cp.policy_id END) AS property_policies,
        COUNT(DISTINCT CASE WHEN pt.type_name = 'Marine' THEN cp.policy_id END) AS marine_policies,
        COUNT(DISTINCT CASE WHEN pt.type_name = 'Business' THEN cp.policy_id END) AS business_policies,

        -- Catalog Statistics
        COUNT(DISTINCT pc.policy_catalog_id) AS catalog_policies,
        COUNT(DISTINCT pt.type_id) AS policy_types,
        COUNT(DISTINCT ic.company_id) AS insurance_companies
        
    FROM client_policy cp
    INNER JOIN client c ON cp.client_id = c.client_id
    LEFT JOIN policy_catalog pc ON cp.policy_catalog_id = pc.policy_catalog_id
    LEFT JOIN policy_types pt ON cp.type_id = pt.type_id
    LEFT JOIN insurance_companies ic ON cp.company_id = ic.company_id
    WHERE c.agent_id = p_agent_id 
      AND cp.is_active = TRUE 
      AND c.is_active = TRUE;
END;
$$ LANGUAGE plpgsql;

-- ===========================================================
-- Get Expiring Policies (Fixed parameter defaults)
-- ===========================================================
CREATE OR REPLACE FUNCTION sp_get_expiring_policies(
    p_agent_id UUID,
    p_days_ahead INTEGER DEFAULT 30
)
RETURNS TABLE(
    policy_id UUID,
    client_id UUID,
    policy_name VARCHAR(100),
    type_name VARCHAR(100),
    company_name VARCHAR(100),
    status VARCHAR(20),
    start_date DATE,
    end_date DATE,
    notes TEXT,
    client_name VARCHAR(150),
    client_phone VARCHAR(20),
    client_email VARCHAR(100),
    days_until_expiry INTEGER
) AS $$
DECLARE
    v_start_date DATE := CURRENT_DATE;
    v_end_date DATE := CURRENT_DATE + INTERVAL '1 day' * p_days_ahead;
BEGIN
    RETURN QUERY
    SELECT 
        cp.policy_id,
        cp.client_id,
        cp.policy_name,
        pt.type_name,
        ic.company_name,
        cp.status,
        cp.start_date,
        cp.end_date,
        cp.notes,
        (c.first_name || ' ' || c.surname) AS client_name,
        c.phone AS client_phone,
        c.email AS client_email,
        (cp.end_date - v_start_date)::INTEGER AS days_until_expiry
    FROM client_policy cp
    INNER JOIN client c ON cp.client_id = c.client_id
    LEFT JOIN policy_types pt ON cp.type_id = pt.type_id
    LEFT JOIN insurance_companies ic ON cp.company_id = ic.company_id
    WHERE 
        c.agent_id = p_agent_id 
        AND cp.status = 'Active'
        AND cp.is_active = TRUE
        AND c.is_active = TRUE
        AND cp.end_date BETWEEN v_start_date AND v_end_date
    ORDER BY cp.end_date ASC;
END;
$$ LANGUAGE plpgsql;

-- ===========================================================
-- Get Expiring Policies by Period (Fixed parameter defaults)
-- ===========================================================
CREATE OR REPLACE FUNCTION sp_get_expiring_policies_by_period(
    p_period VARCHAR(20),
    p_agent_id UUID DEFAULT NULL
)
RETURNS TABLE(
    policy_id UUID,
    client_id UUID,
    client_name VARCHAR(150),
    client_phone VARCHAR(20),
    client_email VARCHAR(100),
    policy_name VARCHAR(100),
    policy_type VARCHAR(100),
    company_name VARCHAR(100),
    start_date DATE,
    end_date DATE,
    status VARCHAR(20),
    notes TEXT,
    days_until_expiry INTEGER
) AS $$
DECLARE
    v_days INTEGER;
BEGIN
    -- Determine days based on period
    v_days := CASE UPPER(p_period)
                WHEN '1D' THEN 1
                WHEN '1W' THEN 7
                WHEN '1M' THEN 30
                WHEN '1Y' THEN 365
                WHEN '2Y' THEN 730
                WHEN '3Y' THEN 1095
                ELSE NULL
              END;

    IF v_days IS NULL THEN
        RAISE EXCEPTION 'Invalid period specified. Use 1D, 1W, 1M, 1Y, 2Y, or 3Y.';
    END IF;

    RETURN QUERY
    SELECT 
        cp.policy_id,
        cp.client_id,
        (c.first_name || ' ' || c.surname) AS client_name,
        c.phone AS client_phone,
        c.email AS client_email,
        cp.policy_name,
        pt.type_name AS policy_type,
        ic.company_name,
        cp.start_date,
        cp.end_date,
        cp.status,
        cp.notes,
        (cp.end_date - CURRENT_DATE)::INTEGER AS days_until_expiry
    FROM client_policy cp
    INNER JOIN client c ON cp.client_id = c.client_id
    LEFT JOIN policy_types pt ON cp.type_id = pt.type_id
    LEFT JOIN insurance_companies ic ON cp.company_id = ic.company_id
    WHERE 
        cp.is_active = TRUE
        AND cp.status = 'Active'
        AND c.is_active = TRUE
        AND (p_agent_id IS NULL OR c.agent_id = p_agent_id)
        AND cp.end_date BETWEEN CURRENT_DATE AND (CURRENT_DATE + INTERVAL '1 day' * v_days)
    ORDER BY cp.end_date ASC;
END;
$$ LANGUAGE plpgsql;

-- ===========================================================
-- Get Dashboard Analytics
-- ===========================================================
CREATE OR REPLACE FUNCTION sp_get_dashboard_analytics(p_agent_id UUID)
RETURNS TABLE(
    total_clients BIGINT,
    total_prospects BIGINT,
    active_policies BIGINT,
    expiring_policies BIGINT,
    today_birthdays BIGINT,
    this_week_appointments BIGINT,
    pending_reminders BIGINT,
    recent_activities BIGINT,
    policy_type_breakdown JSONB,
    monthly_growth JSONB
) AS $$
DECLARE
    v_today DATE := CURRENT_DATE;
    v_week_start DATE := DATE_TRUNC('week', CURRENT_DATE)::DATE;
    v_week_end DATE := v_week_start + INTERVAL '6 days';
    v_month_start DATE := DATE_TRUNC('month', CURRENT_DATE)::DATE;
    v_last_month_start DATE := (DATE_TRUNC('month', CURRENT_DATE) - INTERVAL '1 month')::DATE;
    v_last_month_end DATE := (DATE_TRUNC('month', CURRENT_DATE) - INTERVAL '1 day')::DATE;
BEGIN
    RETURN QUERY
    SELECT 
        -- Basic counts
        (SELECT COUNT(*) FROM client WHERE agent_id = p_agent_id AND is_client = TRUE AND is_active = TRUE) AS total_clients,
        (SELECT COUNT(*) FROM client WHERE agent_id = p_agent_id AND is_client = FALSE AND is_active = TRUE) AS total_prospects,
        
        -- Policy counts
        (SELECT COUNT(*) FROM client_policy cp 
         INNER JOIN client c ON cp.client_id = c.client_id 
         WHERE c.agent_id = p_agent_id AND cp.status = 'Active' AND cp.is_active = TRUE) AS active_policies,
        
        (SELECT COUNT(*) FROM client_policy cp 
         INNER JOIN client c ON cp.client_id = c.client_id 
         WHERE c.agent_id = p_agent_id AND cp.status = 'Active' AND cp.is_active = TRUE
         AND cp.end_date BETWEEN v_today AND (v_today + INTERVAL '30 days')) AS expiring_policies,
        
        -- Today's birthdays
        (SELECT COUNT(*) FROM client 
         WHERE agent_id = p_agent_id AND is_active = TRUE
         AND EXTRACT(MONTH FROM date_of_birth) = EXTRACT(MONTH FROM v_today)
         AND EXTRACT(DAY FROM date_of_birth) = EXTRACT(DAY FROM v_today)) AS today_birthdays,
        
        -- This week appointments
        (SELECT COUNT(*) FROM appointment 
         WHERE agent_id = p_agent_id AND is_active = TRUE
         AND appointment_date BETWEEN v_week_start AND v_week_end) AS this_week_appointments,
        
        -- Pending reminders
        (SELECT COUNT(*) FROM reminder 
         WHERE agent_id = p_agent_id AND status = 'Pending'
         AND reminder_date <= v_today) AS pending_reminders,
        
        -- Recent activities (last 7 days)
        (SELECT COUNT(*) FROM activity_log 
         WHERE agent_id = p_agent_id 
         AND created_date >= (v_today - INTERVAL '7 days')) AS recent_activities,
        
        -- Policy type breakdown
        (SELECT jsonb_agg(
            jsonb_build_object(
                'type_name', type_name,
                'count', policy_count
            )
        )
         FROM (
            SELECT pt.type_name, COUNT(cp.policy_id) AS policy_count
            FROM client_policy cp
            INNER JOIN client c ON cp.client_id = c.client_id
            INNER JOIN policy_types pt ON cp.type_id = pt.type_id
            WHERE c.agent_id = p_agent_id AND cp.is_active = TRUE AND cp.status = 'Active'
            GROUP BY pt.type_name
            ORDER BY policy_count DESC
         ) breakdown) AS policy_type_breakdown,
        
        -- Monthly growth comparison
        (SELECT jsonb_build_object(
            'current_month_clients', current_month.count_clients,
            'last_month_clients', last_month.count_clients,
            'current_month_policies', current_month.count_policies,
            'last_month_policies', last_month.count_policies
        )
         FROM (
            SELECT 
                COUNT(CASE WHEN is_client = TRUE THEN 1 END) AS count_clients,
                0 AS count_policies
            FROM client 
            WHERE agent_id = p_agent_id AND is_active = TRUE
            AND created_date >= v_month_start
         ) current_month,
         (
            SELECT 
                COUNT(CASE WHEN is_client = TRUE THEN 1 END) AS count_clients,
                0 AS count_policies
            FROM client 
            WHERE agent_id = p_agent_id AND is_active = TRUE
            AND created_date BETWEEN v_last_month_start AND v_last_month_end
         ) last_month) AS monthly_growth;
END;
$$ LANGUAGE plpgsql;

-- ===========================================================
-- Get Client Growth Analytics (Fixed parameter defaults)
-- ===========================================================
CREATE OR REPLACE FUNCTION sp_get_client_growth_analytics(
    p_agent_id UUID,
    p_months INTEGER DEFAULT 12
)
RETURNS TABLE(
    month_year VARCHAR(7),
    new_clients BIGINT,
    new_prospects BIGINT,
    total_new BIGINT,
    cumulative_clients BIGINT,
    cumulative_prospects BIGINT
) AS $$
DECLARE
    v_start_date DATE := (CURRENT_DATE - INTERVAL '1 month' * p_months)::DATE;
BEGIN
    RETURN QUERY
    WITH monthly_data AS (
        SELECT 
            TO_CHAR(DATE_TRUNC('month', created_date), 'YYYY-MM') AS month_year,
            COUNT(CASE WHEN is_client = TRUE THEN 1 END) AS new_clients,
            COUNT(CASE WHEN is_client = FALSE THEN 1 END) AS new_prospects,
            COUNT(*) AS total_new
        FROM client
        WHERE agent_id = p_agent_id 
          AND is_active = TRUE
          AND created_date >= v_start_date
        GROUP BY DATE_TRUNC('month', created_date)
        ORDER BY DATE_TRUNC('month', created_date)
    )
    SELECT 
        md.month_year,
        md.new_clients,
        md.new_prospects,
        md.total_new,
        SUM(md.new_clients) OVER (ORDER BY md.month_year) AS cumulative_clients,
        SUM(md.new_prospects) OVER (ORDER BY md.month_year) AS cumulative_prospects
    FROM monthly_data md;
END;
$$ LANGUAGE plpgsql;

-- ===========================================================
-- Get Policy Performance Analytics (Fixed parameter defaults)
-- ===========================================================
CREATE OR REPLACE FUNCTION sp_get_policy_performance_analytics(
    p_agent_id UUID,
    p_months INTEGER DEFAULT 12
)
RETURNS TABLE(
    policy_type VARCHAR(100),
    active_count BIGINT,
    expired_count BIGINT,
    lapsed_count BIGINT,
    renewal_rate NUMERIC(5,2),
    avg_duration_days NUMERIC(10,2),
    expiring_next_30_days BIGINT
) AS $$
DECLARE
    v_start_date DATE := (CURRENT_DATE - INTERVAL '1 month' * p_months)::DATE;
BEGIN
    RETURN QUERY
    SELECT 
        pt.type_name AS policy_type,
        COUNT(CASE WHEN cp.status = 'Active' THEN 1 END) AS active_count,
        COUNT(CASE WHEN cp.status = 'Expired' THEN 1 END) AS expired_count,
        COUNT(CASE WHEN cp.status = 'Lapsed' THEN 1 END) AS lapsed_count,
        CASE 
            WHEN COUNT(CASE WHEN cp.status IN ('Expired', 'Lapsed') THEN 1 END) = 0 THEN 0
            ELSE ROUND(
                (COUNT(CASE WHEN cp.status = 'Active' THEN 1 END)::NUMERIC / 
                 COUNT(CASE WHEN cp.status IN ('Active', 'Expired', 'Lapsed') THEN 1 END)::NUMERIC) * 100, 2
            )
        END AS renewal_rate,
        ROUND(AVG(EXTRACT(EPOCH FROM (cp.end_date - cp.start_date)) / 86400), 2) AS avg_duration_days,
        COUNT(CASE WHEN cp.end_date BETWEEN CURRENT_DATE AND (CURRENT_DATE + INTERVAL '30 days') 
                   AND cp.status = 'Active' THEN 1 END) AS expiring_next_30_days
    FROM client_policy cp
    INNER JOIN client c ON cp.client_id = c.client_id
    INNER JOIN policy_types pt ON cp.type_id = pt.type_id
    WHERE c.agent_id = p_agent_id 
      AND cp.is_active = TRUE
      AND cp.created_date >= v_start_date
    GROUP BY pt.type_name
    ORDER BY active_count DESC;
END;
$$ LANGUAGE plpgsql;

-- ===========================================================
-- Dashboard Statistics Functions
-- ===========================================================

-- Get Dashboard Statistics
CREATE OR REPLACE FUNCTION sp_get_dashboard_stats(p_agent_id UUID)
RETURNS TABLE (
    total_clients INTEGER,
    total_policies INTEGER,
    active_policies INTEGER,
    expiring_policies INTEGER,
    today_appointments INTEGER,
    pending_reminders INTEGER,
    today_birthdays INTEGER,
    monthly_revenue DECIMAL(10,2)
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        (SELECT COUNT(*)::INTEGER FROM clients WHERE agent_id = p_agent_id AND is_active = TRUE),
        (SELECT COUNT(*)::INTEGER FROM client_policies cp 
         INNER JOIN clients c ON cp.client_id = c.client_id 
         WHERE c.agent_id = p_agent_id AND cp.is_active = TRUE),
        (SELECT COUNT(*)::INTEGER FROM client_policies cp 
         INNER JOIN clients c ON cp.client_id = c.client_id 
         WHERE c.agent_id = p_agent_id AND cp.status = 'Active' AND cp.is_active = TRUE),
        (SELECT COUNT(*)::INTEGER FROM client_policies cp 
         INNER JOIN clients c ON cp.client_id = c.client_id 
         WHERE c.agent_id = p_agent_id AND cp.status = 'Active' 
         AND cp.end_date BETWEEN CURRENT_DATE AND CURRENT_DATE + INTERVAL '30 days'),
        (SELECT COUNT(*)::INTEGER FROM appointments a 
         INNER JOIN clients c ON a.client_id = c.client_id 
         WHERE c.agent_id = p_agent_id AND a.appointment_date = CURRENT_DATE 
         AND a.status NOT IN ('Cancelled') AND a.is_active = TRUE),
        (SELECT COUNT(*)::INTEGER FROM reminders r 
         INNER JOIN clients c ON r.client_id = c.client_id 
         WHERE c.agent_id = p_agent_id AND r.status = 'Active' 
         AND r.reminder_date <= CURRENT_DATE),
        (SELECT COUNT(*)::INTEGER FROM clients 
         WHERE agent_id = p_agent_id AND is_active = TRUE 
         AND EXTRACT(MONTH FROM date_of_birth) = EXTRACT(MONTH FROM CURRENT_DATE)
         AND EXTRACT(DAY FROM date_of_birth) = EXTRACT(DAY FROM CURRENT_DATE)),
        (SELECT COALESCE(SUM(premium_amount), 0)::DECIMAL(10,2) FROM client_policies cp 
         INNER JOIN clients c ON cp.client_id = c.client_id 
         WHERE c.agent_id = p_agent_id AND cp.status = 'Active' 
         AND EXTRACT(MONTH FROM cp.created_date) = EXTRACT(MONTH FROM CURRENT_DATE)
         AND EXTRACT(YEAR FROM cp.created_date) = EXTRACT(YEAR FROM CURRENT_DATE));
END;
$$ LANGUAGE plpgsql;

-- Get Recent Activities (Fixed parameter defaults)
CREATE OR REPLACE FUNCTION sp_get_recent_activities(
    p_agent_id UUID,
    p_limit INTEGER DEFAULT 10
)
RETURNS TABLE (
    activity_id UUID,
    activity_type VARCHAR(50),
    entity_type VARCHAR(50),
    entity_id UUID,
    description TEXT,
    activity_date TIMESTAMPTZ
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        al.activity_id,
        al.activity_type,
        al.entity_type,
        al.entity_id,
        al.description,
        al.activity_date
    FROM activity_log al
    WHERE al.agent_id = p_agent_id
    ORDER BY al.activity_date DESC
    LIMIT p_limit;
END;
$$ LANGUAGE plpgsql;

-- Get Today's Appointments
CREATE OR REPLACE FUNCTION sp_get_today_appointments1(p_agent_id UUID)
RETURNS TABLE (
    appointment_id UUID,
    client_id UUID,
    client_name VARCHAR(150),
    title VARCHAR(200),
    start_time TIME,
    end_time TIME,
    status VARCHAR(20),
    appointment_type VARCHAR(50),
    notes TEXT,
    phone_number VARCHAR(20)
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        a.appointment_id,
        a.client_id,
        CONCAT(c.first_name, ' ', c.surname, ' ', COALESCE(c.last_name, '')) as client_name,
        a.title,
        a.start_time,
        a.end_time,
        a.status,
        a.appointment_type,
        a.notes,
        c.phone_number
    FROM appointments a
    INNER JOIN clients c ON a.client_id = c.client_id
    WHERE c.agent_id = p_agent_id 
    AND a.appointment_date = CURRENT_DATE
    AND a.is_active = TRUE
    ORDER BY a.start_time;
END;
$$ LANGUAGE plpgsql;

-- -- Get Today's Birthdays
-- CREATE OR REPLACE FUNCTION sp_get_today_birthdays(p_agent_id UUID)
-- RETURNS TABLE (
--     client_id UUID,
--     client_name VARCHAR(150),
--     phone_number VARCHAR(20),
--     email VARCHAR(100),
--     date_of_birth DATE,
--     age INTEGER
-- ) AS $$
-- BEGIN
--     RETURN QUERY
--     SELECT 
--         c.client_id,
--         CONCAT(c.first_name, ' ', c.surname, ' ', COALESCE(c.last_name, '')) as client_name,
--         c.phone_number,
--         c.email,
--         c.date_of_birth,
--         (EXTRACT(YEAR FROM AGE(CURRENT_DATE, c.date_of_birth)))::INTEGER as age
--     FROM clients c
--     WHERE c.agent_id = p_agent_id 
--     AND c.is_active = TRUE
--     AND EXTRACT(MONTH FROM c.date_of_birth) = EXTRACT(MONTH FROM CURRENT_DATE)
--     AND EXTRACT(DAY FROM c.date_of_birth) = EXTRACT(DAY FROM CURRENT_DATE)
--     ORDER BY c.first_name, c.surname;
-- END;
-- $$ LANGUAGE plpgsql;

-- ===========================================================
-- Performance Analytics Functions
-- ===========================================================

-- Get Monthly Performance (Fixed parameter defaults)
CREATE OR REPLACE FUNCTION sp_get_monthly_performance(
    p_agent_id UUID,
    p_year INTEGER DEFAULT NULL,
    p_month INTEGER DEFAULT NULL
)
RETURNS TABLE (
    month_year VARCHAR(7),
    new_clients INTEGER,
    new_policies INTEGER,
    total_premium DECIMAL(10,2),
    appointments_scheduled INTEGER,
    appointments_completed INTEGER,
    conversion_rate DECIMAL(5,2)
) AS $$
DECLARE
    v_year INTEGER := COALESCE(p_year, EXTRACT(YEAR FROM CURRENT_DATE));
    v_month INTEGER := COALESCE(p_month, EXTRACT(MONTH FROM CURRENT_DATE));
BEGIN
    RETURN QUERY
    WITH monthly_stats AS (
        SELECT 
            TO_CHAR(DATE_TRUNC('month', generate_series), 'YYYY-MM') as month_year,
            generate_series as month_start
        FROM generate_series(
            DATE_TRUNC('month', MAKE_DATE(v_year, GREATEST(1, v_month - 5), 1)),
            DATE_TRUNC('month', MAKE_DATE(v_year, v_month, 1)),
            INTERVAL '1 month'
        )
    )
    SELECT 
        ms.month_year,
        COALESCE(client_stats.new_clients, 0)::INTEGER,
        COALESCE(policy_stats.new_policies, 0)::INTEGER,
        COALESCE(policy_stats.total_premium, 0)::DECIMAL(10,2),
        COALESCE(appt_stats.scheduled, 0)::INTEGER,
        COALESCE(appt_stats.completed, 0)::INTEGER,
        CASE 
            WHEN COALESCE(appt_stats.scheduled, 0) > 0 
            THEN ROUND((COALESCE(appt_stats.completed, 0)::DECIMAL / appt_stats.scheduled) * 100, 2)
            ELSE 0 
        END::DECIMAL(5,2) as conversion_rate
    FROM monthly_stats ms
    LEFT JOIN (
        SELECT 
            TO_CHAR(DATE_TRUNC('month', created_date), 'YYYY-MM') as month_year,
            COUNT(*)::INTEGER as new_clients
        FROM clients 
        WHERE agent_id = p_agent_id 
        AND is_active = TRUE
        GROUP BY DATE_TRUNC('month', created_date)
    ) client_stats ON ms.month_year = client_stats.month_year
    LEFT JOIN (
        SELECT 
            TO_CHAR(DATE_TRUNC('month', cp.created_date), 'YYYY-MM') as month_year,
            COUNT(*)::INTEGER as new_policies,
            SUM(cp.premium_amount)::DECIMAL(10,2) as total_premium
        FROM client_policies cp
        INNER JOIN clients c ON cp.client_id = c.client_id
        WHERE c.agent_id = p_agent_id 
        AND cp.is_active = TRUE
        GROUP BY DATE_TRUNC('month', cp.created_date)
    ) policy_stats ON ms.month_year = policy_stats.month_year
    LEFT JOIN (
        SELECT 
            TO_CHAR(DATE_TRUNC('month', a.appointment_date), 'YYYY-MM') as month_year,
            COUNT(*)::INTEGER as scheduled,
            COUNT(CASE WHEN a.status = 'Completed' THEN 1 END)::INTEGER as completed
        FROM appointments a
        INNER JOIN clients c ON a.client_id = c.client_id
        WHERE c.agent_id = p_agent_id 
        AND a.is_active = TRUE
        GROUP BY DATE_TRUNC('month', a.appointment_date)
    ) appt_stats ON ms.month_year = appt_stats.month_year
    ORDER BY ms.month_year;
END;
$$ LANGUAGE plpgsql;


-- Get Policy Distribution
CREATE OR REPLACE FUNCTION sp_get_policy_distribution(p_agent_id UUID)
RETURNS TABLE (
    policy_type VARCHAR(100),
    policy_count INTEGER,
    total_premium DECIMAL(10,2),
    percentage DECIMAL(5,2)
) AS $$
BEGIN
    RETURN QUERY
    WITH policy_totals AS (
        SELECT 
            cp.policy_type,
            COUNT(*)::INTEGER as policy_count,
            SUM(cp.premium_amount)::DECIMAL(10,2) as total_premium
        FROM client_policies cp
        INNER JOIN clients c ON cp.client_id = c.client_id
        WHERE c.agent_id = p_agent_id 
        AND cp.status = 'Active' 
        AND cp.is_active = TRUE
        GROUP BY cp.policy_type
    ),
    grand_total AS (
        SELECT SUM(policy_count) as total_count
        FROM policy_totals
    )
    SELECT 
        pt.policy_type,
        pt.policy_count,
        pt.total_premium,
        CASE 
            WHEN gt.total_count > 0 
            THEN ROUND((pt.policy_count::DECIMAL / gt.total_count) * 100, 2)
            ELSE 0 
        END::DECIMAL(5,2) as percentage
    FROM policy_totals pt
    CROSS JOIN grand_total gt
    ORDER BY pt.policy_count DESC;
END;
$$ LANGUAGE plpgsql;

-- Get Client Demographics
CREATE OR REPLACE FUNCTION sp_get_client_demographics(p_agent_id UUID)
RETURNS TABLE (
    age_group VARCHAR(20),
    client_count INTEGER,
    percentage DECIMAL(5,2)
) AS $$
BEGIN
    RETURN QUERY
    WITH age_groups AS (
        SELECT 
            CASE 
                WHEN EXTRACT(YEAR FROM AGE(CURRENT_DATE, date_of_birth)) < 25 THEN '18-24'
                WHEN EXTRACT(YEAR FROM AGE(CURRENT_DATE, date_of_birth)) < 35 THEN '25-34'
                WHEN EXTRACT(YEAR FROM AGE(CURRENT_DATE, date_of_birth)) < 45 THEN '35-44'
                WHEN EXTRACT(YEAR FROM AGE(CURRENT_DATE, date_of_birth)) < 55 THEN '45-54'
                WHEN EXTRACT(YEAR FROM AGE(CURRENT_DATE, date_of_birth)) < 65 THEN '55-64'
                ELSE '65+'
            END as age_group,
            COUNT(*)::INTEGER as client_count
        FROM clients 
        WHERE agent_id = p_agent_id 
        AND is_active = TRUE
        AND date_of_birth IS NOT NULL
        GROUP BY 
            CASE 
                WHEN EXTRACT(YEAR FROM AGE(CURRENT_DATE, date_of_birth)) < 25 THEN '18-24'
                WHEN EXTRACT(YEAR FROM AGE(CURRENT_DATE, date_of_birth)) < 35 THEN '25-34'
                WHEN EXTRACT(YEAR FROM AGE(CURRENT_DATE, date_of_birth)) < 45 THEN '35-44'
                WHEN EXTRACT(YEAR FROM AGE(CURRENT_DATE, date_of_birth)) < 55 THEN '45-54'
                WHEN EXTRACT(YEAR FROM AGE(CURRENT_DATE, date_of_birth)) < 65 THEN '55-64'
                ELSE '65+'
            END
    ),
    total_clients AS (
        SELECT SUM(client_count) as total_count
        FROM age_groups
    )
    SELECT 
        ag.age_group,
        ag.client_count,
        CASE 
            WHEN tc.total_count > 0 
            THEN ROUND((ag.client_count::DECIMAL / tc.total_count) * 100, 2)
            ELSE 0 
        END::DECIMAL(5,2) as percentage
    FROM age_groups ag
    CROSS JOIN total_clients tc
    ORDER BY 
        CASE ag.age_group
            WHEN '18-24' THEN 1
            WHEN '25-34' THEN 2
            WHEN '35-44' THEN 3
            WHEN '45-54' THEN 4
            WHEN '55-64' THEN 5
            WHEN '65+' THEN 6
        END;
END;
$$ LANGUAGE plpgsql;

-- ===========================================================
-- Revenue Analytics Functions
-- ===========================================================

-- Get Revenue Summary
CREATE OR REPLACE FUNCTION sp_get_revenue_summary(
    p_agent_id UUID,
    p_start_date DATE DEFAULT NULL,
    p_end_date DATE DEFAULT NULL
)
RETURNS TABLE (
    total_revenue DECIMAL(10,2),
    monthly_revenue DECIMAL(10,2),
    average_policy_value DECIMAL(10,2),
    highest_value_policy DECIMAL(10,2),
    policy_count INTEGER,
    growth_rate DECIMAL(5,2)
) AS $$
DECLARE
    v_start_date DATE := COALESCE(p_start_date, CURRENT_DATE - INTERVAL '1 year');
    v_end_date DATE := COALESCE(p_end_date, CURRENT_DATE);
    v_prev_period_start DATE := v_start_date - (v_end_date - v_start_date);
    v_prev_period_end DATE := v_start_date;
BEGIN
    RETURN QUERY
    WITH current_period AS (
        SELECT 
            SUM(cp.premium_amount) as total_revenue,
            COUNT(*) as policy_count,
            AVG(cp.premium_amount) as avg_premium,
            MAX(cp.premium_amount) as max_premium
        FROM client_policies cp
        INNER JOIN clients c ON cp.client_id = c.client_id
        WHERE c.agent_id = p_agent_id 
        AND cp.created_date BETWEEN v_start_date AND v_end_date
        AND cp.is_active = TRUE
    ),
    previous_period AS (
        SELECT 
            COALESCE(SUM(cp.premium_amount), 0) as prev_total_revenue
        FROM client_policies cp
        INNER JOIN clients c ON cp.client_id = c.client_id
        WHERE c.agent_id = p_agent_id 
        AND cp.created_date BETWEEN v_prev_period_start AND v_prev_period_end
        AND cp.is_active = TRUE
    )
    SELECT 
        COALESCE(cp.total_revenue, 0)::DECIMAL(10,2) as total_revenue,
        ROUND(COALESCE(cp.total_revenue, 0) / 
              EXTRACT(MONTHS FROM AGE(v_end_date, v_start_date)), 2)::DECIMAL(10,2) as monthly_revenue,
        COALESCE(cp.avg_premium, 0)::DECIMAL(10,2) as average_policy_value,
        COALESCE(cp.max_premium, 0)::DECIMAL(10,2) as highest_value_policy,
        COALESCE(cp.policy_count, 0)::INTEGER as policy_count,
        CASE 
            WHEN pp.prev_total_revenue > 0 AND cp.total_revenue IS NOT NULL
            THEN ROUND(((cp.total_revenue - pp.prev_total_revenue) / pp.prev_total_revenue) * 100, 2)
            ELSE 0 
        END::DECIMAL(5,2) as growth_rate
    FROM current_period cp
    CROSS JOIN previous_period pp;
END;
$$ LANGUAGE plpgsql;

-- Get Monthly Revenue Trend
CREATE OR REPLACE FUNCTION sp_get_monthly_revenue_trend(
    p_agent_id UUID,
    p_months INTEGER DEFAULT 12
)
RETURNS TABLE (
    month_year VARCHAR(7),
    revenue DECIMAL(10,2),
    policy_count INTEGER,
    avg_policy_value DECIMAL(10,2)
) AS $$
BEGIN
    RETURN QUERY
    WITH monthly_series AS (
        SELECT 
            TO_CHAR(DATE_TRUNC('month', generate_series), 'YYYY-MM') as month_year,
            generate_series as month_start
        FROM generate_series(
            DATE_TRUNC('month', CURRENT_DATE - INTERVAL '1 month' * (p_months - 1)),
            DATE_TRUNC('month', CURRENT_DATE),
            INTERVAL '1 month'
        )
    )
    SELECT 
        ms.month_year,
        COALESCE(rev.revenue, 0)::DECIMAL(10,2),
        COALESCE(rev.policy_count, 0)::INTEGER,
        COALESCE(rev.avg_policy_value, 0)::DECIMAL(10,2)
    FROM monthly_series ms
    LEFT JOIN (
        SELECT 
            TO_CHAR(DATE_TRUNC('month', cp.created_date), 'YYYY-MM') as month_year,
            SUM(cp.premium_amount)::DECIMAL(10,2) as revenue,
            COUNT(*)::INTEGER as policy_count,
            AVG(cp.premium_amount)::DECIMAL(10,2) as avg_policy_value
        FROM client_policies cp
        INNER JOIN clients c ON cp.client_id = c.client_id
        WHERE c.agent_id = p_agent_id 
        AND cp.is_active = TRUE
        GROUP BY DATE_TRUNC('month', cp.created_date)
    ) rev ON ms.month_year = rev.month_year
    ORDER BY ms.month_year;
END;
$$ LANGUAGE plpgsql;

-- ===========================================================
-- Appointment Analytics Functions
-- ===========================================================

-- Get Appointment Statistics
CREATE OR REPLACE FUNCTION sp_get_appointment_stats(
    p_agent_id UUID,
    p_start_date DATE DEFAULT NULL,
    p_end_date DATE DEFAULT NULL
)
RETURNS TABLE (
    total_appointments INTEGER,
    completed_appointments INTEGER,
    cancelled_appointments INTEGER,
    rescheduled_appointments INTEGER,
    completion_rate DECIMAL(5,2),
    most_common_type VARCHAR(50),
    busiest_day_of_week VARCHAR(10)
) AS $$
DECLARE
    v_start_date DATE := COALESCE(p_start_date, CURRENT_DATE - INTERVAL '30 days');
    v_end_date DATE := COALESCE(p_end_date, CURRENT_DATE);
BEGIN
    RETURN QUERY
    WITH appointment_stats AS (
        SELECT 
            COUNT(*) as total_appointments,
            COUNT(CASE WHEN a.status = 'Completed' THEN 1 END) as completed_appointments,
            COUNT(CASE WHEN a.status = 'Cancelled' THEN 1 END) as cancelled_appointments,
            COUNT(CASE WHEN a.status = 'Rescheduled' THEN 1 END) as rescheduled_appointments
        FROM appointments a
        INNER JOIN clients c ON a.client_id = c.client_id
        WHERE c.agent_id = p_agent_id 
        AND a.appointment_date BETWEEN v_start_date AND v_end_date
        AND a.is_active = TRUE
    ),
    common_type AS (
        SELECT a.appointment_type
        FROM appointments a
        INNER JOIN clients c ON a.client_id = c.client_id
        WHERE c.agent_id = p_agent_id 
        AND a.appointment_date BETWEEN v_start_date AND v_end_date
        AND a.is_active = TRUE
        GROUP BY a.appointment_type
        ORDER BY COUNT(*) DESC
        LIMIT 1
    ),
    busiest_day AS (
        SELECT TO_CHAR(a.appointment_date, 'Day') as day_of_week
        FROM appointments a
        INNER JOIN clients c ON a.client_id = c.client_id
        WHERE c.agent_id = p_agent_id 
        AND a.appointment_date BETWEEN v_start_date AND v_end_date
        AND a.is_active = TRUE
        GROUP BY TO_CHAR(a.appointment_date, 'Day'), EXTRACT(DOW FROM a.appointment_date)
        ORDER BY COUNT(*) DESC, EXTRACT(DOW FROM a.appointment_date)
        LIMIT 1
    )
    SELECT 
        ast.total_appointments::INTEGER,
        ast.completed_appointments::INTEGER,
        ast.cancelled_appointments::INTEGER,
        ast.rescheduled_appointments::INTEGER,
        CASE 
            WHEN ast.total_appointments > 0 
            THEN ROUND((ast.completed_appointments::DECIMAL / ast.total_appointments) * 100, 2)
            ELSE 0 
        END::DECIMAL(5,2) as completion_rate,
        COALESCE(ct.appointment_type, 'N/A')::VARCHAR(50) as most_common_type,
        COALESCE(TRIM(bd.day_of_week), 'N/A')::VARCHAR(10) as busiest_day_of_week
    FROM appointment_stats ast
    LEFT JOIN common_type ct ON TRUE
    LEFT JOIN busiest_day bd ON TRUE;
END;
$$ LANGUAGE plpgsql;

-- ===========================================================
-- Reminder Analytics Functions  
-- ===========================================================

-- Get Reminder Statistics
CREATE OR REPLACE FUNCTION sp_get_reminder_stats(p_agent_id UUID)
RETURNS TABLE (
    total_reminders INTEGER,
    active_reminders INTEGER,
    completed_reminders INTEGER,
    overdue_reminders INTEGER,
    reminder_types JSONB
) AS $$
BEGIN
    RETURN QUERY
    WITH reminder_stats AS (
        SELECT 
            COUNT(*) as total_reminders,
            COUNT(CASE WHEN r.status = 'Active' THEN 1 END) as active_reminders,
            COUNT(CASE WHEN r.status = 'Completed' THEN 1 END) as completed_reminders,
            COUNT(CASE WHEN r.status = 'Active' AND r.reminder_date < CURRENT_DATE THEN 1 END) as overdue_reminders
        FROM reminders r
        INNER JOIN clients c ON r.client_id = c.client_id
        WHERE c.agent_id = p_agent_id
    ),
    reminder_type_stats AS (
        SELECT jsonb_agg(
            jsonb_build_object(
                'type', r.reminder_type,
                'count', type_counts.type_count
            )
        ) as reminder_types
        FROM (
            SELECT 
                r.reminder_type,
                COUNT(*) as type_count
            FROM reminders r
            INNER JOIN clients c ON r.client_id = c.client_id
            WHERE c.agent_id = p_agent_id
            GROUP BY r.reminder_type
        ) type_counts
        JOIN reminders r ON r.reminder_type = type_counts.reminder_type
        GROUP BY TRUE
    )
    SELECT 
        rs.total_reminders::INTEGER,
        rs.active_reminders::INTEGER,
        rs.completed_reminders::INTEGER,
        rs.overdue_reminders::INTEGER,
        COALESCE(rts.reminder_types, '[]'::JSONB) as reminder_types
    FROM reminder_stats rs
    LEFT JOIN reminder_type_stats rts ON TRUE;
END;
$$ LANGUAGE plpgsql;
