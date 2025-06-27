-- SPCS Restricted Callers Rights Lab - Data Setup
-- This script creates the sample financial data for multi-tenant testing

USE ROLE PLATFORM_OWNER;
USE DATABASE SPCS_RESTRICTED_DEMO;
USE SCHEMA FINANCIAL_DATA;
USE WAREHOUSE SPCS_LAB_WH;

-- Create main transactions table
CREATE OR REPLACE TABLE client_transactions (
    client_id STRING NOT NULL,
    transaction_id STRING NOT NULL,
    account_id STRING NOT NULL,
    amount DECIMAL(15,2) NOT NULL,
    transaction_date DATE NOT NULL,
    transaction_type STRING NOT NULL,
    description STRING,
    merchant_category STRING,
    created_timestamp TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    PRIMARY KEY(transaction_id)
) COMMENT = 'Multi-tenant financial transaction data';

-- Insert realistic sample data for Client A (Financial Services Company)
INSERT INTO client_transactions VALUES
-- Client A - January 2024 transactions
('CLIENT_A', 'TXN_A_001', 'ACC_A_001', 25000.00, '2024-01-02', 'DEPOSIT', 'Wire Transfer from Corporate Account', 'BUSINESS', '2024-01-02 09:15:00'),
('CLIENT_A', 'TXN_A_002', 'ACC_A_001', -1250.00, '2024-01-03', 'WITHDRAWAL', 'Office Rent Payment', 'RENT', '2024-01-03 14:30:00'),
('CLIENT_A', 'TXN_A_003', 'ACC_A_002', 15000.00, '2024-01-05', 'DEPOSIT', 'Client Payment - Investment Advisory', 'PROFESSIONAL_SERVICES', '2024-01-05 11:20:00'),
('CLIENT_A', 'TXN_A_004', 'ACC_A_001', -850.00, '2024-01-08', 'WITHDRAWAL', 'Software License Payment', 'TECHNOLOGY', '2024-01-08 16:45:00'),
('CLIENT_A', 'TXN_A_005', 'ACC_A_003', 8500.00, '2024-01-10', 'DEPOSIT', 'Consultation Fee', 'PROFESSIONAL_SERVICES', '2024-01-10 10:30:00'),
('CLIENT_A', 'TXN_A_006', 'ACC_A_001', -2100.00, '2024-01-12', 'WITHDRAWAL', 'Employee Salaries', 'PAYROLL', '2024-01-12 08:00:00'),
('CLIENT_A', 'TXN_A_007', 'ACC_A_002', -450.00, '2024-01-15', 'WITHDRAWAL', 'Marketing Campaign', 'MARKETING', '2024-01-15 13:20:00'),
('CLIENT_A', 'TXN_A_008', 'ACC_A_001', 5200.00, '2024-01-18', 'DEPOSIT', 'Investment Returns', 'INVESTMENT', '2024-01-18 15:10:00'),
('CLIENT_A', 'TXN_A_009', 'ACC_A_003', -780.00, '2024-01-20', 'WITHDRAWAL', 'Professional Insurance', 'INSURANCE', '2024-01-20 12:00:00'),
('CLIENT_A', 'TXN_A_010', 'ACC_A_002', 12000.00, '2024-01-22', 'DEPOSIT', 'Advisory Fee - Q1', 'PROFESSIONAL_SERVICES', '2024-01-22 14:45:00'),

-- Client B - Regional Bank transactions
('CLIENT_B', 'TXN_B_001', 'ACC_B_001', 45000.00, '2024-01-02', 'DEPOSIT', 'Interbank Transfer', 'BANKING', '2024-01-02 08:30:00'),
('CLIENT_B', 'TXN_B_002', 'ACC_B_002', 32000.00, '2024-01-03', 'DEPOSIT', 'Commercial Loan Disbursement', 'LENDING', '2024-01-03 10:15:00'),
('CLIENT_B', 'TXN_B_003', 'ACC_B_001', -3500.00, '2024-01-04', 'WITHDRAWAL', 'ATM Network Fees', 'OPERATIONAL', '2024-01-04 16:20:00'),
('CLIENT_B', 'TXN_B_004', 'ACC_B_003', 18500.00, '2024-01-08', 'DEPOSIT', 'Mortgage Processing Fees', 'MORTGAGE', '2024-01-08 11:30:00'),
('CLIENT_B', 'TXN_B_005', 'ACC_B_002', -12000.00, '2024-01-10', 'WITHDRAWAL', 'Federal Reserve Transfer', 'REGULATORY', '2024-01-10 09:45:00'),
('CLIENT_B', 'TXN_B_006', 'ACC_B_001', 28000.00, '2024-01-12', 'DEPOSIT', 'Credit Card Processing Revenue', 'PAYMENT_PROCESSING', '2024-01-12 13:15:00'),
('CLIENT_B', 'TXN_B_007', 'ACC_B_003', -5400.00, '2024-01-15', 'WITHDRAWAL', 'Compliance Audit Costs', 'COMPLIANCE', '2024-01-15 14:00:00'),
('CLIENT_B', 'TXN_B_008', 'ACC_B_002', 22000.00, '2024-01-18', 'DEPOSIT', 'Investment Portfolio Returns', 'INVESTMENT', '2024-01-18 12:30:00'),
('CLIENT_B', 'TXN_B_009', 'ACC_B_001', -8700.00, '2024-01-20', 'WITHDRAWAL', 'Technology Infrastructure', 'TECHNOLOGY', '2024-01-20 15:45:00'),
('CLIENT_B', 'TXN_B_010', 'ACC_B_003', 35000.00, '2024-01-22', 'DEPOSIT', 'Treasury Operations', 'TREASURY', '2024-01-22 10:20:00');

-- Add more recent transactions for better testing
INSERT INTO client_transactions VALUES
-- Client A - February 2024 transactions
('CLIENT_A', 'TXN_A_011', 'ACC_A_001', 18000.00, '2024-02-01', 'DEPOSIT', 'Monthly Retainer Payment', 'PROFESSIONAL_SERVICES', '2024-02-01 09:00:00'),
('CLIENT_A', 'TXN_A_012', 'ACC_A_002', -950.00, '2024-02-05', 'WITHDRAWAL', 'Cloud Infrastructure Costs', 'TECHNOLOGY', '2024-02-05 11:30:00'),
('CLIENT_A', 'TXN_A_013', 'ACC_A_003', 7200.00, '2024-02-08', 'DEPOSIT', 'Training Services', 'EDUCATION', '2024-02-08 14:15:00'),

-- Client B - February 2024 transactions  
('CLIENT_B', 'TXN_B_011', 'ACC_B_001', 52000.00, '2024-02-01', 'DEPOSIT', 'Monthly Settlement', 'BANKING', '2024-02-01 08:15:00'),
('CLIENT_B', 'TXN_B_012', 'ACC_B_002', -15000.00, '2024-02-05', 'WITHDRAWAL', 'Reserve Requirement', 'REGULATORY', '2024-02-05 16:30:00'),
('CLIENT_B', 'TXN_B_013', 'ACC_B_003', 41000.00, '2024-02-08', 'DEPOSIT', 'Wealth Management Fees', 'WEALTH_MANAGEMENT', '2024-02-08 13:45:00');

-- Create summary view for quick reference
CREATE OR REPLACE VIEW client_summary AS
SELECT 
    client_id,
    COUNT(*) as total_transactions,
    SUM(CASE WHEN amount > 0 THEN amount ELSE 0 END) as total_deposits,
    SUM(CASE WHEN amount < 0 THEN ABS(amount) ELSE 0 END) as total_withdrawals,
    MIN(transaction_date) as first_transaction,
    MAX(transaction_date) as last_transaction,
    COUNT(DISTINCT account_id) as account_count
FROM client_transactions
GROUP BY client_id;

-- Create account details table for additional testing
CREATE OR REPLACE TABLE account_details (
    client_id STRING NOT NULL,
    account_id STRING NOT NULL,
    account_type STRING NOT NULL,
    account_name STRING,
    opening_balance DECIMAL(15,2),
    current_balance DECIMAL(15,2),
    account_status STRING DEFAULT 'ACTIVE',
    opened_date DATE,
    PRIMARY KEY(account_id)
) COMMENT = 'Account details for multi-tenant testing';

INSERT INTO account_details VALUES
-- Client A accounts
('CLIENT_A', 'ACC_A_001', 'BUSINESS_CHECKING', 'Primary Operating Account', 50000.00, 71500.00, 'ACTIVE', '2023-06-15'),
('CLIENT_A', 'ACC_A_002', 'BUSINESS_SAVINGS', 'Revenue Reserve Account', 25000.00, 38550.00, 'ACTIVE', '2023-06-15'),
('CLIENT_A', 'ACC_A_003', 'PROFESSIONAL_ESCROW', 'Client Escrow Account', 10000.00, 16920.00, 'ACTIVE', '2023-08-01'),

-- Client B accounts
('CLIENT_B', 'ACC_B_001', 'CORPORATE_CHECKING', 'Main Operating Account', 100000.00, 162800.00, 'ACTIVE', '2023-01-10'),
('CLIENT_B', 'ACC_B_002', 'LENDING_PORTFOLIO', 'Loan Portfolio Account', 500000.00, 547000.00, 'ACTIVE', '2023-01-10'),
('CLIENT_B', 'ACC_B_003', 'TREASURY_ACCOUNT', 'Treasury Management Account', 250000.00, 284600.00, 'ACTIVE', '2023-02-01');

-- Show data summary
SELECT 'Transactions by Client' as metric_type, client_id as dimension, COUNT(*) as value
FROM client_transactions 
GROUP BY client_id
UNION ALL
SELECT 'Total Transactions' as metric_type, 'ALL_CLIENTS' as dimension, COUNT(*) as value
FROM client_transactions
UNION ALL
SELECT 'Total Deposit Amount' as metric_type, 'ALL_CLIENTS' as dimension, 
       SUM(CASE WHEN amount > 0 THEN amount ELSE 0 END) as value
FROM client_transactions
UNION ALL
SELECT 'Total Withdrawal Amount' as metric_type, 'ALL_CLIENTS' as dimension,
       SUM(CASE WHEN amount < 0 THEN ABS(amount) ELSE 0 END) as value
FROM client_transactions
ORDER BY metric_type, dimension; 