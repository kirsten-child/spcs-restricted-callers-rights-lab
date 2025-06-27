#!/bin/bash

# SPCS Restricted Callers Rights Lab - Build and Deploy Script
# This script builds the container image and deploys it to Snowflake

set -e  # Exit on any error

# Configuration
SERVICE_NAME="analytics_service"
IMAGE_NAME="spcs-restricted-analytics"
IMAGE_TAG="v1.0"
REPOSITORY_PATH="/spcs_restricted_demo/container_registry/analytics_repo"
COMPUTE_POOL="SPCS_RESTRICTED_POOL"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if Docker is running
check_docker() {
    log_info "Checking Docker status..."
    if ! docker info > /dev/null 2>&1; then
        log_error "Docker is not running. Please start Docker and try again."
        exit 1
    fi
    log_info "Docker is running."
}

# Build the container image
build_image() {
    log_info "Building container image: ${IMAGE_NAME}:${IMAGE_TAG}"
    
    # Change to the analytics-service directory
    cd analytics-service
    
    # Build the image
    docker build -t ${IMAGE_NAME}:${IMAGE_TAG} .
    
    if [ $? -eq 0 ]; then
        log_info "Image built successfully."
    else
        log_error "Failed to build image."
        exit 1
    fi
    
    # Go back to parent directory
    cd ..
}

# Tag image for Snowflake repository
tag_image() {
    log_info "Tagging image for Snowflake repository..."
    
    # Get the registry URL from environment or use default
    REGISTRY_URL="${SNOWFLAKE_REGISTRY_URL:-demo83-account.registry.snowflakecomputing.com}"
    FULL_IMAGE_PATH="${REGISTRY_URL}${REPOSITORY_PATH}/${IMAGE_NAME}:${IMAGE_TAG}"
    
    docker tag ${IMAGE_NAME}:${IMAGE_TAG} ${FULL_IMAGE_PATH}
    
    if [ $? -eq 0 ]; then
        log_info "Image tagged as: ${FULL_IMAGE_PATH}"
    else
        log_error "Failed to tag image."
        exit 1
    fi
}

# Push image to Snowflake
push_image() {
    log_info "Pushing image to Snowflake registry..."
    
    REGISTRY_URL="${SNOWFLAKE_REGISTRY_URL:-demo83-account.registry.snowflakecomputing.com}"
    FULL_IMAGE_PATH="${REGISTRY_URL}${REPOSITORY_PATH}/${IMAGE_NAME}:${IMAGE_TAG}"
    
    # Push the image
    docker push ${FULL_IMAGE_PATH}
    
    if [ $? -eq 0 ]; then
        log_info "Image pushed successfully."
    else
        log_error "Failed to push image. Make sure you're authenticated with Snowflake registry."
        log_info "Run: docker login ${REGISTRY_URL}"
        exit 1
    fi
}

# Deploy the service to Snowflake
deploy_service() {
    log_info "Deploying SPCS service..."
    
    # Check if service specification file exists
    if [ ! -f "service-configs/analytics-service.yaml" ]; then
        log_error "Service specification file not found: service-configs/analytics-service.yaml"
        exit 1
    fi
    
    # Create SQL commands file
    cat > deploy_service.sql << EOF
USE ROLE PLATFORM_OWNER;
USE DATABASE SPCS_RESTRICTED_DEMO;
USE SCHEMA FINANCIAL_DATA;

-- Drop existing service if it exists
DROP SERVICE IF EXISTS ${SERVICE_NAME};

-- Create the service with restricted caller's rights
CREATE SERVICE ${SERVICE_NAME}
  IN COMPUTE POOL ${COMPUTE_POOL}
  FROM SPECIFICATION_FILE '@internal_stage/analytics-service.yaml'
  COMMENT = 'Analytics service with restricted callers rights for multi-tenant access';

-- Grant service access to client roles
GRANT USAGE ON SERVICE ${SERVICE_NAME} TO ROLE CLIENT_A_ANALYST;
GRANT USAGE ON SERVICE ${SERVICE_NAME} TO ROLE CLIENT_B_ANALYST;

-- Grant service role access
GRANT USAGE ON SERVICE ROLE ${SERVICE_NAME}.analytics_users TO ROLE CLIENT_A_ANALYST;
GRANT USAGE ON SERVICE ROLE ${SERVICE_NAME}.analytics_users TO ROLE CLIENT_B_ANALYST;

-- Show service status
SHOW SERVICES LIKE '${SERVICE_NAME}';
DESCRIBE SERVICE ${SERVICE_NAME};
EOF

    log_info "Service deployment SQL created. Run the following command to deploy:"
    log_info "snowsql -f deploy_service.sql"
    log_warn "Make sure to upload the service specification file to the internal stage first:"
    log_warn "PUT file://service-configs/analytics-service.yaml @internal_stage;"
}

# Validate deployment
validate_deployment() {
    log_info "Creating validation SQL script..."
    
    cat > validate_deployment.sql << EOF
-- Validation script for SPCS Restricted Callers Rights deployment
USE ROLE PLATFORM_OWNER;

-- Check service status
SELECT 'Service Status Check' as validation_step;
SHOW SERVICES LIKE '${SERVICE_NAME}';

-- Check service endpoints
SELECT 'Service Endpoints Check' as validation_step;
DESCRIBE SERVICE ${SERVICE_NAME};

-- Test caller grants
SELECT 'Caller Grants Check' as validation_step;
SHOW CALLER GRANTS TO ROLE PLATFORM_OWNER;

-- Test data access with different roles
USE ROLE CLIENT_A_ANALYST;
SELECT 'Client A Access Test' as validation_step, COUNT(*) as accessible_records
FROM client_transactions;

USE ROLE CLIENT_B_ANALYST;  
SELECT 'Client B Access Test' as validation_step, COUNT(*) as accessible_records
FROM client_transactions;

USE ROLE PLATFORM_OWNER;
SELECT 'Platform Owner Access Test' as validation_step, COUNT(*) as accessible_records
FROM client_transactions;
EOF

    log_info "Validation SQL created: validate_deployment.sql"
    log_info "Run: snowsql -f validate_deployment.sql"
}

# Cleanup function
cleanup() {
    log_info "Cleaning up temporary files..."
    rm -f deploy_service.sql validate_deployment.sql
}

# Main execution
main() {
    log_info "Starting SPCS Restricted Callers Rights Lab deployment..."
    
    # Parse command line arguments
    case "${1:-all}" in
        "build")
            check_docker
            build_image
            ;;
        "tag")
            tag_image
            ;;
        "push")
            tag_image
            push_image
            ;;
        "deploy")
            deploy_service
            ;;
        "validate")
            validate_deployment
            ;;
        "all")
            check_docker
            build_image
            tag_image
            push_image
            deploy_service
            validate_deployment
            ;;
        "clean")
            cleanup
            ;;
        *)
            echo "Usage: $0 [build|tag|push|deploy|validate|all|clean]"
            echo ""
            echo "Commands:"
            echo "  build    - Build the Docker image"
            echo "  tag      - Tag the image for Snowflake registry"
            echo "  push     - Push the image to Snowflake registry"
            echo "  deploy   - Generate deployment SQL"
            echo "  validate - Generate validation SQL"
            echo "  all      - Run build, tag, push, deploy, and validate"
            echo "  clean    - Clean up temporary files"
            exit 1
            ;;
    esac
    
    log_info "Operation completed successfully!"
}

# Execute main function with all arguments
main "$@" 