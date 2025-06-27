-- SPCS Restricted Callers Rights Lab - Security Setup
-- This script configures caller grants and security policies

USE ROLE ACCOUNTADMIN;
USE DATABASE SPCS_RESTRICTED_DEMO;
USE SCHEMA FINANCIAL_DATA;

-- Step 1: Set up caller grants for the PLATFORM_OWNER role
-- These grants define what user privileges the SPCS service can use

-- Allow service to use SELECT privilege on behalf of callers
GRANT CALLER SELECT ON TABLE client_transactions TO ROLE PLATFORM_OWNER;
GRANT CALLER SELECT ON TABLE account_details TO ROLE PLATFORM_OWNER;
GRANT CALLER SELECT ON VIEW client_summary TO ROLE PLATFORM_OWNER;

-- Allow service to use warehouse on behalf of callers  
GRANT CALLER USAGE ON WAREHOUSE SPCS_LAB_WH TO ROLE PLATFORM_OWNER;

-- Allow service to use database/schema on behalf of callers
GRANT CALLER USAGE ON DATABASE SPCS_RESTRICTED_DEMO TO ROLE PLATFORM_OWNER;
GRANT CALLER USAGE ON SCHEMA FINANCIAL_DATA TO ROLE PLATFORM_OWNER;

-- Step 2: Create row access policies for multi-tenant isolation
-- These policies ensure users can only see their own client's data

-- Row access policy for client_transactions
CREATE ROW ACCESS POLICY client_transactions_policy AS (
    client_id = CASE 
        WHEN CURRENT_ROLE() = 'CLIENT_A_ANALYST' THEN 'CLIENT_A'
        WHEN CURRENT_ROLE() = 'CLIENT_B_ANALYST' THEN 'CLIENT_B'
        WHEN CURRENT_ROLE() = 'PLATFORM_OWNER' THEN client_id  -- Platform owner can see all
        ELSE 'NO_ACCESS'  -- Default deny
    END
) COMMENT = 'Row access policy for multi-tenant transaction data';

-- Apply the policy to the transactions table
ALTER TABLE client_transactions ADD ROW ACCESS POLICY client_transactions_policy ON (client_id);

-- Row access policy for account_details
CREATE ROW ACCESS POLICY account_details_policy AS (
    client_id = CASE 
        WHEN CURRENT_ROLE() = 'CLIENT_A_ANALYST' THEN 'CLIENT_A'
        WHEN CURRENT_ROLE() = 'CLIENT_B_ANALYST' THEN 'CLIENT_B'
        WHEN CURRENT_ROLE() = 'PLATFORM_OWNER' THEN client_id  -- Platform owner can see all
        ELSE 'NO_ACCESS'  -- Default deny
    END
) COMMENT = 'Row access policy for multi-tenant account data';

-- Apply the policy to the account details table
ALTER TABLE account_details ADD ROW ACCESS POLICY account_details_policy ON (client_id);

-- Step 3: Create dynamic data masking policies for sensitive data
-- These policies mask sensitive account information

CREATE MASKING POLICY account_mask_policy AS (account_id STRING) RETURNS STRING ->
    CASE 
        WHEN CURRENT_ROLE() IN ('CLIENT_A_ANALYST') AND account_id LIKE 'ACC_A_%' THEN account_id
        WHEN CURRENT_ROLE() IN ('CLIENT_B_ANALYST') AND account_id LIKE 'ACC_B_%' THEN account_id
        WHEN CURRENT_ROLE() = 'PLATFORM_OWNER' THEN account_id  -- Platform owner sees all
        ELSE 'XXX-MASKED'  -- Mask for unauthorized access
    END
COMMENT = 'Masking policy for account IDs';

-- Apply masking policy to account_id columns
ALTER TABLE client_transactions MODIFY COLUMN account_id SET MASKING POLICY account_mask_policy;
ALTER TABLE account_details MODIFY COLUMN account_id SET MASKING POLICY account_mask_policy;

-- Step 4: Grant data access privileges to client roles
-- Client A access
GRANT SELECT ON TABLE client_transactions TO ROLE CLIENT_A_ANALYST;
GRANT SELECT ON TABLE account_details TO ROLE CLIENT_A_ANALYST;
GRANT SELECT ON VIEW client_summary TO ROLE CLIENT_A_ANALYST;

-- Client B access
GRANT SELECT ON TABLE client_transactions TO ROLE CLIENT_B_ANALYST;
GRANT SELECT ON TABLE account_details TO ROLE CLIENT_B_ANALYST;
GRANT SELECT ON VIEW client_summary TO ROLE CLIENT_B_ANALYST;

-- Platform Owner gets full access
GRANT ALL PRIVILEGES ON TABLE client_transactions TO ROLE PLATFORM_OWNER;
GRANT ALL PRIVILEGES ON TABLE account_details TO ROLE PLATFORM_OWNER;
GRANT ALL PRIVILEGES ON VIEW client_summary TO ROLE PLATFORM_OWNER;

-- Step 5: Test the security configuration
-- Test as Client A analyst
USE ROLE CLIENT_A_ANALYST;
SELECT 'CLIENT_A access test' as test_name, COUNT(*) as accessible_records
FROM client_transactions;

-- This should only show Client A data
SELECT client_id, COUNT(*) as transaction_count
FROM client_transactions 
GROUP BY client_id;

-- Test as Client B analyst
USE ROLE CLIENT_B_ANALYST;
SELECT 'CLIENT_B access test' as test_name, COUNT(*) as accessible_records
FROM client_transactions;

-- This should only show Client B data
SELECT client_id, COUNT(*) as transaction_count
FROM client_transactions 
GROUP BY client_id;

-- Test as Platform Owner (should see all data)
USE ROLE PLATFORM_OWNER;
SELECT 'PLATFORM_OWNER access test' as test_name, COUNT(*) as accessible_records
FROM client_transactions;

-- This should show all client data
SELECT client_id, COUNT(*) as transaction_count
FROM client_transactions 
GROUP BY client_id;

-- Step 6: Create monitoring views for security validation
CREATE OR REPLACE VIEW security_audit_log AS
SELECT 
    query_id,
    query_text,
    user_name,
    role_name,
    start_time,
    end_time,
    execution_status,
    rows_produced,
    warehouse_name
FROM snowflake.account_usage.query_history
WHERE query_text ILIKE '%client_transactions%'
   OR query_text ILIKE '%account_details%'
ORDER BY start_time DESC;

-- Step 7: Verify caller grants are properly configured
SHOW CALLER GRANTS TO ROLE PLATFORM_OWNER;

-- Step 8: Create test procedure to validate restricted caller's rights
CREATE OR REPLACE PROCEDURE test_caller_grants()
RETURNS STRING
LANGUAGE JAVASCRIPT
EXECUTE AS CALLER  -- This uses caller's rights (not restricted)
AS
$$
try {
    var result = snowflake.execute({sqlText: "SELECT COUNT(*) as count FROM client_transactions"});
    result.next();
    var count = result.getColumnValue(1);
    return "Caller can access " + count + " transactions";
} catch (err) {
    return "Access denied: " + err.message;
}
$$;

-- Test the procedure with different roles
USE ROLE CLIENT_A_ANALYST;
CALL test_caller_grants();

USE ROLE CLIENT_B_ANALYST;
CALL test_caller_grants();

USE ROLE PLATFORM_OWNER;
CALL test_caller_grants();

-- Summary of security configuration
SELECT 'Security Configuration Summary' as summary_type;
SELECT 'Row Access Policies' as policy_type, COUNT(*) as count FROM information_schema.row_access_policies;
SELECT 'Masking Policies' as policy_type, COUNT(*) as count FROM information_schema.masking_policies;
SELECT 'Client Roles Created' as policy_type, 3 as count;
SELECT 'Caller Grants Configured' as policy_type, 
       (SELECT COUNT(*) FROM information_schema.grants WHERE grantee_name = 'PLATFORM_OWNER' AND granted_on = 'CALLER_GRANT') as count; 