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
--
CREATE OR REPLACE FUNCTION GET_APPLICATION_RANKINGS
RETURN SYS_REFCURSOR
IS
    v_cursor SYS_REFCURSOR;
BEGIN
    OPEN v_cursor FOR
        WITH application_stats AS (
            SELECT 
                FARMER_ID,
                COUNT(*) AS APPLICATION_COUNT,
                SUM(AMOUNT_REQUESTED) AS TOTAL_AMOUNT,
                AVG(AMOUNT_REQUESTED) AS AVERAGE_AMOUNT
            FROM APPLICATIONS
            WHERE STATUS IN ('APPROVED', 'PAID')
            GROUP BY FARMER_ID
        )
        SELECT 
            F.FARMER_ID,
            F.FIRST_NAME || ' ' || F.LAST_NAME AS FARMER_NAME,
            S.APPLICATION_COUNT,
            S.TOTAL_AMOUNT,
            S.AVERAGE_AMOUNT,
            
            -- 1. RANK(): Ranking with gaps for ties
            RANK() OVER (ORDER BY S.TOTAL_AMOUNT DESC) AS AMOUNT_RANK,
            
            -- 2. DENSE_RANK(): Ranking without gaps
            DENSE_RANK() OVER (ORDER BY S.APPLICATION_COUNT DESC) AS COUNT_RANK,
            
            -- 3. ROW_NUMBER(): Unique sequential numbers
            ROW_NUMBER() OVER (ORDER BY S.TOTAL_AMOUNT DESC) AS ROW_NUM,
            
            -- 4. PERCENT_RANK(): Relative position (0-1)
            ROUND(PERCENT_RANK() OVER (ORDER BY S.TOTAL_AMOUNT DESC), 3) AS PERCENTILE,
            
            -- 5. NTILE(4): Divide into quartiles
            NTILE(4) OVER (ORDER BY S.TOTAL_AMOUNT DESC) AS QUARTILE,
            
            -- 6. LAG(): Previous farmer's amount
            LAG(S.TOTAL_AMOUNT) OVER (ORDER BY S.TOTAL_AMOUNT DESC) AS PREV_AMOUNT,
            
            -- 7. LEAD(): Next farmer's amount
            LEAD(S.TOTAL_AMOUNT) OVER (ORDER BY S.TOTAL_AMOUNT DESC) AS NEXT_AMOUNT,
            
            -- 8. Difference from previous (using LAG)
            S.TOTAL_AMOUNT - LAG(S.TOTAL_AMOUNT) OVER (ORDER BY S.TOTAL_AMOUNT DESC) 
                AS AMOUNT_DIFF_FROM_PREV
            
        FROM application_stats S
        JOIN FARMERS F ON S.FARMER_ID = F.FARMER_ID
        ORDER BY S.TOTAL_AMOUNT DESC;
    
    RETURN v_cursor;
END GET_APPLICATION_RANKINGS;
/
--
CREATE OR REPLACE FUNCTION IS_DATE_HOLIDAY(
    p_check_date IN DATE
) RETURN VARCHAR2 IS
    v_holiday_name VARCHAR2(100);
    v_result VARCHAR2(150);
BEGIN
    -- Check if the date is a holiday
    BEGIN
        SELECT HOLIDAY_NAME
        INTO v_holiday_name
        FROM PUBLIC_HOLIDAYS
        WHERE TRUNC(HOLIDAY_DATE) = TRUNC(p_check_date)
        AND ROWNUM = 1;
        
        v_result := 'Y:' || v_holiday_name;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            v_result := 'N';
        WHEN TOO_MANY_ROWS THEN
            SELECT HOLIDAY_NAME
            INTO v_holiday_name
            FROM PUBLIC_HOLIDAYS
            WHERE TRUNC(HOLIDAY_DATE) = TRUNC(p_check_date)
            AND ROWNUM = 1;
            v_result := 'Y:' || v_holiday_name;
    END;
    
    RETURN v_result;
EXCEPTION
    WHEN OTHERS THEN
        RETURN 'ERROR:' || SQLERRM;
END IS_DATE_HOLIDAY;
/
