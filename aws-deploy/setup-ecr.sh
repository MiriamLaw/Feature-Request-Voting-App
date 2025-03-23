#!/bin/bash

# Set variables
APP_NAME="feature-voting-app"
AWS_REGION="us-east-1"

# Get AWS account ID
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

# Create ECR repository if it doesn't exist
echo "Creating ECR repository..."
aws ecr create-repository \
    --repository-name ${APP_NAME} \
    --image-scanning-configuration scanOnPush=true \
    --region ${AWS_REGION} || true

# Get ECR login token and login to Docker
echo "Logging into ECR..."
aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com

# Build the Docker image
echo "Building Docker image..."
docker build -t ${APP_NAME}:latest ..

# Tag the image for ECR
echo "Tagging Docker image..."
docker tag ${APP_NAME}:latest ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${APP_NAME}:latest

# Push the image to ECR
echo "Pushing image to ECR..."
docker push ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${APP_NAME}:latest

# Save ECR repository URI for later use
ECR_REPOSITORY_URI="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${APP_NAME}"
echo "ECR_REPOSITORY_URI=${ECR_REPOSITORY_URI}" > ecr-output.env

echo "Docker image pushed successfully!"
echo "ECR Repository URI: ${ECR_REPOSITORY_URI}" 