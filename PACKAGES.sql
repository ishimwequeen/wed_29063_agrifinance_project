CREATE OR REPLACE PACKAGE APPLICATION_MANAGEMENT AS
    
    PROCEDURE SUBMIT_APPLICATION(
        p_application_id IN NUMBER,
        p_farmer_id IN NUMBER,
        p_subsidy_type_id IN NUMBER,
        p_amount_requested IN NUMBER
    );
    
    PROCEDURE REVIEW_APPLICATION(
        p_application_id IN NUMBER,
        p_status IN VARCHAR2
    );
    
    FUNCTION CHECK_ELIGIBILITY(
        p_farmer_id IN NUMBER,
        p_subsidy_type_id IN NUMBER
    ) RETURN VARCHAR2;
    
    FUNCTION GET_PENDING_COUNT RETURN NUMBER;
    
END APPLICATION_MANAGEMENT;
/

CREATE OR REPLACE PACKAGE BODY APPLICATION_MANAGEMENT AS
    
    PROCEDURE SUBMIT_APPLICATION(
        p_application_id IN NUMBER,
        p_farmer_id IN NUMBER,
        p_subsidy_type_id IN NUMBER,
        p_amount_requested IN NUMBER
    ) IS
    BEGIN
        INSERT INTO APPLICATIONS (
            APPLICATION_ID, FARMER_ID, SUBSIDY_TYPE_ID,
            APPLICATION_DATE, AMOUNT_REQUESTED, STATUS
        ) VALUES (
            p_application_id, p_farmer_id, p_subsidy_type_id,
            SYSDATE, p_amount_requested, 'PENDING'
        );
        
        COMMIT;
        DBMS_OUTPUT.PUT_LINE('Application submitted. ID: ' || p_application_id);
        
    EXCEPTION
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE('Error: ' || SQLERRM);
            RAISE;
    END SUBMIT_APPLICATION;
    
    PROCEDURE REVIEW_APPLICATION(
        p_application_id IN NUMBER,
        p_status IN VARCHAR2
    ) IS
    BEGIN
        UPDATE APPLICATIONS 
        SET STATUS = p_status
        WHERE APPLICATION_ID = p_application_id;
        
        COMMIT;
        DBMS_OUTPUT.PUT_LINE('Application updated to: ' || p_status);
        
    EXCEPTION
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE('Error: ' || SQLERRM);
            RAISE;
    END REVIEW_APPLICATION;
    
    FUNCTION CHECK_ELIGIBILITY(
        p_farmer_id IN NUMBER,
        p_subsidy_type_id IN NUMBER
    ) RETURN VARCHAR2 IS
        v_land_count NUMBER;
    BEGIN
        -- Check if farmer has land
        SELECT COUNT(*) INTO v_land_count
        FROM LANDS 
        WHERE FARMER_ID = p_farmer_id;
        
        IF v_land_count = 0 THEN
            RETURN 'INELIGIBLE: No land registered';
        ELSE
            RETURN 'ELIGIBLE';
        END IF;
        
    EXCEPTION
        WHEN OTHERS THEN
            RETURN 'ERROR';
    END CHECK_ELIGIBILITY;
    
    FUNCTION GET_PENDING_COUNT RETURN NUMBER IS
        v_count NUMBER;
    BEGIN
        SELECT COUNT(*) INTO v_count
        FROM APPLICATIONS 
        WHERE STATUS = 'PENDING';
        
        RETURN v_count;
    END GET_PENDING_COUNT;
    
END APPLICATION_MANAGEMENT;
/

--
CREATE OR REPLACE PACKAGE FARMER_MANAGEMENT AS
    
    -- Procedures
    PROCEDURE REGISTER_FARMER(
        p_farmer_id IN NUMBER,
        p_first_name IN VARCHAR2,
        p_last_name IN VARCHAR2,
        p_phone IN VARCHAR2
    );
    
    PROCEDURE UPDATE_FARMER_BANK(
        p_farmer_id IN NUMBER,
        p_bank_account IN VARCHAR2,
        p_bank_id IN NUMBER
    );
    
    -- Functions
    FUNCTION GET_FARMER_INFO(p_farmer_id IN NUMBER) RETURN VARCHAR2;
    FUNCTION CHECK_PHONE(p_phone IN VARCHAR2) RETURN VARCHAR2;
    
END FARMER_MANAGEMENT;
/

CREATE OR REPLACE PACKAGE BODY FARMER_MANAGEMENT AS
    
    PROCEDURE REGISTER_FARMER(
        p_farmer_id IN NUMBER,
        p_first_name IN VARCHAR2,
        p_last_name IN VARCHAR2,
        p_phone IN VARCHAR2
    ) IS
    BEGIN
        INSERT INTO FARMERS (
            FARMER_ID, FIRST_NAME, LAST_NAME, PHONE, REGISTRATION_DATE
        ) VALUES (
            p_farmer_id, p_first_name, p_last_name, p_phone, SYSDATE
        );
        
        COMMIT;
        DBMS_OUTPUT.PUT_LINE('Farmer registered: ' || p_first_name || ' ' || p_last_name);
        
    EXCEPTION
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE('Error: ' || SQLERRM);
            RAISE;
    END REGISTER_FARMER;
    
    PROCEDURE UPDATE_FARMER_BANK(
        p_farmer_id IN NUMBER,
        p_bank_account IN VARCHAR2,
        p_bank_id IN NUMBER
    ) IS
    BEGIN
        UPDATE FARMERS 
        SET BANK_ACCOUNT_NUMBER = p_bank_account,
            BANK_ID = p_bank_id
        WHERE FARMER_ID = p_farmer_id;
        
        COMMIT;
        DBMS_OUTPUT.PUT_LINE('Bank info updated for farmer: ' || p_farmer_id);
        
    EXCEPTION
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE('Error: ' || SQLERRM);
            RAISE;
    END UPDATE_FARMER_BANK;
    
    FUNCTION GET_FARMER_INFO(p_farmer_id IN NUMBER) RETURN VARCHAR2 IS
        v_info VARCHAR2(200);
    BEGIN
        SELECT FIRST_NAME || ' ' || LAST_NAME || ' - Phone: ' || PHONE
        INTO v_info
        FROM FARMERS 
        WHERE FARMER_ID = p_farmer_id;
        
        RETURN v_info;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RETURN 'Farmer not found';
    END GET_FARMER_INFO;
    
    FUNCTION CHECK_PHONE(p_phone IN VARCHAR2) RETURN VARCHAR2 IS
    BEGIN
        IF p_phone LIKE '+250%' AND LENGTH(p_phone) = 13 THEN
            RETURN 'VALID';
        ELSE
            RETURN 'INVALID - Must be +250XXXXXXXXX';
        END IF;
    END CHECK_PHONE;
    
END FARMER_MANAGEMENT;
/

--
CREATE OR REPLACE PACKAGE REPORTING_PACKAGE AS
    
    FUNCTION GET_TOP_FARMERS RETURN SYS_REFCURSOR;
    
    FUNCTION GET_SYSTEM_STATS RETURN VARCHAR2;
    
    PROCEDURE SHOW_PENDING_APPLICATIONS;
    
END REPORTING_PACKAGE;
/

CREATE OR REPLACE PACKAGE BODY REPORTING_PACKAGE AS
    
    FUNCTION GET_TOP_FARMERS RETURN SYS_REFCURSOR IS
        v_cursor SYS_REFCURSOR;
    BEGIN
        OPEN v_cursor FOR
            SELECT 
                F.FARMER_ID,
                F.FIRST_NAME || ' ' || F.LAST_NAME AS FARMER_NAME,
                COUNT(A.APPLICATION_ID) AS TOTAL_APPLICATIONS,
                SUM(A.AMOUNT_REQUESTED) AS TOTAL_AMOUNT,
                -- WINDOW FUNCTIONS
                RANK() OVER (ORDER BY SUM(A.AMOUNT_REQUESTED) DESC) AS RANK_BY_AMOUNT,
                ROW_NUMBER() OVER (ORDER BY COUNT(A.APPLICATION_ID) DESC) AS RANK_BY_COUNT
            FROM FARMERS F
            LEFT JOIN APPLICATIONS A ON F.FARMER_ID = A.FARMER_ID
            WHERE A.STATUS IN ('APPROVED', 'PAID')
            GROUP BY F.FARMER_ID, F.FIRST_NAME, F.LAST_NAME
            ORDER BY TOTAL_AMOUNT DESC NULLS LAST;
        
        RETURN v_cursor;
    END GET_TOP_FARMERS;
    
    FUNCTION GET_SYSTEM_STATS RETURN VARCHAR2 IS
        v_farmers NUMBER;
        v_applications NUMBER;
        v_pending NUMBER;
    BEGIN
        SELECT COUNT(*) INTO v_farmers FROM FARMERS;
        SELECT COUNT(*) INTO v_applications FROM APPLICATIONS;
        SELECT COUNT(*) INTO v_pending FROM APPLICATIONS WHERE STATUS = 'PENDING';
        
        RETURN 'Farmers: ' || v_farmers || 
               ' | Applications: ' || v_applications || 
               ' | Pending: ' || v_pending;
    END GET_SYSTEM_STATS;
    
    PROCEDURE SHOW_PENDING_APPLICATIONS IS
        CURSOR c_pending IS
            SELECT A.APPLICATION_ID, F.FIRST_NAME || ' ' || F.LAST_NAME AS FARMER_NAME,
                   A.AMOUNT_REQUESTED, A.APPLICATION_DATE
            FROM APPLICATIONS A
            JOIN FARMERS F ON A.FARMER_ID = F.FARMER_ID
            WHERE A.STATUS = 'PENDING'
            ORDER BY A.APPLICATION_DATE;
    BEGIN
        DBMS_OUTPUT.PUT_LINE('=== PENDING APPLICATIONS ===');
        FOR rec IN c_pending LOOP
            DBMS_OUTPUT.PUT_LINE(
                'ID: ' || rec.APPLICATION_ID || 
                ' | Farmer: ' || rec.FARMER_NAME ||
                ' | Amount: ' || rec.AMOUNT_REQUESTED ||
                ' | Date: ' || TO_CHAR(rec.APPLICATION_DATE, 'DD-MON-YY')
            );
        END LOOP;
    END SHOW_PENDING_APPLICATIONS;
    
END REPORTING_PACKAGE;
/
