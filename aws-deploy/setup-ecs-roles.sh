#!/bin/bash

# Get AWS account ID
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

# Create ECS task execution role
echo "Creating ECS task execution role..."
aws iam create-role \
    --role-name ecsTaskExecutionRole \
    --assume-role-policy-document '{
        "Version": "2012-10-17",
        "Statement": [
            {
                "Effect": "Allow",
                "Principal": {
                    "Service": "ecs-tasks.amazonaws.com"
                },
                "Action": "sts:AssumeRole"
            }
        ]
    }' || true

# Attach the AWS managed policy for ECS task execution
echo "Attaching ECS task execution policy..."
aws iam attach-role-policy \
    --role-name ecsTaskExecutionRole \
    --policy-arn arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy

# Create ECS service role
echo "Creating ECS service role..."
aws iam create-role \
    --role-name aws-service-role/ecs.amazonaws.com/AWSServiceRoleForECS \
    --assume-role-policy-document '{
        "Version": "2012-10-17",
        "Statement": [
            {
                "Effect": "Allow",
                "Principal": {
                    "Service": "ecs.amazonaws.com"
                },
                "Action": "sts:AssumeRole"
            }
        ]
    }' || true

# Attach the AWS managed policy for ECS service
echo "Attaching ECS service policy..."
aws iam attach-role-policy \
    --role-name aws-service-role/ecs.amazonaws.com/AWSServiceRoleForECS \
    --policy-arn arn:aws:iam::aws:policy/service-role/AmazonECSServiceRolePolicy

echo "ECS roles created successfully!" 