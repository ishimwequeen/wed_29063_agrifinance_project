CREATE OR REPLACE FUNCTION CHECK_ELIGIBILITY(
    p_farmer_id IN NUMBER,
    p_subsidy_type_id IN NUMBER,
    p_min_land_acres IN NUMBER DEFAULT 1  -- Minimum land requirement
) 
RETURN VARCHAR2
IS
    v_total_land_acres NUMBER := 0;
    v_recent_apps NUMBER := 0;
    v_pending_apps NUMBER := 0;
    v_farmer_count NUMBER := 0;
    v_subsidy_count NUMBER := 0;
    v_result VARCHAR2(1000);
BEGIN
    -- 1. Check if farmer exists
    SELECT COUNT(*) INTO v_farmer_count
    FROM FARMERS 
    WHERE FARMER_ID = p_farmer_id;
    
    IF v_farmer_count = 0 THEN
        RETURN 'INVALID_FARMER: Farmer ID ' || p_farmer_id || ' does not exist';
    END IF;
    
    -- 2. Check if subsidy type exists
    SELECT COUNT(*) INTO v_subsidy_count
    FROM SUBSIDY_TYPES 
    WHERE TYPE_ID = p_subsidy_type_id;
    
    IF v_subsidy_count = 0 THEN
        RETURN 'INVALID_SUBSIDY: Subsidy Type ID ' || p_subsidy_type_id || ' does not exist';
    END IF;
    
    -- 3. Check total land size (using LAND_SIZE_ACRES column)
    SELECT NVL(SUM(LAND_SIZE_ACRES), 0) INTO v_total_land_acres
    FROM LANDS 
    WHERE FARMER_ID = p_farmer_id
    AND OWNERSHIP_TYPE IN ('OWNED', 'LEASED');  -- Only count owned or leased lands
    
    IF v_total_land_acres < p_min_land_acres THEN
        RETURN 'INELIGIBLE - Insufficient land: ' || 
               ROUND(v_total_land_acres, 2) || ' acres < required ' || 
               p_min_land_acres || ' acres';
    END IF;
    
    -- 4. Check recent applications (last 6 months)
    SELECT COUNT(*) INTO v_recent_apps
    FROM APPLICATIONS 
    WHERE FARMER_ID = p_farmer_id
    AND SUBSIDY_TYPE_ID = p_subsidy_type_id
    AND APPLICATION_DATE >= ADD_MONTHS(SYSDATE, -6);
    
    IF v_recent_apps >= 2 THEN
        RETURN 'INELIGIBLE - Too many recent applications: ' || 
               v_recent_apps || ' in last 6 months. Maximum: 1';
    END IF;
    
    -- 5. Check for pending applications
    SELECT COUNT(*) INTO v_pending_apps
    FROM APPLICATIONS 
    WHERE FARMER_ID = p_farmer_id
    AND SUBSIDY_TYPE_ID = p_subsidy_type_id
    AND STATUS = 'PENDING';
    
    IF v_pending_apps > 0 THEN
        RETURN 'INELIGIBLE - Has ' || v_pending_apps || ' pending application(s)';
    END IF;
    
    -- If all checks pass
    RETURN 'ELIGIBLE - ' || v_total_land_acres || ' acres land, qualifies for subsidy';
    
EXCEPTION
    WHEN OTHERS THEN
        -- Return error without crashing
        RETURN 'ERROR checking eligibility: ' || SQLERRM;
END CHECK_ELIGIBILITY;
/

--
CREATE OR REPLACE FUNCTION CHECK_ELIGIBILITY(
    p_farmer_id IN NUMBER,
    p_subsidy_type_id IN NUMBER,
    p_min_land_acres IN NUMBER DEFAULT 1  -- Minimum land requirement
) 
RETURN VARCHAR2
IS
    v_total_land_acres NUMBER := 0;
    v_recent_apps NUMBER := 0;
    v_pending_apps NUMBER := 0;
    v_farmer_count NUMBER := 0;
    v_subsidy_count NUMBER := 0;
    v_result VARCHAR2(1000);
BEGIN
    -- 1. Check if farmer exists
    SELECT COUNT(*) INTO v_farmer_count
    FROM FARMERS 
    WHERE FARMER_ID = p_farmer_id;
    
    IF v_farmer_count = 0 THEN
        RETURN 'INVALID_FARMER: Farmer ID ' || p_farmer_id || ' does not exist';
    END IF;
    
    -- 2. Check if subsidy type exists
    SELECT COUNT(*) INTO v_subsidy_count
    FROM SUBSIDY_TYPES 
    WHERE TYPE_ID = p_subsidy_type_id;
    
    IF v_subsidy_count = 0 THEN
        RETURN 'INVALID_SUBSIDY: Subsidy Type ID ' || p_subsidy_type_id || ' does not exist';
    END IF;
    
    -- 3. Check total land size (using LAND_SIZE_ACRES column)
    SELECT NVL(SUM(LAND_SIZE_ACRES), 0) INTO v_total_land_acres
    FROM LANDS 
    WHERE FARMER_ID = p_farmer_id
    AND OWNERSHIP_TYPE IN ('OWNED', 'LEASED');  -- Only count owned or leased lands
    
    IF v_total_land_acres < p_min_land_acres THEN
        RETURN 'INELIGIBLE - Insufficient land: ' || 
               ROUND(v_total_land_acres, 2) || ' acres < required ' || 
               p_min_land_acres || ' acres';
    END IF;
    
    -- 4. Check recent applications (last 6 months)
    SELECT COUNT(*) INTO v_recent_apps
    FROM APPLICATIONS 
    WHERE FARMER_ID = p_farmer_id
    AND SUBSIDY_TYPE_ID = p_subsidy_type_id
    AND APPLICATION_DATE >= ADD_MONTHS(SYSDATE, -6);
    
    IF v_recent_apps >= 2 THEN
        RETURN 'INELIGIBLE - Too many recent applications: ' || 
               v_recent_apps || ' in last 6 months. Maximum: 1';
    END IF;
    
    -- 5. Check for pending applications
    SELECT COUNT(*) INTO v_pending_apps
    FROM APPLICATIONS 
    WHERE FARMER_ID = p_farmer_id
    AND SUBSIDY_TYPE_ID = p_subsidy_type_id
    AND STATUS = 'PENDING';
    
    IF v_pending_apps > 0 THEN
        RETURN 'INELIGIBLE - Has ' || v_pending_apps || ' pending application(s)';
    END IF;
    
    -- If all checks pass
    RETURN 'ELIGIBLE - ' || v_total_land_acres || ' acres land, qualifies for subsidy';
    
EXCEPTION
    WHEN OTHERS THEN
        -- Return error without crashing
        RETURN 'ERROR checking eligibility: ' || SQLERRM;
END CHECK_ELIGIBILITY;
/

--
CREATE OR REPLACE FUNCTION GENERATE_BANK_REFERENCE 
RETURN VARCHAR2 
IS
    v_ref VARCHAR2(50);
BEGIN
    -- Generate unique bank reference: BK + YYYYMMDD + sequence number
    SELECT 'BK' || TO_CHAR(SYSDATE, 'YYYYMMDD') || 
           '_' || LPAD(PAYMENT_SEQ.NEXTVAL, 6, '0')
    INTO v_ref
    FROM DUAL;
    
    RETURN v_ref;
    
EXCEPTION
    WHEN OTHERS THEN
        -- Return simple reference if sequence doesn't exist
        RETURN 'BK' || TO_CHAR(SYSDATE, 'YYYYMMDDHH24MISS') || '_' || DBMS_RANDOM.STRING('X', 6);
END GENERATE_BANK_REFERENCE;
/
