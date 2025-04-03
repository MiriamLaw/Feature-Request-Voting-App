#!/bin/bash

# This script updates the ECS service with a new task definition revision.
# Run this after pushing a new image to ECR or changing environment variables.

# Assume running from workspace root or aws-deploy. If running from root, cd aws-deploy might be needed.
# cd "$(dirname "$0")"

# Source environment files
# Ensure these files exist and contain the necessary values
if [ ! -f "aws-deploy/vpc-output.env" ] || [ ! -f "aws-deploy/rds-output.env" ]; then
    # Check also relative to current dir if not in root
    if [ ! -f "vpc-output.env" ] || [ ! -f "rds-output.env" ]; then
        echo "Error: Required environment files are missing. Please ensure vpc-output.env and rds-output.env exist in aws-deploy/ or current directory."
        exit 1
    fi
    source vpc-output.env
    source rds-output.env # Still potentially useful for non-connection string info
else
    source aws-deploy/vpc-output.env
    source aws-deploy/rds-output.env
fi

# Set variables
APP_NAME="feature-voting-app"
CLUSTER_NAME="feature-voting-cluster"
SERVICE_NAME="feature-voting-app-service"
TASK_FAMILY="feature-voting-app-task"
CONTAINER_NAME="feature-voting-app"
CONTAINER_PORT=3000
ALB_NAME="feature-voting-app-lb" # Assumes ALB name is consistent
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

# Get the ALB DNS name (required for NEXTAUTH_URL)
# This assumes the ALB created by the setup script still exists and has the same name
echo "Fetching ALB DNS name..."
ALB_DNS_NAME=$(aws elbv2 describe-load-balancers --names ${ALB_NAME} --query 'LoadBalancers[0].DNSName' --output text)
if [ -z "$ALB_DNS_NAME" ]; then
    echo "Error: Could not retrieve ALB DNS name. Ensure ALB '${ALB_NAME}' exists."
    exit 1
fi
echo "Using ALB DNS Name: ${ALB_DNS_NAME}"


# Register a new task definition revision using Secrets Manager
echo "Registering new task definition revision..."
# Construct the container definitions JSON string carefully
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

# Register the new revision
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

if [ -z "$TASK_DEFINITION_ARN" ]; then
    echo "Error: Failed to register new task definition revision."
    exit 1
fi
echo "Registered Task Definition Revision ARN: ${TASK_DEFINITION_ARN}"

# Update the service to use the latest task definition revision from the family
# and use the correct network configuration from sourced variables
echo "Updating ECS service ${SERVICE_NAME} to use latest task definition revision..."
aws ecs update-service \
    --cluster ${CLUSTER_NAME} \
    --service ${SERVICE_NAME} \
    --task-definition ${TASK_FAMILY} \
    --network-configuration "awsvpcConfiguration={subnets=[${PUBLIC_SUBNET_1_ID},${PUBLIC_SUBNET_2_ID}],securityGroups=[${APP_SG_ID}],assignPublicIp=ENABLED}" \
    --load-balancers "targetGroupArn=arn:aws:elasticloadbalancing:us-east-1:753561063721:targetgroup/feature-voting-app-tg/93e2cbdb1a142a2c,containerName=${CONTAINER_NAME},containerPort=${CONTAINER_PORT}" \
    --force-new-deployment \
    --health-check-grace-period-seconds 60

echo "ECS service update initiated. Deployment will proceed."
echo "Use 'aws ecs describe-services --cluster ${CLUSTER_NAME} --services ${SERVICE_NAME}' to check deployment status." 