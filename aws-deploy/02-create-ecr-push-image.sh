#!/bin/bash

# Set variables
APP_NAME="feature-voting-app"
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
AWS_REGION="us-east-1"
ECR_REPOSITORY_URI="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${APP_NAME}"

echo "Creating ECR repository..."
aws ecr create-repository \
    --repository-name ${APP_NAME} \
    --image-scanning-configuration scanOnPush=true \
    --region ${AWS_REGION}

echo "Logging into ECR..."
aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com

echo "Building Docker image..."
docker build -t ${APP_NAME}:latest .

echo "Tagging Docker image..."
docker tag ${APP_NAME}:latest ${ECR_REPOSITORY_URI}:latest

echo "Pushing Docker image to ECR..."
docker push ${ECR_REPOSITORY_URI}:latest

echo "Image successfully pushed to ECR at ${ECR_REPOSITORY_URI}:latest" 