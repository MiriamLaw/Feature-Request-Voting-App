#!/bin/bash

# Source existing environment variables
source vpc-output.env
source rds-output.env
source secrets-output.env

# Set variables
APP_NAME="feature-voting-app"
CLUSTER_NAME="feature-voting-cluster"
SERVICE_NAME="feature-voting-app-service"
TASK_FAMILY="feature-voting-app-task"
CONTAINER_NAME="feature-voting-app"
CONTAINER_PORT=3000
ALB_NAME="feature-voting-app-lb"
TARGET_GROUP_NAME="feature-voting-app-tg"

# Get AWS account ID
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

# Create Application Load Balancer
echo "Creating Application Load Balancer..."
ALB_ARN=$(aws elbv2 create-load-balancer \
    --name ${ALB_NAME} \
    --subnets ${PUBLIC_SUBNET_1_ID} ${PUBLIC_SUBNET_2_ID} \
    --security-groups ${APP_SG_ID} \
    --scheme internet-facing \
    --type application \
    --query 'LoadBalancers[0].LoadBalancerArn' \
    --output text)

# Create target group
echo "Creating target group..."
TARGET_GROUP_ARN=$(aws elbv2 create-target-group \
    --name ${TARGET_GROUP_NAME} \
    --protocol HTTP \
    --port ${CONTAINER_PORT} \
    --vpc-id ${VPC_ID} \
    --target-type ip \
    --health-check-path "/" \
    --health-check-interval-seconds 30 \
    --health-check-timeout-seconds 5 \
    --healthy-threshold-count 2 \
    --unhealthy-threshold-count 2 \
    --query 'TargetGroups[0].TargetGroupArn' \
    --output text)

# Create listener for HTTP
echo "Creating HTTP listener..."
aws elbv2 create-listener \
    --load-balancer-arn ${ALB_ARN} \
    --protocol HTTP \
    --port 80 \
    --default-actions Type=forward,TargetGroupArn=${TARGET_GROUP_ARN}

# Create ECS cluster
echo "Creating ECS cluster..."
aws ecs create-cluster --cluster-name ${CLUSTER_NAME}

# Register task definition
echo "Registering task definition..."
TASK_DEFINITION_ARN=$(aws ecs register-task-definition \
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
                }
            ],
            \"logConfiguration\": {
                \"logDriver\": \"awslogs\",
                \"options\": {
                    \"awslogs-group\": \"/ecs/${APP_NAME}\",
                    \"awslogs-region\": \"${AWS_REGION}\",
                    \"awslogs-stream-prefix\": \"ecs\"
                }
            }
        }
    ]" \
    --query 'taskDefinition.taskDefinitionArn' \
    --output text)

# Create ECS service
echo "Creating ECS service..."
aws ecs create-service \
    --cluster ${CLUSTER_NAME} \
    --service-name ${SERVICE_NAME} \
    --task-definition ${TASK_DEFINITION_ARN} \
    --desired-count 1 \
    --launch-type FARGATE \
    --platform-version LATEST \
    --network-configuration "awsvpcConfiguration={subnets=[${PUBLIC_SUBNET_1_ID},${PUBLIC_SUBNET_2_ID}],securityGroups=[${APP_SG_ID}],assignPublicIp=ENABLED}" \
    --load-balancers "targetGroupArn=${TARGET_GROUP_ARN},containerName=${CONTAINER_NAME},containerPort=${CONTAINER_PORT}"

# Get the ALB DNS name
ALB_DNS_NAME=$(aws elbv2 describe-load-balancers \
    --names ${ALB_NAME} \
    --query 'LoadBalancers[0].DNSName' \
    --output text)

# Save ALB DNS name for later use
echo "ALB_DNS_NAME=${ALB_DNS_NAME}" > http-deploy-output.env

echo "HTTP deployment completed successfully!"
echo "You can access your application at: http://${ALB_DNS_NAME}" 