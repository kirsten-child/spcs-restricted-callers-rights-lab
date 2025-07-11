# Snowflake Solution Engineering University
## Hands-On Lab: SPCS Restricted Callers Rights
### Secure Multi-Tenant Container Applications

---

**Lab Duration:** 90 minutes  
**Difficulty Level:** Intermediate  
**Prerequisites:** Basic understanding of Snowpark Container Services, SQL, and Docker  
**Industry Focus:** Financial Services (Multi-tenant SaaS Platform)

---

## Lab Overview

In this hands-on lab, you will learn how to implement and sell Snowflake's SPCS (Snowpark Container Services) Restricted Callers Rights feature. This powerful security capability allows containerized applications to execute with user-specific privileges while maintaining strict access controls—perfect for multi-tenant applications where data isolation is critical.

### Learning Objectives

By the end of this lab, you will be able to:

1. **Technical Mastery:**
   - Configure SPCS services with Restricted Callers Rights
   - Implement caller grants for fine-grained access control
   - Build secure multi-tenant container applications
   - Troubleshoot common configuration issues

2. **Sales Enablement:**
   - Identify ideal customer use cases for Restricted Callers Rights
   - Position the feature against competitive solutions
   - Handle common objections around container security
   - Demonstrate ROI and business value

3. **Customer Discovery:**
   - Ask the right qualifying questions
   - Recognize security compliance requirements
   - Map customer pain points to solution benefits

---

## Business Context: SecureFinance Analytics Platform

**Customer Profile:** SecureFinance is a growing FinTech company that provides analytics dashboards for multiple financial institutions. Each client requires strict data isolation while sharing the same application infrastructure.

**Current Pain Points:**
- Complex multi-tenant security management
- Risk of data leakage between clients
- Compliance requirements (SOX, PCI DSS)
- Operational overhead of managing separate environments

**Solution Value Proposition:**
SPCS Restricted Callers Rights enables SecureFinance to deploy a single containerized application that automatically enforces client-specific data access based on user identity, reducing security risks and operational complexity.

---

## Section 1: Understanding the Technology

### What is SPCS Restricted Callers Rights?

SPCS Restricted Callers Rights is a security feature that allows containerized services to execute with the privileges of the calling user, but only for explicitly granted permissions. This provides a "least privilege" approach to container security.

**Key Components:**
1. **Caller's Rights Execution:** Containers run with user privileges, not service owner privileges
2. **Caller Grants:** Explicit permissions that define what user privileges the container can access
3. **Service Specification:** Container configuration that enables caller's rights mode

### Architecture Overview

```
User Authentication → Service Call → Privilege Check → Container Execution
     ↓                    ↓              ↓                ↓
  User Role         executeAsCaller   Caller Grants   User Data Access
```

---      

## Section 2: Environment Setup

### Step 1: Access Your Lab Environment

1. **Connect to Demo83 Environment:**
   ```sql
   -- Use your assigned demo environment
   USE ROLE ACCOUNTADMIN;
   CREATE OR REPLACE WAREHOUSE SPCS_LAB_WH;
   USE WAREHOUSE SPCS_LAB_WH;
   CREATE OR REPLACE DATABASE SPCS_RESTRICTED_DEMO;
   USE DATABASE SPCS_RESTRICTED_DEMO;
   CREATE OR REPLACE SCHEMA FINANCIAL_DATA;
   USE SCHEMA FINANCIAL_DATA;
   
   CREATE IMAGE REPOSITORY IF NOT EXISTS ANALYTICS_REPO;
   ```

### Step 2: Create Lab Resources

**Execute the following setup script:**

```sql
-- Create roles for multi-tenant scenario
CREATE ROLE CLIENT_A_ANALYST;
CREATE ROLE CLIENT_B_ANALYST; 
CREATE ROLE PLATFORM_OWNER;

-- Create sample financial data
CREATE OR REPLACE TABLE client_transactions (
    client_id STRING,
    transaction_id STRING,
    account_id STRING,
    amount DECIMAL(15,2),
    transaction_date DATE,
    transaction_type STRING
);

-- Insert sample data
INSERT INTO client_transactions VALUES
('CLIENT_A', 'TXN001', 'ACC123', 1500.00, '2024-01-15', 'DEPOSIT'),
('CLIENT_A', 'TXN002', 'ACC124', -500.00, '2024-01-16', 'WITHDRAWAL'),
('CLIENT_B', 'TXN003', 'ACC225', 2500.00, '2024-01-15', 'DEPOSIT'),
('CLIENT_B', 'TXN004', 'ACC226', -750.00, '2024-01-17', 'WITHDRAWAL');

-- Create compute pool for containers
CREATE COMPUTE POOL SPCS_RESTRICTED_POOL
    MIN_NODES = 1
    MAX_NODES = 3
    INSTANCE_FAMILY = CPU_X64_XS;
```

---

## Section 3: Building the Multi-Tenant Analytics Service

### Step 3: Create the Container Application

**File: analytics-service/app.py**

```python
from flask import Flask, request, jsonify
import snowflake.connector
import os
import logging

app = Flask(__name__)
logging.basicConfig(level=logging.INFO)

def get_snowflake_connection(user_token=None):
    """Create Snowflake connection with caller's rights"""
    base_token = os.getenv('SNOWFLAKE_TOKEN')
    
    if user_token:
        # Use caller's rights with user token
        token = f"{base_token}.{user_token}"
        logging.info("Creating caller's rights connection")
    else:
        # Use service owner rights
        token = base_token
        logging.info("Creating owner's rights connection")
    
    return snowflake.connector.connect(
        host=os.getenv('SNOWFLAKE_HOST'),
        account=os.getenv('SNOWFLAKE_ACCOUNT'),
        token=token,
        authenticator='oauth'
    )

@app.route('/api/client-summary/<client_id>', methods=['GET'])
def get_client_summary(client_id):
    """Get transaction summary for specific client"""
    try:
        # Get user token from header for caller's rights
        user_token = request.headers.get('Sf-Context-Current-User-Token')
        
        # Create connection with appropriate rights
        conn = get_snowflake_connection(user_token)
        cursor = conn.cursor()
        
        # Execute query - access controlled by caller grants
        query = """
        SELECT 
            client_id,
            COUNT(*) as transaction_count,
            SUM(CASE WHEN amount > 0 THEN amount ELSE 0 END) as total_deposits,
            SUM(CASE WHEN amount < 0 THEN ABS(amount) ELSE 0 END) as total_withdrawals
        FROM client_transactions 
        WHERE client_id = %s
        GROUP BY client_id
        """
        
        cursor.execute(query, (client_id,))
        result = cursor.fetchone()
        
        if result:
            return jsonify({
                'client_id': result[0],
                'transaction_count': result[1],
                'total_deposits': float(result[2]),
                'total_withdrawals': float(result[3]),
                'access_method': 'caller_rights' if user_token else 'owner_rights'
            })
        else:
            return jsonify({'error': 'No data found or access denied'}), 403
            
    except Exception as e:
        logging.error(f"Error: {str(e)}")
        return jsonify({'error': str(e)}), 500
    finally:
        if 'conn' in locals():
            conn.close()

@app.route('/health', methods=['GET'])
def health_check():
    return jsonify({'status': 'healthy'})

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8080)
```

**File: analytics-service/Dockerfile**

```dockerfile
FROM python:3.9-slim

WORKDIR /app

# Install dependencies
COPY requirements.txt .
RUN pip install -r requirements.txt

# Copy application code
COPY app.py .

# Expose port
EXPOSE 8080

# Run application
CMD ["python", "app.py"]
```

**File: analytics-service/requirements.txt**

```
flask==2.3.3
snowflake-connector-python==3.7.0
```

### Step 4: Build and Push Container Image

```bash
# Build the container image
docker build -t spcs-restricted-analytics:v1.0 ./analytics-service/

# Tag for Snowflake repository
docker tag spcs-restricted-analytics:v1.0 \
  demo83-account.registry.snowflakecomputing.com/spcs_restricted_demo/financial_data/analytics_repo/spcs-restricted-analytics:v1.0

# Push to Snowflake
docker push demo83-account.registry.snowflakecomputing.com/spcs_restricted_demo/financial_data/analytics_repo/spcs-restricted-analytics:v1.0
```

---

## Section 4: Configuring Restricted Callers Rights

### Step 5: Create Service Specification

**File: service-spec.yaml**

```yaml
spec:
  containers:
  - name: analytics-service
    image: /spcs_restricted_demo/financial_data/analytics_repo/spcs-restricted-analytics:v1.0
    env:
      PORT: "8080"
  endpoints:
  - name: analytics-api
    port: 8080
    public: true
    protocol: HTTP
capabilities:
  securityContext:
    executeAsCaller: true  # Enable caller's rights
serviceRoles:
- name: analytics_users
  endpoints:
  - analytics-api
```

### Step 6: Set Up Caller Grants

```sql
-- Grant caller grants to service owner for restricted access
USE ROLE ACCOUNTADMIN;

-- Allow service to use SELECT privilege on behalf of callers
GRANT CALLER SELECT ON TABLE client_transactions TO ROLE PLATFORM_OWNER;

-- Allow service to use warehouse on behalf of callers  
GRANT CALLER USAGE ON WAREHOUSE SPCS_LAB_WH TO ROLE PLATFORM_OWNER;

-- Allow service to use database/schema on behalf of callers
GRANT CALLER USAGE ON DATABASE SPCS_RESTRICTED_DEMO TO ROLE PLATFORM_OWNER;
GRANT CALLER USAGE ON SCHEMA FINANCIAL_DATA TO ROLE PLATFORM_OWNER;
```

### Step 7: Deploy the Service

```sql
-- Create the service with restricted caller's rights
USE ROLE PLATFORM_OWNER;

CREATE SERVICE analytics_service
  IN COMPUTE POOL SPCS_RESTRICTED_POOL
  FROM SPECIFICATION $$
spec:
  containers:
  - name: analytics-service
    image: /spcs_restricted_demo/financial_data/analytics_repo/spcs-restricted-analytics:v1.0
    env:
      PORT: "8080"
  endpoints:
  - name: analytics-api
    port: 8080
    public: true
    protocol: HTTP
capabilities:
  securityContext:
    executeAsCaller: true
serviceRoles:
- name: analytics_users
  endpoints:
  - analytics-api
$$;
```

---

## Section 5: Testing Multi-Tenant Security

### Step 8: Configure Client Access

```sql
-- Set up data access for Client A
GRANT SELECT ON client_transactions TO ROLE CLIENT_A_ANALYST;
GRANT USAGE ON WAREHOUSE SPCS_LAB_WH TO ROLE CLIENT_A_ANALYST;
GRANT USAGE ON DATABASE SPCS_RESTRICTED_DEMO TO ROLE CLIENT_A_ANALYST;
GRANT USAGE ON SCHEMA FINANCIAL_DATA TO ROLE CLIENT_A_ANALYST;

-- Create row access policy for Client A
CREATE ROW ACCESS POLICY client_a_policy AS (client_id = 'CLIENT_A');
ALTER TABLE client_transactions ADD ROW ACCESS POLICY client_a_policy ON (client_id);

-- Grant service access to Client A users
GRANT USAGE ON SERVICE analytics_service TO ROLE CLIENT_A_ANALYST;
GRANT USAGE ON SERVICE ROLE analytics_service.analytics_users TO ROLE CLIENT_A_ANALYST;
```

### Step 9: Test Access Controls

```sql
-- Test as Client A analyst
USE ROLE CLIENT_A_ANALYST;

-- This should work - user has access to Client A data
SELECT * FROM client_transactions WHERE client_id = 'CLIENT_A';

-- This should return no results due to row access policy
SELECT * FROM client_transactions WHERE client_id = 'CLIENT_B';
```

**Test via Service Endpoint:**

```bash
# Test API access with authentication
curl -X GET "https://[service-url]/api/client-summary/CLIENT_A" \
  -H "Authorization: Bearer [jwt-token]" \
  -H "Content-Type: application/json"
```

---

## Section 6: Sales Discovery and Positioning

### Customer Discovery Questions

**Security & Compliance:**
1. "How do you currently ensure data isolation in your multi-tenant applications?"
2. "What compliance frameworks are you subject to? (SOX, GDPR, HIPAA, etc.)"
3. "Have you experienced any data leakage incidents between tenants?"

**Technical Architecture:**
1. "Are you using containerized applications for your data services?"
2. "How do you manage user authentication and authorization across applications?"
3. "Do you have applications that need to access Snowflake data with user-specific permissions?"

**Business Impact:**
1. "How much time does your team spend managing security policies across environments?"
2. "What's the business impact of potential data exposure between clients?"
3. "Are you able to quickly onboard new clients with existing infrastructure?"

### Value Proposition Messaging

**Primary Value Drivers:**

1. **Enhanced Security Posture**
   - *Message:* "Eliminate the risk of privilege escalation by ensuring containers can only access data the user is authorized to see"
   - *Evidence:* Row-level security enforced at the container level

2. **Simplified Multi-Tenancy**
   - *Message:* "Deploy once, secure everywhere - single application serves multiple tenants with automatic data isolation"
   - *Evidence:* Demonstrate same service returning different data for different users

3. **Compliance Readiness**
   - *Message:* "Built-in audit trails and access controls that satisfy the most stringent compliance requirements"
   - *Evidence:* Query history shows exactly what data each user accessed

4. **Operational Efficiency**
   - *Message:* "Reduce infrastructure complexity and management overhead with centralized security controls"
   - *Evidence:* Single service specification manages security for all tenants

### Competitive Positioning

**vs. AWS EKS/ECS with IAM:**
- *Snowflake Advantage:* Native integration with data platform, no complex IAM role mapping
- *Customer Benefit:* Reduced complexity and improved security posture

**vs. Azure AKS with Azure AD:**
- *Snowflake Advantage:* Data-native security model, unified governance
- *Customer Benefit:* Simplified compliance reporting and audit trails

**vs. Custom-built solutions:**
- *Snowflake Advantage:* Fully managed, tested at scale, immediate availability
- *Customer Benefit:* Faster time-to-market, lower development costs

---

## Section 7: Objection Handling

### Common Objections and Responses

**Objection 1:** "We already have container security with Kubernetes RBAC"

*Response:* "Kubernetes RBAC is excellent for infrastructure access, but it doesn't provide data-level access controls. SPCS Restricted Callers Rights gives you application-level security that's directly tied to your data permissions. Let me show you how this prevents data leakage that RBAC alone cannot address..."

*Demo:* Show same container returning different data based on user identity

**Objection 2:** "This seems complex to implement"

*Response:* "I understand that concern. Let's compare the setup complexity to your current multi-tenant security approach. Most customers find this actually reduces complexity because you're managing security in one place rather than across multiple layers..."

*Demo:* Walk through the simple service specification and caller grant setup

**Objection 3:** "What about performance impact?"

*Response:* "Great question. The security evaluation happens at query planning time, not execution time, so there's minimal performance impact. Plus, you're eliminating network hops between your application and data..."

*Demo:* Show query execution times with and without caller's rights

**Objection 4:** "We're not ready for containers yet"

*Response:* "That's perfectly fine. SPCS Restricted Callers Rights is just one security option in your toolkit. When you do move to containerized applications - which 87% of enterprises plan to do according to CNCF - you'll have this capability ready. For now, let's also discuss how Snowflake's other security features can address your immediate needs..."

---

## Section 8: Business Value Demonstration

### ROI Calculation Framework

**Cost Savings:**
1. **Reduced Infrastructure Costs**
   - Fewer environments needed for tenant isolation
   - Savings: $X per month per eliminated environment

2. **Development Efficiency**
   - Single codebase for multi-tenant application
   - Savings: X developer hours per feature release

3. **Compliance Costs**
   - Simplified audit and reporting
   - Savings: X audit hours per compliance cycle

**Risk Mitigation:**
1. **Data Breach Prevention**
   - Average cost of data breach: $4.45M (IBM, 2023)
   - Risk reduction: X% based on improved access controls

2. **Compliance Violations**
   - Average regulatory fine: $X based on industry
   - Risk reduction: X% based on improved governance

### Success Metrics

**Technical Metrics:**
- Query response time: < 2 seconds for typical analytics queries
- Security policy deployment time: < 1 hour vs. days for traditional approaches
- Multi-tenant onboarding time: < 4 hours vs. weeks

**Business Metrics:**
- Time to market for new features: 50% reduction
- Security incident response time: 75% reduction
- Compliance audit preparation time: 60% reduction

---

## Section 9: Advanced Configuration

### Dynamic Row-Level Security

```sql
-- Create dynamic masking policy
CREATE MASKING POLICY account_mask AS (val STRING) RETURNS STRING ->
    CASE 
        WHEN CURRENT_ROLE() IN ('CLIENT_A_ANALYST') AND val LIKE 'ACC1%' THEN val
        WHEN CURRENT_ROLE() IN ('CLIENT_B_ANALYST') AND val LIKE 'ACC2%' THEN val
        ELSE 'XXX-MASKED'
    END;

-- Apply masking policy
ALTER TABLE client_transactions MODIFY COLUMN account_id SET MASKING POLICY account_mask;
```

### Monitoring and Alerting

```sql
-- Create monitoring view for security events
CREATE VIEW security_monitoring AS
SELECT 
    query_id,
    query_text,
    user_name,
    role_name,
    start_time,
    execution_status
FROM snowflake.account_usage.query_history
WHERE query_text ILIKE '%client_transactions%'
AND start_time >= DATEADD(hour, -24, CURRENT_TIMESTAMP());
```

---

## Section 10: Troubleshooting Guide

### Common Issues and Solutions

**Issue:** Container fails to start with "executeAsCaller: true"
*Solution:* Verify caller grants are properly configured for the service owner role

**Issue:** Users see "Access Denied" errors
*Solution:* Check that users have both direct table permissions AND service usage permissions

**Issue:** Wrong data returned for user
*Solution:* Verify row access policies are correctly applied and user tokens are being passed

**Issue:** Performance degradation
*Solution:* Review query plans to ensure security policies are optimized

### Debugging Commands

```sql
-- Check caller grants
SHOW CALLER GRANTS TO ROLE PLATFORM_OWNER;

-- View service status
SHOW SERVICES;
DESCRIBE SERVICE analytics_service;

-- Check user permissions
SHOW GRANTS TO ROLE CLIENT_A_ANALYST;

-- Monitor query execution
SELECT * FROM TABLE(INFORMATION_SCHEMA.QUERY_HISTORY())
WHERE query_text ILIKE '%client_transactions%'
ORDER BY start_time DESC;
```

---

## Section 11: Lab Validation and Grading

### Hands-On Exercises

**Exercise 1: Basic Setup (20 points)**
- [ ] Create compute pool and service successfully
- [ ] Configure executeAsCaller correctly
- [ ] Deploy container with proper specifications

**Exercise 2: Security Configuration (25 points)**
- [ ] Set up caller grants properly
- [ ] Configure row access policies
- [ ] Test multi-tenant data isolation

**Exercise 3: Application Integration (20 points)**
- [ ] Build and deploy container application
- [ ] Implement caller's rights authentication
- [ ] Demonstrate API functionality

**Exercise 4: Sales Simulation (25 points)**
- [ ] Conduct customer discovery conversation
- [ ] Position value proposition effectively
- [ ] Handle at least 2 objections successfully

**Exercise 5: Business Case (10 points)**
- [ ] Calculate ROI for sample customer
- [ ] Present business value metrics
- [ ] Recommend next steps

### Validation Scenarios

**Scenario 1:** Customer is a SaaS provider with 50 tenants
*Expected Response:* Emphasize operational efficiency and security isolation

**Scenario 2:** Financial services with strict compliance requirements
*Expected Response:* Focus on audit capabilities and data governance

**Scenario 3:** Healthcare organization with PHI data
*Expected Response:* Highlight privacy controls and access logging

---

## Section 12: Next Steps and Resources

### Customer Next Steps

1. **Proof of Concept Phase (2-4 weeks)**
   - Set up trial environment
   - Migrate one application workload
   - Validate security requirements

2. **Pilot Implementation (1-2 months)**
   - Deploy production-ready service
   - Train development team
   - Establish monitoring and alerts

3. **Full Rollout (3-6 months)**
   - Migrate all applicable workloads
   - Implement advanced security policies
   - Optimize performance and costs

### Additional Resources

**Documentation:**
- [SPCS Security Best Practices](https://docs.snowflake.com/spcs-security)
- [Caller Grants Reference](https://docs.snowflake.com/caller-grants)
- [Container Services Tutorial](https://docs.snowflake.com/spcs-tutorial)

**Training:**
- Snowflake University: Container Services Fundamentals
- Partner Training: Security Architecture with Snowflake
- Certification: Snowflake Security Specialist

**Support:**
- Solution Engineering team for POC assistance
- Professional Services for implementation guidance
- Customer Support for ongoing operational issues

---

## Conclusion

SPCS Restricted Callers Rights represents a significant advancement in cloud-native application security. By completing this lab, you've gained the technical knowledge and sales skills needed to help customers implement secure, multi-tenant applications that meet the most stringent compliance requirements.

Remember the key value drivers:
- **Enhanced Security:** User-level access controls at the container level
- **Simplified Operations:** Single application serving multiple tenants securely
- **Compliance Ready:** Built-in audit trails and access controls
- **Cost Effective:** Reduced infrastructure and operational overhead

Use the discovery questions, objection handling techniques, and business value framework to guide your customer conversations and drive successful SPCS implementations.

---

*Lab Version: 1.0 | Last Updated: January 2024 | Contact: SE-Uni-Team@snowflake.com* 
