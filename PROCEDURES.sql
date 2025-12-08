CREATE OR REPLACE PROCEDURE ADD_SUBSIDY_TYPE(
    p_type_id IN SUBSIDY_TYPES.TYPE_ID%TYPE,
    p_type_name IN SUBSIDY_TYPES.TYPE_NAME%TYPE,
    p_description IN SUBSIDY_TYPES.DESCRIPTION%TYPE,
    p_max_amount IN SUBSIDY_TYPES.MAX_AMOUNT%TYPE,
    p_unit IN SUBSIDY_TYPES.UNIT%TYPE,
    p_supplier_id IN SUBSIDY_TYPES.SUPPLIER_ID%TYPE
) IS
    v_count NUMBER;
BEGIN
    -- Basic validation
    IF p_type_name IS NULL THEN
        RAISE_APPLICATION_ERROR(-20001, 'Type name cannot be null');
    END IF;
    
    IF p_supplier_id IS NULL THEN
        RAISE_APPLICATION_ERROR(-20002, 'Supplier ID cannot be null');
    END IF;
    
    IF p_max_amount IS NULL OR p_max_amount <= 0 THEN
        RAISE_APPLICATION_ERROR(-20003, 'Maximum amount must be positive');
    END IF;
    
    -- Check for duplicate type name
    SELECT COUNT(*) INTO v_count
    FROM SUBSIDY_TYPES 
    WHERE UPPER(TYPE_NAME) = UPPER(p_type_name);
    
    IF v_count > 0 THEN
        RAISE_APPLICATION_ERROR(-20004, 'Subsidy type name already exists: ' || p_type_name);
    END IF;
    
    -- Check if supplier exists
    SELECT COUNT(*) INTO v_count 
    FROM SUPPLIERS 
    WHERE SUPPLIER_ID = p_supplier_id;
    
    IF v_count = 0 THEN
        RAISE_APPLICATION_ERROR(-20005, 'Supplier not found: ' || p_supplier_id);
    END IF;
    
    -- Insert the record
    INSERT INTO SUBSIDY_TYPES (
        TYPE_ID,
        TYPE_NAME,
        DESCRIPTION,
        MAX_AMOUNT,
        UNIT,
        SUPPLIER_ID
    ) VALUES (
        p_type_id,
        p_type_name,
        p_description,
        p_max_amount,
        p_unit,
        p_supplier_id
    );
    
    COMMIT;
    DBMS_OUTPUT.PUT_LINE('Subsidy type added successfully: ' || p_type_name);
    
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        DBMS_OUTPUT.PUT_LINE('Error: ' || SQLERRM);
        RAISE;
END ADD_SUBSIDY_TYPE;
/

CREATE OR REPLACE PROCEDURE ADD_FARMER(
    p_farmer_id IN NUMBER,
    p_first_name IN VARCHAR2,
    p_last_name IN VARCHAR2,
    p_id_number IN VARCHAR2,
    p_phone IN VARCHAR2,
    p_farm_size IN NUMBER,
    p_location IN VARCHAR2,
    p_bank_account IN VARCHAR2 DEFAULT NULL,
    p_bank_id IN NUMBER DEFAULT NULL
) IS
    v_error_msg VARCHAR2(500);
    v_customer_msg VARCHAR2(1000);
    v_message_id NUMBER;
BEGIN
    -- Validate phone format
    IF p_phone IS NOT NULL AND NOT p_phone LIKE '+250%' THEN
        v_error_msg := 'Phone number must start with +250 (Rwanda format). Provided: ' || p_phone;
        v_customer_msg := 'Dear ' || p_first_name || ', your phone number format is incorrect. ' ||
                         'Please use Rwandan format: +250XXXXXXXXX';
        
        -- Log message for customer
        INSERT INTO CUSTOMER_MESSAGES (
            MESSAGE_ID, FARMER_ID, MESSAGE_TYPE, 
            MESSAGE_TEXT, PHONE_NUMBER, STATUS
        ) VALUES (
            MESSAGE_SEQ.NEXTVAL, p_farmer_id, 'ERROR',
            v_customer_msg, p_phone, 'PENDING'
        );
        
        COMMIT;
        RAISE_APPLICATION_ERROR(-20001, v_error_msg);
    END IF;
    
    -- Validate farm size
    IF p_farm_size <= 0 THEN
        v_error_msg := 'Farm size must be greater than 0. Provided: ' || p_farm_size;
        v_customer_msg := 'Dear ' || p_first_name || ', farm size must be greater than 0 acres. ' ||
                         'Please provide a valid farm size.';
        
        INSERT INTO CUSTOMER_MESSAGES VALUES (
            MESSAGE_SEQ.NEXTVAL, p_farmer_id, 'ERROR',
            v_customer_msg, p_phone, 'PENDING', SYSTIMESTAMP, NULL
        );
        
        COMMIT;
        RAISE_APPLICATION_ERROR(-20002, v_error_msg);
    END IF;
    
    -- Validate required fields
    IF p_first_name IS NULL OR p_last_name IS NULL OR p_id_number IS NULL OR p_location IS NULL THEN
        v_error_msg := 'First name, last name, ID number, and location are required fields.';
        v_customer_msg := 'Dear applicant, please fill all required fields: ' ||
                         'First name, Last name, ID number, and Location.';
        
        INSERT INTO CUSTOMER_MESSAGES VALUES (
            MESSAGE_SEQ.NEXTVAL, NULL, 'ERROR',  -- No farmer_id yet
            v_customer_msg, p_phone, 'PENDING', SYSTIMESTAMP, NULL
        );
        
        COMMIT;
        RAISE_APPLICATION_ERROR(-20003, v_error_msg);
    END IF;
    
    -- Insert the farmer
    INSERT INTO FARMERS (
        FARMER_ID, FIRST_NAME, LAST_NAME, ID_NUMBER, PHONE,
        FARM_SIZE_ACRES, LOCATION, BANK_ACCOUNT_NUMBER, BANK_ID, REGISTRATION_DATE
    ) VALUES (
        p_farmer_id, p_first_name, p_last_name, p_id_number, p_phone,
        p_farm_size, p_location, p_bank_account, p_bank_id, SYSDATE
    );
    
    -- Success message
    v_customer_msg := 'Dear ' || p_first_name || ' ' || p_last_name || 
                     ', you have been successfully registered!' ||
                     ' Farmer ID: ' || p_farmer_id ||
                     '. You can now apply for subsidies.';
    
    INSERT INTO CUSTOMER_MESSAGES VALUES (
        MESSAGE_SEQ.NEXTVAL, p_farmer_id, 'SUCCESS',
        v_customer_msg, p_phone, 'PENDING', SYSTIMESTAMP, NULL
    );
    
    COMMIT;
    
    DBMS_OUTPUT.PUT_LINE('Farmer added successfully: ' || p_first_name || ' ' || p_last_name);
    DBMS_OUTPUT.PUT_LINE('Success message logged for customer.');
    
EXCEPTION
    WHEN DUP_VAL_ON_INDEX THEN
        ROLLBACK;
        v_error_msg := 'ID number already exists: ' || p_id_number;
        v_customer_msg := 'Dear ' || p_first_name || ', this ID number is already registered. ' ||
                         'Please use a different ID or contact support.';
        
        INSERT INTO CUSTOMER_MESSAGES VALUES (
            MESSAGE_SEQ.NEXTVAL, p_farmer_id, 'ERROR',
            v_customer_msg, p_phone, 'PENDING', SYSTIMESTAMP, NULL
        );
        
        COMMIT;
        RAISE_APPLICATION_ERROR(-20004, v_error_msg);
        
    WHEN OTHERS THEN
        ROLLBACK;
        v_customer_msg := 'Dear ' || p_first_name || ', registration failed. ' ||
                         'Please try again or contact support. Error: REG-' || ABS(SQLCODE);
        
        INSERT INTO CUSTOMER_MESSAGES VALUES (
            MESSAGE_SEQ.NEXTVAL, p_farmer_id, 'ERROR',
            v_customer_msg, p_phone, 'PENDING', SYSTIMESTAMP, NULL
        );
        
        COMMIT;
        DBMS_OUTPUT.PUT_LINE('Customer message logged. System error: ' || SQLERRM);
        RAISE;
END ADD_FARMER;
/

CREATE OR REPLACE PROCEDURE SUBMIT_APPLICATION(
    p_application_id IN NUMBER,
    p_farmer_id IN NUMBER,
    p_land_id IN NUMBER,  -- Added this required parameter
    p_subsidy_type_id IN NUMBER,
    p_amount_requested IN NUMBER,
    p_preferred_bank_id IN NUMBER DEFAULT NULL,
    p_notes IN VARCHAR2 DEFAULT NULL
) IS
    v_error_msg VARCHAR2(500);
BEGIN
    -- Insert application with all required columns
    INSERT INTO APPLICATIONS (
        APPLICATION_ID,
        FARMER_ID,
        LAND_ID,  -- Required column
        SUBSIDY_TYPE_ID,
        APPLICATION_DATE,
        AMOUNT_REQUESTED,
        PREFERRED_BANK_ID,
        STATUS
    ) VALUES (
        p_application_id,
        p_farmer_id,
        p_land_id,  -- Required value
        p_subsidy_type_id,
        SYSDATE,
        p_amount_requested,
        p_preferred_bank_id,
        'PENDING'
    );
    
    -- Log success message to CUSTOMER_MESSAGES
    v_error_msg := 'Application submitted successfully. ID: ' || p_application_id;
    INSERT INTO CUSTOMER_MESSAGES (
        MESSAGE_ID,
        FARMER_ID,  -- Required column
        MESSAGE_TYPE,
        MESSAGE_TEXT,
        STATUS,
        CREATED_DATE
    ) VALUES (
        MESSAGE_SEQ.NEXTVAL,
        p_farmer_id,  -- Link message to farmer
        'SUCCESS',
        v_error_msg,
        'SENT',  -- Status for success messages
        SYSTIMESTAMP
    );
    
    COMMIT;
    DBMS_OUTPUT.PUT_LINE(v_error_msg);
    
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        v_error_msg := 'Error submitting application: ' || SQLERRM;
        
        -- Log error to CUSTOMER_MESSAGES
        INSERT INTO CUSTOMER_MESSAGES (
            MESSAGE_ID,
            FARMER_ID,
            MESSAGE_TYPE,
            MESSAGE_TEXT,
            STATUS,
            CREATED_DATE
        ) VALUES (
            MESSAGE_SEQ.NEXTVAL,
            p_farmer_id,
            'ERROR',
            v_error_msg,
            'FAILED',  -- Status for error messages
            SYSTIMESTAMP
        );
        COMMIT;
        
        DBMS_OUTPUT.PUT_LINE(v_error_msg);
        RAISE;
END SUBMIT_APPLICATION;
/
