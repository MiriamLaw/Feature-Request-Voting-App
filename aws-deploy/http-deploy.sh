#!/bin/bash

# Source existing environment variables
# Ensure these files exist and contain the necessary values
if [ -f "aws-deploy/vpc-output.env" ] && [ -f "aws-deploy/rds-output.env" ]; then
    source aws-deploy/vpc-output.env
    source aws-deploy/rds-output.env # Used for DB host/user/name if needed, but connection string comes from Secrets Mgr
elif [ -f "vpc-output.env" ] && [ -f "rds-output.env" ]; then
    # Handle case where script is run from within aws-deploy directory
    source vpc-output.env
    source rds-output.env
else
    echo "Error: Could not find vpc-output.env or rds-output.env."
    echo "Please ensure these files exist in the 'aws-deploy' directory relative to your project root."
    exit 1
fi
# secrets-output.env is no longer needed for secrets, but might be sourced for other reasons? Removed sourcing for now.
# source secrets-output.env
# ECR URI might be in ecr-output.env, source it if necessary
# source ecr-output.env

# Set variables
APP_NAME="feature-voting-app"
CLUSTER_NAME="feature-voting-cluster"
SERVICE_NAME="feature-voting-app-service"
TASK_FAMILY="feature-voting-app-task"
CONTAINER_NAME="feature-voting-app"
CONTAINER_PORT=3000 # Changed from 80 - Run container on non-privileged port
ALB_NAME="feature-voting-app-lb"
TARGET_GROUP_NAME="feature-voting-app-tg"
SECRET_ARN="arn:aws:secretsmanager:us-east-1:753561063721:secret:feature-voting-app-secrets-Zbqr22" # Your Specific Secret ARN
AWS_REGION=$(aws configure get region) # Or set explicitly e.g., us-east-1

# Get AWS account ID
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
ECR_REPOSITORY_URI="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${APP_NAME}" # Construct ECR URI

# Check if required env vars are set (Only VPC vars now)
if [ -z "$VPC_ID" ] || [ -z "$PUBLIC_SUBNET_1_ID" ] || [ -z "$PUBLIC_SUBNET_2_ID" ] || [ -z "$APP_SG_ID" ]; then
  echo "Error: One or more required VPC environment variables are missing."
  echo "Please ensure vpc-output.env contains VPC_ID, PUBLIC_SUBNET_1_ID, PUBLIC_SUBNET_2_ID, APP_SG_ID."
  exit 1
fi


# Create Application Load Balancer
echo "Creating Application Load Balancer..."
# Check if ALB already exists (optional, safer to delete first as instructed)
# aws elbv2 describe-load-balancers --names ${ALB_NAME} > /dev/null 2>&1
# if [ $? -eq 0 ]; then
#   echo "Load Balancer ${ALB_NAME} already exists. Skipping creation."
#   ALB_ARN=$(aws elbv2 describe-load-balancers --names ${ALB_NAME} --query 'LoadBalancers[0].LoadBalancerArn' --output text)
# else
  ALB_ARN=$(aws elbv2 create-load-balancer \
      --name ${ALB_NAME} \
      --subnets ${PUBLIC_SUBNET_1_ID} ${PUBLIC_SUBNET_2_ID} \
      --security-groups ${APP_SG_ID} \
      --scheme internet-facing \
      --type application \
      --query 'LoadBalancers[0].LoadBalancerArn' \
      --output text)
# fi

# Get the ALB DNS name (needed for NEXTAUTH_URL)
echo "Waiting for ALB to be available..."
aws elbv2 wait load-balancer-available --load-balancer-arns ${ALB_ARN}
ALB_DNS_NAME=$(aws elbv2 describe-load-balancers \
    --names ${ALB_NAME} \
    --query 'LoadBalancers[0].DNSName' \
    --output text)
echo "ALB DNS Name: ${ALB_DNS_NAME}"

# Create target group
echo "Creating target group..."
# Check if TG already exists (optional, safer to delete first as instructed)
# aws elbv2 describe-target-groups --names ${TARGET_GROUP_NAME} > /dev/null 2>&1
# if [ $? -eq 0 ]; then
#   echo "Target Group ${TARGET_GROUP_NAME} already exists. Skipping creation."
#   TARGET_GROUP_ARN=$(aws elbv2 describe-target-groups --names ${TARGET_GROUP_NAME} --query 'TargetGroups[0].TargetGroupArn' --output text)
# else
  TARGET_GROUP_ARN=$(aws elbv2 create-target-group \
      --name ${TARGET_GROUP_NAME} \
      --protocol HTTP \
      --port ${CONTAINER_PORT} \
      --vpc-id ${VPC_ID} \
      --target-type ip \
      --health-check-protocol HTTP \
      --health-check-path "/api/health" \
      --health-check-interval-seconds 30 \
      --health-check-timeout-seconds 5 \
      --healthy-threshold-count 2 \
      --unhealthy-threshold-count 2 \
      --query 'TargetGroups[0].TargetGroupArn' \
      --output text)
# fi

# Create listener for HTTP
echo "Creating HTTP listener..."
# Consider checking if listener exists for idempotency, or ensure ALB is deleted first
aws elbv2 create-listener \
    --load-balancer-arn ${ALB_ARN} \
    --protocol HTTP \
    --port 80 \
    --default-actions Type=forward,TargetGroupArn=${TARGET_GROUP_ARN}

# Create ECS cluster
echo "Creating ECS cluster..."
# This command fails gracefully if the cluster exists
aws ecs create-cluster --cluster-name ${CLUSTER_NAME}

# Register task definition
echo "Registering initial task definition..."
# Construct the container definitions JSON string using Secrets Manager
TASK_DEFINITION_JSON=$(cat <<-EOF
[
  {
    "name": "${CONTAINER_NAME}",
    "image": "${ECR_REPOSITORY_URI}:latest",
    "cpu": 256,
    "memory": 512,
    "essential": true,
    "portMappings": [
      {
        "containerPort": ${CONTAINER_PORT},
        "hostPort": ${CONTAINER_PORT},
        "protocol": "tcp"
      }
    ],
    "environment": [
      { "name": "NODE_ENV", "value": "production" },
      { "name": "NEXTAUTH_URL", "value": "http://${ALB_DNS_NAME}" }
    ],
    "secrets": [
      {
        "name": "DATABASE_URL",
        "valueFrom": "${SECRET_ARN}:DATABASE_URL::"
      },
      {
        "name": "NEXTAUTH_SECRET",
        "valueFrom": "${SECRET_ARN}:NEXTAUTH_SECRET::"
      },
      {
        "name": "GOOGLE_ID",
        "valueFrom": "${SECRET_ARN}:GOOGLE_ID::"
      },
      {
        "name": "GOOGLE_SECRET",
        "valueFrom": "${SECRET_ARN}:GOOGLE_SECRET::"
      }
    ],
    "logConfiguration": {
      "logDriver": "awslogs",
      "options": {
        "awslogs-group": "/ecs/${APP_NAME}",
        "awslogs-region": "${AWS_REGION}",
        "awslogs-stream-prefix": "ecs"
      }
    },
    "healthCheck": {
        "command": [
            "CMD-SHELL",
            "curl -f http://localhost:3000/api/health || exit 1"
        ],
        "interval": 30,
        "timeout": 5,
        "retries": 3,
        "startPeriod": 60
    }
  }
]
EOF
)

TASK_DEFINITION_ARN=$(aws ecs register-task-definition \
    --family ${TASK_FAMILY} \
    --network-mode awsvpc \
    --requires-compatibilities FARGATE \
    --cpu 256 \
    --memory 512 \
    --execution-role-arn arn:aws:iam::${AWS_ACCOUNT_ID}:role/ecsTaskExecutionRole \
    --task-role-arn arn:aws:iam::${AWS_ACCOUNT_ID}:role/ecsTaskExecutionRole \
    --container-definitions "${TASK_DEFINITION_JSON}" \
    --query 'taskDefinition.taskDefinitionArn' \
    --output text)

echo "Registered Task Definition ARN: ${TASK_DEFINITION_ARN}"

# Create ECS service
echo "Creating ECS service..."
# Check if service exists (optional, safer to delete orphan services first)
# aws ecs describe-services --cluster ${CLUSTER_NAME} --services ${SERVICE_NAME} > /dev/null 2>&1
# if [ $? -eq 0 ]; then
#   echo "Service ${SERVICE_NAME} already exists. Skipping creation."
# else
  aws ecs create-service \
      --cluster ${CLUSTER_NAME} \
      --service-name ${SERVICE_NAME} \
      --task-definition ${TASK_DEFINITION_ARN} \
      --desired-count 1 \
      --launch-type FARGATE \
      --platform-version LATEST \
      --network-configuration "awsvpcConfiguration={subnets=[${PUBLIC_SUBNET_1_ID},${PUBLIC_SUBNET_2_ID}],securityGroups=[${APP_SG_ID}],assignPublicIp=ENABLED}" \
      --load-balancers "targetGroupArn=${TARGET_GROUP_ARN},containerName=${CONTAINER_NAME},containerPort=${CONTAINER_PORT}" \
      --health-check-grace-period-seconds 60 # Add grace period for container start
# fi

# No longer needed to save ALB DNS to file, it's used directly above
# echo "ALB_DNS_NAME=${ALB_DNS_NAME}" > http-deploy-output.env

echo "HTTP infrastructure setup completed successfully!"
echo "You should be able to access your application soon at: http://${ALB_DNS_NAME}"
echo "Use 'aws ecs describe-services --cluster ${CLUSTER_NAME} --services ${SERVICE_NAME}' to check deployment status." 