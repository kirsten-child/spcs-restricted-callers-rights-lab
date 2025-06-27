-- DORA Automated Grading Script for SPCS Restricted Callers Rights Lab
-- This script validates SE lab completion and provides scoring
-- Execute this script as ACCOUNTADMIN to grade the lab

USE ROLE ACCOUNTADMIN;

-- Create grading schema if it doesn't exist
CREATE SCHEMA IF NOT EXISTS SPCS_RESTRICTED_DEMO.GRADING;
USE SCHEMA SPCS_RESTRICTED_DEMO.GRADING;

-- Create grading results table
CREATE OR REPLACE TABLE lab_grading_results (
    student_id STRING,
    test_category STRING,
    test_name STRING,
    points_possible INTEGER,
    points_earned INTEGER,
    status STRING,
    error_message STRING,
    graded_timestamp TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

-- Create grading procedure
CREATE OR REPLACE PROCEDURE grade_spcs_lab(student_id STRING)
RETURNS STRING
LANGUAGE JAVASCRIPT
AS
$$
var results = [];
var totalPoints = 0;
var earnedPoints = 0;

function addResult(category, testName, possible, earned, status, error) {
    results.push({
        category: category,
        testName: testName,
        possible: possible,
        earned: earned,
        status: status,
        error: error || ''
    });
    totalPoints += possible;
    earnedPoints += earned;
}

function executeTest(testSql, testName, category, points) {
    try {
        var result = snowflake.execute({sqlText: testSql});
        if (result.next()) {
            var value = result.getColumnValue(1);
            if (value === true || value > 0) {
                addResult(category, testName, points, points, 'PASS', '');
                return true;
            }
        }
        addResult(category, testName, points, 0, 'FAIL', 'Test condition not met');
        return false;
    } catch (err) {
        addResult(category, testName, points, 0, 'ERROR', err.message);
        return false;
    }
}

// Test 1: Basic Infrastructure Setup (20 points)
executeTest(
    "SELECT COUNT(*) > 0 FROM information_schema.warehouses WHERE warehouse_name = 'SPCS_LAB_WH'",
    "Warehouse Created", "Infrastructure", 3
);

executeTest(
    "SELECT COUNT(*) > 0 FROM information_schema.databases WHERE database_name = 'SPCS_RESTRICTED_DEMO'",
    "Database Created", "Infrastructure", 3
);

executeTest(
    "SELECT COUNT(*) > 0 FROM information_schema.schemata WHERE schema_name = 'FINANCIAL_DATA'",
    "Schema Created", "Infrastructure", 2
);

executeTest(
    "SELECT COUNT(*) > 0 FROM information_schema.compute_pools WHERE compute_pool_name = 'SPCS_RESTRICTED_POOL'",
    "Compute Pool Created", "Infrastructure", 5
);

executeTest(
    "SELECT COUNT(*) >= 3 FROM information_schema.applicable_roles WHERE role_name IN ('CLIENT_A_ANALYST', 'CLIENT_B_ANALYST', 'PLATFORM_OWNER')",
    "Roles Created", "Infrastructure", 7
);

// Test 2: Data Setup (15 points)
executeTest(
    "SELECT COUNT(*) > 20 FROM SPCS_RESTRICTED_DEMO.FINANCIAL_DATA.client_transactions",
    "Transaction Data Loaded", "Data Setup", 5
);

executeTest(
    "SELECT COUNT(*) >= 6 FROM SPCS_RESTRICTED_DEMO.FINANCIAL_DATA.account_details",
    "Account Details Loaded", "Data Setup", 3
);

executeTest(
    "SELECT COUNT(DISTINCT client_id) = 2 FROM SPCS_RESTRICTED_DEMO.FINANCIAL_DATA.client_transactions",
    "Multi-tenant Data Structure", "Data Setup", 4
);

executeTest(
    "SELECT COUNT(*) > 0 FROM information_schema.views WHERE table_name = 'CLIENT_SUMMARY'",
    "Summary View Created", "Data Setup", 3
);

// Test 3: Security Configuration (25 points)
executeTest(
    "SELECT COUNT(*) >= 3 FROM information_schema.grants WHERE grantee_name = 'PLATFORM_OWNER' AND privilege_type = 'CALLER USAGE'",
    "Caller Grants Configured", "Security", 8
);

executeTest(
    "SELECT COUNT(*) >= 2 FROM information_schema.row_access_policies",
    "Row Access Policies Created", "Security", 6
);

executeTest(
    "SELECT COUNT(*) >= 1 FROM information_schema.masking_policies",
    "Masking Policies Created", "Security", 5
);

executeTest(
    "SELECT COUNT(*) >= 2 FROM information_schema.table_privileges WHERE table_name = 'CLIENT_TRANSACTIONS' AND grantee_name IN ('CLIENT_A_ANALYST', 'CLIENT_B_ANALYST')",
    "Client Role Permissions", "Security", 6
);

// Test 4: Container Service Configuration (20 points)
try {
    var serviceCheck = snowflake.execute({
        sqlText: "SHOW SERVICES LIKE 'analytics_service'"
    });
    
    if (serviceCheck.next()) {
        addResult("Container Service", "SPCS Service Created", 10, 10, "PASS", "");
        
        // Check service specification
        var specCheck = snowflake.execute({
            sqlText: "DESCRIBE SERVICE analytics_service"
        });
        
        var hasCallerRights = false;
        while (specCheck.next()) {
            var specJson = specCheck.getColumnValue(2);
            if (specJson && specJson.includes('executeAsCaller')) {
                hasCallerRights = true;
                break;
            }
        }
        
        if (hasCallerRights) {
            addResult("Container Service", "Caller Rights Enabled", 10, 10, "PASS", "");
        } else {
            addResult("Container Service", "Caller Rights Enabled", 10, 0, "FAIL", "executeAsCaller not found in service spec");
        }
    } else {
        addResult("Container Service", "SPCS Service Created", 10, 0, "FAIL", "Service not found");
        addResult("Container Service", "Caller Rights Enabled", 10, 0, "FAIL", "Service not found");
    }
} catch (err) {
    addResult("Container Service", "SPCS Service Created", 10, 0, "ERROR", err.message);
    addResult("Container Service", "Caller Rights Enabled", 10, 0, "ERROR", "Cannot check service spec");
}

// Test 5: Multi-tenant Data Isolation Testing (15 points)
// Test Client A isolation
try {
    snowflake.execute({sqlText: "USE ROLE CLIENT_A_ANALYST"});
    var clientATest = snowflake.execute({
        sqlText: "SELECT COUNT(DISTINCT client_id) FROM SPCS_RESTRICTED_DEMO.FINANCIAL_DATA.client_transactions"
    });
    
    if (clientATest.next() && clientATest.getColumnValue(1) === 1) {
        addResult("Data Isolation", "Client A Data Isolation", 5, 5, "PASS", "");
    } else {
        addResult("Data Isolation", "Client A Data Isolation", 5, 0, "FAIL", "Client A can see multiple client data");
    }
} catch (err) {
    addResult("Data Isolation", "Client A Data Isolation", 5, 0, "ERROR", err.message);
}

// Test Client B isolation
try {
    snowflake.execute({sqlText: "USE ROLE CLIENT_B_ANALYST"});
    var clientBTest = snowflake.execute({
        sqlText: "SELECT COUNT(DISTINCT client_id) FROM SPCS_RESTRICTED_DEMO.FINANCIAL_DATA.client_transactions"
    });
    
    if (clientBTest.next() && clientBTest.getColumnValue(1) === 1) {
        addResult("Data Isolation", "Client B Data Isolation", 5, 5, "PASS", "");
    } else {
        addResult("Data Isolation", "Client B Data Isolation", 5, 0, "FAIL", "Client B can see multiple client data");
    }
} catch (err) {
    addResult("Data Isolation", "Client B Data Isolation", 5, 0, "ERROR", err.message);
}

// Test Platform Owner access
try {
    snowflake.execute({sqlText: "USE ROLE PLATFORM_OWNER"});
    var platformTest = snowflake.execute({
        sqlText: "SELECT COUNT(DISTINCT client_id) FROM SPCS_RESTRICTED_DEMO.FINANCIAL_DATA.client_transactions"
    });
    
    if (platformTest.next() && platformTest.getColumnValue(1) === 2) {
        addResult("Data Isolation", "Platform Owner Full Access", 5, 5, "PASS", "");
    } else {
        addResult("Data Isolation", "Platform Owner Full Access", 5, 0, "FAIL", "Platform owner cannot see all client data");
    }
} catch (err) {
    addResult("Data Isolation", "Platform Owner Full Access", 5, 0, "ERROR", err.message);
}

// Test 6: Business Understanding (5 points)
// Check if monitoring views were created (indicates understanding of operational needs)
executeTest(
    "SELECT COUNT(*) > 0 FROM information_schema.views WHERE table_name = 'SECURITY_AUDIT_LOG'",
    "Monitoring Implementation", "Business Understanding", 5
);

// Insert all results
snowflake.execute({sqlText: "USE ROLE ACCOUNTADMIN"});
for (var i = 0; i < results.length; i++) {
    var insertSql = `INSERT INTO SPCS_RESTRICTED_DEMO.GRADING.lab_grading_results 
        (student_id, test_category, test_name, points_possible, points_earned, status, error_message)
        VALUES ('${STUDENT_ID}', '${results[i].category}', '${results[i].testName}', 
                ${results[i].possible}, ${results[i].earned}, '${results[i].status}', '${results[i].error}')`;
    snowflake.execute({sqlText: insertSql});
}

// Calculate final grade
var percentage = Math.round((earnedPoints / totalPoints) * 100);
var letterGrade = percentage >= 90 ? 'A' : percentage >= 80 ? 'B' : percentage >= 70 ? 'C' : percentage >= 60 ? 'D' : 'F';

return `Grade Summary for ${STUDENT_ID}:
Points Earned: ${earnedPoints}/${totalPoints} (${percentage}%)
Letter Grade: ${letterGrade}
Status: ${percentage >= 70 ? 'PASS' : 'FAIL'}

Category Breakdown:
- Infrastructure Setup: Tests for basic environment setup
- Data Setup: Tests for sample data creation
- Security Configuration: Tests for caller grants and policies  
- Container Service: Tests for SPCS service deployment
- Data Isolation: Tests for multi-tenant security
- Business Understanding: Tests for operational awareness

See detailed results in SPCS_RESTRICTED_DEMO.GRADING.lab_grading_results table.`;
$$;

-- Create summary report view
CREATE OR REPLACE VIEW lab_grading_summary AS
SELECT 
    student_id,
    COUNT(*) as total_tests,
    SUM(points_possible) as total_possible_points,
    SUM(points_earned) as total_earned_points,
    ROUND((SUM(points_earned) / SUM(points_possible)) * 100, 1) as percentage,
    CASE 
        WHEN ROUND((SUM(points_earned) / SUM(points_possible)) * 100, 1) >= 90 THEN 'A'
        WHEN ROUND((SUM(points_earned) / SUM(points_possible)) * 100, 1) >= 80 THEN 'B'
        WHEN ROUND((SUM(points_earned) / SUM(points_possible)) * 100, 1) >= 70 THEN 'C'
        WHEN ROUND((SUM(points_earned) / SUM(points_possible)) * 100, 1) >= 60 THEN 'D'
        ELSE 'F'
    END as letter_grade,
    CASE 
        WHEN ROUND((SUM(points_earned) / SUM(points_possible)) * 100, 1) >= 70 THEN 'PASS'
        ELSE 'FAIL'
    END as pass_fail_status,
    COUNT(CASE WHEN status = 'PASS' THEN 1 END) as tests_passed,
    COUNT(CASE WHEN status = 'FAIL' THEN 1 END) as tests_failed,
    COUNT(CASE WHEN status = 'ERROR' THEN 1 END) as tests_errored,
    MAX(graded_timestamp) as last_graded
FROM lab_grading_results
GROUP BY student_id;

-- Create detailed category breakdown view
CREATE OR REPLACE VIEW lab_category_breakdown AS
SELECT 
    student_id,
    test_category,
    COUNT(*) as tests_in_category,
    SUM(points_possible) as category_possible_points,
    SUM(points_earned) as category_earned_points,
    ROUND((SUM(points_earned) / SUM(points_possible)) * 100, 1) as category_percentage,
    COUNT(CASE WHEN status = 'PASS' THEN 1 END) as tests_passed,
    COUNT(CASE WHEN status = 'FAIL' THEN 1 END) as tests_failed,
    COUNT(CASE WHEN status = 'ERROR' THEN 1 END) as tests_errored
FROM lab_grading_results
GROUP BY student_id, test_category
ORDER BY student_id, test_category;

-- Sample usage instructions
/*
-- To grade a student's lab (replace 'john.doe@company.com' with actual student identifier):
CALL grade_spcs_lab('john.doe@company.com');

-- To view summary results:
SELECT * FROM lab_grading_summary WHERE student_id = 'john.doe@company.com';

-- To view detailed breakdown:
SELECT * FROM lab_category_breakdown WHERE student_id = 'john.doe@company.com';

-- To view all test details:
SELECT * FROM lab_grading_results WHERE student_id = 'john.doe@company.com' ORDER BY test_category, test_name;

-- To grade multiple students in batch:
-- Create a table with student IDs and use a loop or run individual CALL statements
*/ 