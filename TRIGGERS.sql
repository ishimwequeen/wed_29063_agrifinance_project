CREATE OR REPLACE TRIGGER CHECK_REPEAT_ERRORS
AFTER INSERT ON CUSTOMER_MESSAGES
FOR EACH ROW
DECLARE
    v_error_count NUMBER;
    v_user_errors NUMBER;
    v_alert_message VARCHAR2(500);
BEGIN
    -- Only process ERROR type messages
    IF :NEW.MESSAGE_TYPE != 'ERROR' THEN
        RETURN;
    END IF;
    
    -- Debug: Show what we're processing
    DBMS_OUTPUT.PUT_LINE('Processing error for Farmer ID: ' || :NEW.FARMER_ID);
    
    -- Count errors by this farmer in the last 24 hours
    SELECT COUNT(*) 
    INTO v_error_count
    FROM CUSTOMER_MESSAGES
    WHERE FARMER_ID = :NEW.FARMER_ID
    AND MESSAGE_TYPE = 'ERROR'
    AND CREATED_DATE >= SYSTIMESTAMP - INTERVAL '24' HOUR;
    
    -- Count total errors by this farmer
    SELECT COUNT(*)
    INTO v_user_errors
    FROM CUSTOMER_MESSAGES
    WHERE FARMER_ID = :NEW.FARMER_ID
    AND MESSAGE_TYPE = 'ERROR';
    
    -- Debug: Show counts
    DBMS_OUTPUT.PUT_LINE('24-hour error count: ' || v_error_count || ', Total errors: ' || v_user_errors);
    
    -- Check if this is the 3rd error
    IF v_error_count = 3 THEN
        -- Create alert for 3 errors in 24 hours
        v_alert_message := 'Farmer ID: ' || :NEW.FARMER_ID || 
                          ' has made 3 errors in the last 24 hours. ' ||
                          'Latest error: ' || SUBSTR(:NEW.MESSAGE_TEXT, 1, 100);
        
        INSERT INTO REPEAT_ERROR_ALERTS (
            ALERT_ID, USER_NAME, ERROR_TYPE, ERROR_COUNT,
            FIRST_OCCURRENCE, LAST_OCCURRENCE, ALERT_DATE
        ) VALUES (
            ALERT_SEQ.NEXTVAL, 'Farmer_' || :NEW.FARMER_ID, 'HOURLY_THRESHOLD', v_error_count,
            SYSTIMESTAMP - INTERVAL '24' HOUR, SYSTIMESTAMP, SYSDATE
        );
        
        DBMS_OUTPUT.PUT_LINE('ALERT: ' || v_alert_message);
        
    ELSIF v_user_errors = 3 THEN
        -- Create alert for 3rd total error
        v_alert_message := 'Farmer ID: ' || :NEW.FARMER_ID || 
                          ' has made their 3rd total error. ' ||
                          'Latest error: ' || SUBSTR(:NEW.MESSAGE_TEXT, 1, 100);
        
        INSERT INTO REPEAT_ERROR_ALERTS (
            ALERT_ID, USER_NAME, ERROR_TYPE, ERROR_COUNT,
            FIRST_OCCURRENCE, LAST_OCCURRENCE, ALERT_DATE
        ) VALUES (
            ALERT_SEQ.NEXTVAL, 'Farmer_' || :NEW.FARMER_ID, 'TOTAL_THRESHOLD', v_user_errors,
            (SELECT MIN(CREATED_DATE) FROM CUSTOMER_MESSAGES 
             WHERE FARMER_ID = :NEW.FARMER_ID AND MESSAGE_TYPE = 'ERROR'),
            SYSTIMESTAMP, SYSDATE
        );
        
        DBMS_OUTPUT.PUT_LINE('ALERT: ' || v_alert_message);
    END IF;
    
EXCEPTION
    WHEN OTHERS THEN
        -- Don't let trigger error stop the insert
        DBMS_OUTPUT.PUT_LINE('Trigger error: ' || SQLERRM);
        DBMS_OUTPUT.PUT_LINE('Error code: ' || SQLCODE);
END;
/
