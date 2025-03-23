#!/bin/bash

# Source environment variables
source ecr-output.env
source rds-output.env
source secrets-output.env

# Get AWS account ID
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

# Set variables
TASK_FAMILY="feature-voting-app-task"
CONTAINER_NAME="feature-voting-app"
CONTAINER_PORT=3000

# Register new task definition
echo "Registering new task definition..."
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
            \"image\": \"${ECR_REPOSITORY_URI}:latest\",
            \"portMappings\": [
                {
                    \"containerPort\": ${CONTAINER_PORT},
                    \"protocol\": \"tcp\"
                }
            ],
            \"environment\": [
                {
                    \"name\": \"DATABASE_URL\",
                    \"value\": \"${DATABASE_URL}\"
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
                },
                {
                    \"name\": \"NODE_ENV\",
                    \"value\": \"production\"
                }
            ],
            \"healthCheck\": {
                \"command\": [
                    \"CMD-SHELL\",
                    \"curl -f http://localhost:${CONTAINER_PORT}/api/health || exit 1\"
                ],
                \"interval\": 30,
                \"timeout\": 5,
                \"retries\": 3,
                \"startPeriod\": 60
            },
            \"logConfiguration\": {
                \"logDriver\": \"awslogs\",
                \"options\": {
                    \"awslogs-group\": \"/ecs/feature-voting-app\",
                    \"awslogs-region\": \"us-east-1\",
                    \"awslogs-stream-prefix\": \"ecs\"
                }
            }
        }
    ]"

echo "Task definition updated successfully!" 