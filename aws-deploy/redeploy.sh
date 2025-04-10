#!/bin/bash

# This script helps redeploy the application with the fixes

# Build and push the Docker image
echo "Building and pushing Docker image..."
docker build -t feature-voting-app .
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin $(aws sts get-caller-identity --query Account --output text).dkr.ecr.us-east-1.amazonaws.com
docker tag feature-voting-app:latest $(aws sts get-caller-identity --query Account --output text).dkr.ecr.us-east-1.amazonaws.com/feature-voting-app:latest
docker push $(aws sts get-caller-identity --query Account --output text).dkr.ecr.us-east-1.amazonaws.com/feature-voting-app:latest

# Update the task definition
echo "Updating task definition..."
./aws-deploy/update-task-definition.sh

# Update the service
echo "Updating service..."
./aws-deploy/update-ecs-service.sh

echo "Redeployment initiated. Check the status with:"
echo "aws ecs describe-services --cluster feature-voting-cluster --services feature-voting-app-service" 