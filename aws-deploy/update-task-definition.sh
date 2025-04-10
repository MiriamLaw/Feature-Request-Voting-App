#!/bin/bash

# Set variables
APP_NAME="feature-voting-app"
CLUSTER_NAME="feature-voting-cluster"
SERVICE_NAME="feature-voting-app-service"
ALB_NAME="feature-voting-app-lb"
TARGET_GROUP_NAME="feature-voting-app-tg"
SECRET_ARN="arn:aws:secretsmanager:us-east-1:753561063721:secret:feature-voting-app-secrets-Zbqr22"

# Get AWS account ID
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

# Get ALB DNS name
ALB_DNS_NAME=$(aws elbv2 describe-load-balancers --names $ALB_NAME --query 'LoadBalancers[0].DNSName' --output text)

# Register new task definition
aws ecs register-task-definition \
    --family ${APP_NAME}-task \
    --network-mode awsvpc \
    --requires-compatibilities FARGATE \
    --cpu 256 \
    --memory 512 \
    --task-role-arn arn:aws:iam::${AWS_ACCOUNT_ID}:role/ecsTaskExecutionRole \
    --execution-role-arn arn:aws:iam::${AWS_ACCOUNT_ID}:role/ecsTaskExecutionRole \
    --container-definitions "[
        {
            \"name\": \"${APP_NAME}\",
            \"image\": \"${AWS_ACCOUNT_ID}.dkr.ecr.us-east-1.amazonaws.com/${APP_NAME}:latest\",
            \"cpu\": 256,
            \"memory\": 512,
            \"portMappings\": [
                {
                    \"containerPort\": 3000,
                    \"hostPort\": 3000,
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
                    \"name\": \"NEXTAUTH_URL\",
                    \"value\": \"http://${ALB_DNS_NAME}\"
                }
            ],
            \"secrets\": [
                {
                    \"name\": \"DATABASE_URL\",
                    \"valueFrom\": \"${SECRET_ARN}:DATABASE_URL::\"
                },
                {
                    \"name\": \"NEXTAUTH_SECRET\",
                    \"valueFrom\": \"${SECRET_ARN}:NEXTAUTH_SECRET::\"
                },
                {
                    \"name\": \"GOOGLE_ID\",
                    \"valueFrom\": \"${SECRET_ARN}:GOOGLE_ID::\"
                },
                {
                    \"name\": \"GOOGLE_SECRET\",
                    \"valueFrom\": \"${SECRET_ARN}:GOOGLE_SECRET::\"
                }
            ],
            \"logConfiguration\": {
                \"logDriver\": \"awslogs\",
                \"options\": {
                    \"awslogs-group\": \"/ecs/${APP_NAME}\",
                    \"awslogs-region\": \"us-east-1\",
                    \"awslogs-stream-prefix\": \"ecs\"
                }
            }
        }
    ]"

# Get the new task definition ARN
NEW_TASK_DEF_ARN=$(aws ecs describe-task-definition \
    --task-definition ${APP_NAME}-task \
    --query 'taskDefinition.taskDefinitionArn' \
    --output text)

# Update the service to use the new task definition
aws ecs update-service \
    --cluster ${CLUSTER_NAME} \
    --service ${SERVICE_NAME} \
    --task-definition ${NEW_TASK_DEF_ARN}

echo "Task definition updated and service is being updated with the new task definition." 