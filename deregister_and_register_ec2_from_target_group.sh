#!/bin/bash

# Define variables
REGION="ap-south-1"

TAG_KEY="$1"
TAG_VALUE="$2"
TARGET_GROUP_ARN="$3"
# Function to log messages
log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S'): $1"
}

# Function to handle errors
handle_error() {
    log_message "ERROR: $1"
}

# Log start of script execution
log_message "Starting EC2 instance deregistration and registration from Target Group"

# Check if TARGET_GROUP_ARN is provided
if [ -z "$TARGET_GROUP_ARN" ]; then
    log_message "ERROR: Target Group ARN not provided."
    exit 1
fi

log_message "Using Target Group ARN: $TARGET_GROUP_ARN"

# Tag key and value for identifying instances

# Function to deregister an instance
deregister_instance() {
    local INSTANCE_ID=$1
    
    log_message "Attempting to deregister instance with ID $INSTANCE_ID"
    
    aws elbv2 deregister-targets --region $REGION \
        --target-group-arn $TARGET_GROUP_ARN \
        --targets Id=$INSTANCE_ID
    
    if [ $? -eq 0 ]; then
        log_message "Successfully deregistered instance with ID $INSTANCE_ID"
    else
        handle_error "Failed to deregister instance with ID $INSTANCE_ID: $(aws elbv2 deregister-targets --region $REGION --target-group-arn $TARGET_GROUP_ARN --targets Id=$INSTANCE_ID 2>&1)"
    fi
    
    log_message "Waiting for 2 minutes before next operation..."
    sleep 120
}

# Function to register an instance
register_instance() {
    local INSTANCE_ID=$1
    
    log_message "Attempting to register instance with ID $INSTANCE_ID"
    
    aws elbv2 register-targets --region $REGION \
        --target-group-arn $TARGET_GROUP_ARN \
        --targets Id=$INSTANCE_ID
    
    if [ $? -eq 0 ]; then
        log_message "Successfully registered instance with ID $INSTANCE_ID"
    else
        handle_error "Failed to register instance with ID $INSTANCE_ID: $(aws elbv2 register-targets --region $REGION --target-group-arn $TARGET_GROUP_ARN --targets Id=$INSTANCE_ID 2>&1)"
    fi
    
    log_message "Waiting for 2 minutes before next operation..."
    sleep 120
}

# Main execution loop
while true; do
    # Find EC2 instances with the specified tag
    INSTANCES=$(aws ec2 describe-instances --region $REGION \
        --filters "Name=tag:$TAG_KEY,Values=$TAG_VALUE" \
        --query 'Reservations[].Instances[].InstanceId' --output text)
    
    if [ -z "$INSTANCES" ]; then
        log_message "No EC2 instances found with tag '$TAG_KEY:$TAG_VALUE'. Exiting."
        break
    fi
    
    # Process each instance
    for INSTANCE_ID in $INSTANCES; do
        deregister_instance "$INSTANCE_ID"
        
        # Wait for 2 minutes between deregistration and registration
        sleep 120
        
        register_instance "$INSTANCE_ID"
    done
    
    # Exit after processing all instances
    break
done

log_message "All specified EC2 instances have been processed for deregistration and registration."
