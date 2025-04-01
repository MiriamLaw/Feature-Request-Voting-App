#!/bin/bash

# Change to the aws-deploy directory
cd "$(dirname "$0")"

# Source environment files
if [ ! -f "vpc-output.env" ] || [ ! -f "rds-output.env" ] || [ ! -f "secrets-output.env" ]; then
    echo "Error: Required environment files are missing. Please ensure vpc-output.env, rds-output.env, and secrets-output.env exist."
    exit 1
fi

source vpc-output.env
source rds-output.env
source secrets-output.env

# Set variables
APP_NAME="feature-voting-app"
CLUSTER_NAME="feature-voting-cluster"
SERVICE_NAME="feature-voting-app-service"
TASK_FAMILY="feature-voting-app-task"
CONTAINER_NAME="feature-voting-app"
CONTAINER_PORT=80

# Get AWS account ID
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

# Get the ALB DNS name
ALB_DNS_NAME=$(aws elbv2 describe-load-balancers --names feature-voting-app-lb --query 'LoadBalancers[0].DNSName' --output text)

# Register a new task definition without CloudWatch logging
aws ecs register-task-definition \
    --family ${TASK_FAMILY} \
    --network-mode awsvpc \
    --requires-compatibilities FARGATE \
    --cpu 256 \
    --memory 512 \
    --execution-role-arn arn:aws:iam::${AWS_ACCOUNT_ID}:role/ecsTaskExecutionRole \
    --task-role-arn arn:aws:iam::${AWS_ACCOUNT_ID}:role/ecsTaskExecutionRole \
    --container-definitions "[
        {
            \"name\": \"${CONTAINER_NAME}\",
            \"image\": \"${AWS_ACCOUNT_ID}.dkr.ecr.us-east-1.amazonaws.com/feature-voting-app:latest\",
            \"portMappings\": [
                {
                    \"containerPort\": ${CONTAINER_PORT},
                    \"protocol\": \"tcp\"
                }
            ],
            \"essential\": true,
            \"environment\": [
                {
                    \"name\": \"NODE_ENV\",
                    \"value\": \"production\"
                },
                {
                    \"name\": \"DATABASE_URL\",
                    \"value\": \"${DATABASE_URL}\"
                },
                {
                    \"name\": \"NEXTAUTH_URL\",
                    \"value\": \"http://${ALB_DNS_NAME}\"
                },
                {
                    \"name\": \"NEXTAUTH_SECRET\",
                    \"value\": \"${NEXTAUTH_SECRET}\"
                },
                {
                    \"name\": \"GOOGLE_ID\",
                    \"value\": \"${GOOGLE_ID}\"
                },
                {
                    \"name\": \"GOOGLE_SECRET\",
                    \"value\": \"${GOOGLE_SECRET}\"
                }
            ],
            \"healthCheck\": {
                \"command\": [
                    \"CMD-SHELL\",
                    \"curl -f http://localhost:80/api/health || exit 1\"
                ],
                \"interval\": 30,
                \"timeout\": 5,
                \"retries\": 3,
                \"startPeriod\": 60
            }
        }
    ]"

# Update the service to use the new task definition and the working subnet
aws ecs update-service \
    --cluster ${CLUSTER_NAME} \
    --service ${SERVICE_NAME} \
    --task-definition ${TASK_FAMILY} \
    --network-configuration "awsvpcConfiguration={subnets=[subnet-029179805ee7fd6cb],securityGroups=[sg-069a8472395a06744],assignPublicIp=ENABLED}" \
    --force-new-deployment

echo "Task definition updated and service deployment initiated." 