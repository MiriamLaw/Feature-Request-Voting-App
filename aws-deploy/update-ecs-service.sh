#!/bin/bash

# Set variables
CLUSTER_NAME="feature-voting-cluster"
SERVICE_NAME="feature-voting-service"
TASK_FAMILY="feature-voting-app-task"

# Get the latest task definition ARN
TASK_DEFINITION=$(aws ecs describe-task-definition \
    --task-definition ${TASK_FAMILY} \
    --query 'taskDefinition.taskDefinitionArn' \
    --output text)

echo "Updating ECS service with task definition: ${TASK_DEFINITION}"

# Update the service with the new task definition
aws ecs update-service \
    --cluster ${CLUSTER_NAME} \
    --service ${SERVICE_NAME} \
    --task-definition ${TASK_DEFINITION} \
    --health-check-grace-period-seconds 120 \
    --force-new-deployment

echo "Service update initiated successfully!"
echo "You can monitor the deployment status in the AWS ECS console." 