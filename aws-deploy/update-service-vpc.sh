#!/bin/bash

# Get the security group ID from the current service
SECURITY_GROUP=$(aws ecs describe-services \
    --cluster feature-voting-cluster \
    --services feature-voting-app-service \
    --query 'services[0].networkConfiguration.awsvpcConfiguration.securityGroups[0]' \
    --output text)

# Update the service to use default VPC subnets
aws ecs update-service \
    --cluster feature-voting-cluster \
    --service feature-voting-app-service \
    --network-configuration "awsvpcConfiguration={subnets=[subnet-0de2f7145fd021a2c,subnet-09c471ebed1610cfc],securityGroups=[${SECURITY_GROUP}],assignPublicIp=ENABLED}"

echo "Service updated to use default VPC subnets. Please wait for the deployment to complete..." 