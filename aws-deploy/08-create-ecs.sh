#!/bin/bash

# Source output variables from previous scripts
source vpc-output.env
source secrets-output.env

# Set variables
AWS_REGION="us-east-1"
CLUSTER_NAME="feature-voting-cluster"
APP_NAME="feature-voting-app"
TASK_FAMILY="feature-voting-task"
ECR_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
ECR_REPOSITORY_URI="${ECR_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${APP_NAME}"
EXECUTION_ROLE_NAME="ecsTaskExecutionRole-${APP_NAME}"
TASK_ROLE_NAME="ecsTaskRole-${APP_NAME}"

# Create ECS cluster
echo "Creating ECS cluster..."
aws ecs create-cluster \
    --cluster-name ${CLUSTER_NAME} \
    --region ${AWS_REGION} \
    --tags key=Name,value=${CLUSTER_NAME}

# Create ECS task execution role
echo "Creating ECS task execution role..."
EXECUTION_ROLE_POLICY=$(cat <<EOF
{
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
}
EOF
)

EXECUTION_ROLE_ARN=$(aws iam create-role \
    --role-name ${EXECUTION_ROLE_NAME} \
    --assume-role-policy-document "${EXECUTION_ROLE_POLICY}" \
    --query 'Role.Arn' \
    --output text)

# Attach AmazonECSTaskExecutionRolePolicy to the execution role
aws iam attach-role-policy \
    --role-name ${EXECUTION_ROLE_NAME} \
    --policy-arn arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy

# Create ECS task role with permissions to access Secrets Manager
echo "Creating ECS task role..."
TASK_ROLE_POLICY=$(cat <<EOF
{
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
}
EOF
)

TASK_ROLE_ARN=$(aws iam create-role \
    --role-name ${TASK_ROLE_NAME} \
    --assume-role-policy-document "${TASK_ROLE_POLICY}" \
    --query 'Role.Arn' \
    --output text)

# Create a policy that allows access to the specific secret
SECRETS_POLICY=$(cat <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "secretsmanager:GetSecretValue"
      ],
      "Resource": [
        "${SECRET_ARN}"
      ]
    }
  ]
}
EOF
)

# Create the inline policy for secrets access
aws iam put-role-policy \
    --role-name ${TASK_ROLE_NAME} \
    --policy-name SecretsAccessPolicy \
    --policy-document "${SECRETS_POLICY}"

# Create the log group for the ECS task
echo "Creating CloudWatch log group..."
aws logs create-log-group \
    --log-group-name "/ecs/${APP_NAME}" \
    --region ${AWS_REGION}

# Create ECS task definition with secretOptions
echo "Creating ECS task definition..."
TASK_DEFINITION=$(cat <<EOF
{
  "family": "${TASK_FAMILY}",
  "executionRoleArn": "${EXECUTION_ROLE_ARN}",
  "taskRoleArn": "${TASK_ROLE_ARN}",
  "networkMode": "awsvpc",
  "requiresCompatibilities": ["FARGATE"],
  "cpu": "256",
  "memory": "512",
  "containerDefinitions": [
    {
      "name": "${APP_NAME}",
      "image": "${ECR_REPOSITORY_URI}:latest",
      "essential": true,
      "portMappings": [
        {
          "containerPort": 3000,
          "hostPort": 3000,
          "protocol": "tcp"
        }
      ],
      "logConfiguration": {
        "logDriver": "awslogs",
        "options": {
          "awslogs-group": "/ecs/${APP_NAME}",
          "awslogs-region": "${AWS_REGION}",
          "awslogs-stream-prefix": "ecs"
        }
      },
      "secrets": [
        {
          "name": "DATABASE_URL",
          "valueFrom": "${SECRET_ARN}:DATABASE_URL::"
        },
        {
          "name": "NEXTAUTH_SECRET",
          "valueFrom": "${SECRET_ARN}:NEXTAUTH_SECRET::"
        },
        {
          "name": "NEXTAUTH_URL",
          "valueFrom": "${SECRET_ARN}:NEXTAUTH_URL::"
        },
        {
          "name": "GOOGLE_ID",
          "valueFrom": "${SECRET_ARN}:GOOGLE_ID::"
        },
        {
          "name": "GOOGLE_SECRET",
          "valueFrom": "${SECRET_ARN}:GOOGLE_SECRET::"
        }
      ]
    }
  ]
}
EOF
)

TASK_DEFINITION_ARN=$(aws ecs register-task-definition \
    --cli-input-json "${TASK_DEFINITION}" \
    --region ${AWS_REGION} \
    --query 'taskDefinition.taskDefinitionArn' \
    --output text)

# Create Application Load Balancer
echo "Creating security group for the load balancer..."
LB_SG_ID=$(aws ec2 create-security-group \
    --group-name "${APP_NAME}-lb-sg" \
    --description "Security group for ${APP_NAME} load balancer" \
    --vpc-id ${VPC_ID} \
    --query 'GroupId' \
    --output text)

# Allow inbound HTTP and HTTPS traffic to the load balancer
aws ec2 authorize-security-group-ingress \
    --group-id ${LB_SG_ID} \
    --protocol tcp \
    --port 80 \
    --cidr 0.0.0.0/0

aws ec2 authorize-security-group-ingress \
    --group-id ${LB_SG_ID} \
    --protocol tcp \
    --port 443 \
    --cidr 0.0.0.0/0

# Allow traffic from the load balancer to the application
aws ec2 authorize-security-group-ingress \
    --group-id ${APP_SG_ID} \
    --protocol tcp \
    --port 3000 \
    --source-group ${LB_SG_ID}

echo "Creating Application Load Balancer..."
LB_ARN=$(aws elbv2 create-load-balancer \
    --name "${APP_NAME}-lb" \
    --subnets ${PUBLIC_SUBNET_1_ID} ${PUBLIC_SUBNET_2_ID} \
    --security-groups ${LB_SG_ID} \
    --type application \
    --region ${AWS_REGION} \
    --query 'LoadBalancers[0].LoadBalancerArn' \
    --output text)

# Create target group
echo "Creating target group..."
TG_ARN=$(aws elbv2 create-target-group \
    --name "${APP_NAME}-tg" \
    --protocol HTTP \
    --port 3000 \
    --vpc-id ${VPC_ID} \
    --target-type ip \
    --health-check-path "/" \
    --health-check-interval-seconds 30 \
    --health-check-timeout-seconds 5 \
    --healthy-threshold-count 2 \
    --unhealthy-threshold-count 2 \
    --region ${AWS_REGION} \
    --query 'TargetGroups[0].TargetGroupArn' \
    --output text)

# Create HTTP listener that redirects to HTTPS
echo "Creating HTTP listener (redirects to HTTPS)..."
HTTP_LISTENER_ARN=$(aws elbv2 create-listener \
    --load-balancer-arn ${LB_ARN} \
    --protocol HTTP \
    --port 80 \
    --default-actions Type=redirect,RedirectConfig="{Protocol=HTTPS,Port=443,StatusCode=HTTP_301}" \
    --region ${AWS_REGION} \
    --query 'Listeners[0].ListenerArn' \
    --output text)

# For now, create HTTP listener that forwards to target group
# (We'll replace this with HTTPS once certificate is validated)
echo "Creating temporary HTTP listener (forwards to target group)..."
TEMP_LISTENER_ARN=$(aws elbv2 create-listener \
    --load-balancer-arn ${LB_ARN} \
    --protocol HTTP \
    --port 8080 \
    --default-actions Type=forward,TargetGroupArn=${TG_ARN} \
    --region ${AWS_REGION} \
    --query 'Listeners[0].ListenerArn' \
    --output text)

# Get the load balancer DNS name
LB_DNS_NAME=$(aws elbv2 describe-load-balancers \
    --load-balancer-arns ${LB_ARN} \
    --query 'LoadBalancers[0].DNSName' \
    --output text)

# Create ECS service
echo "Creating ECS service..."
SERVICE_ARN=$(aws ecs create-service \
    --cluster ${CLUSTER_NAME} \
    --service-name ${APP_NAME}-service \
    --task-definition ${TASK_DEFINITION_ARN} \
    --desired-count 1 \
    --launch-type FARGATE \
    --platform-version LATEST \
    --scheduling-strategy REPLICA \
    --deployment-configuration maximumPercent=200,minimumHealthyPercent=100 \
    --network-configuration "awsvpcConfiguration={subnets=[${PUBLIC_SUBNET_1_ID},${PUBLIC_SUBNET_2_ID}],securityGroups=[${APP_SG_ID}],assignPublicIp=ENABLED}" \
    --load-balancers "targetGroupArn=${TG_ARN},containerName=${APP_NAME},containerPort=3000" \
    --region ${AWS_REGION} \
    --query 'service.serviceArn' \
    --output text)

# Save resources for later use
echo "CLUSTER_NAME=${CLUSTER_NAME}" > ecs-output.env
echo "SERVICE_NAME=${APP_NAME}-service" >> ecs-output.env
echo "TASK_DEFINITION_ARN=${TASK_DEFINITION_ARN}" >> ecs-output.env
echo "LB_ARN=${LB_ARN}" >> ecs-output.env
echo "TG_ARN=${TG_ARN}" >> ecs-output.env
echo "HTTP_LISTENER_ARN=${HTTP_LISTENER_ARN}" >> ecs-output.env
echo "TEMP_LISTENER_ARN=${TEMP_LISTENER_ARN}" >> ecs-output.env
echo "LB_DNS_NAME=${LB_DNS_NAME}" >> ecs-output.env

echo "ECS infrastructure created successfully!"
echo "ECS Cluster: ${CLUSTER_NAME}"
echo "ECS Service: ${APP_NAME}-service"
echo "Load Balancer DNS: ${LB_DNS_NAME}"
echo ""
echo "You can access your application at: http://${LB_DNS_NAME}"
echo ""
echo "IMPORTANT: Run the next script to set up HTTPS with your validated certificate and update DNS records." 