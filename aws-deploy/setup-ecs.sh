#!/bin/bash

# Set variables
CLUSTER_NAME="feature-voting-cluster"
SERVICE_NAME="feature-voting-service"
TASK_FAMILY="feature-voting-app-task"
AWS_REGION="us-east-1"

# Create ECS cluster
echo "Creating ECS cluster..."
aws ecs create-cluster \
    --cluster-name ${CLUSTER_NAME} \
    --capacity-providers FARGATE \
    --default-capacity-provider-strategy capacityProvider=FARGATE,weight=1

# Get the latest task definition ARN
TASK_DEFINITION=$(aws ecs describe-task-definition \
    --task-definition ${TASK_FAMILY} \
    --query 'taskDefinition.taskDefinitionArn' \
    --output text)

# Create security group for the ECS tasks
echo "Creating security group for ECS tasks..."
VPC_ID=$(aws ec2 describe-vpcs --filters "Name=isDefault,Values=true" --query "Vpcs[0].VpcId" --output text)

SECURITY_GROUP_ID=$(aws ec2 create-security-group \
    --group-name "ecs-tasks-sg" \
    --description "Security group for ECS tasks" \
    --vpc-id ${VPC_ID} \
    --query "GroupId" \
    --output text)

# Allow inbound traffic on port 3000
aws ec2 authorize-security-group-ingress \
    --group-id ${SECURITY_GROUP_ID} \
    --protocol tcp \
    --port 3000 \
    --cidr 0.0.0.0/0

# Get subnet IDs from the default VPC
SUBNET_IDS=$(aws ec2 describe-subnets \
    --filters "Name=vpc-id,Values=${VPC_ID}" \
    --query "Subnets[*].SubnetId" \
    --output text)

# Convert space-separated subnet IDs to comma-separated
SUBNET_LIST=$(echo ${SUBNET_IDS} | tr ' ' ',')

# Create ECS service
echo "Creating ECS service..."
aws ecs create-service \
    --cluster ${CLUSTER_NAME} \
    --service-name ${SERVICE_NAME} \
    --task-definition ${TASK_DEFINITION} \
    --desired-count 1 \
    --launch-type FARGATE \
    --network-configuration "awsvpcConfiguration={subnets=[${SUBNET_LIST}],securityGroups=[${SECURITY_GROUP_ID}],assignPublicIp=ENABLED}" \
    --scheduling-strategy REPLICA

echo "ECS cluster and service created successfully!"