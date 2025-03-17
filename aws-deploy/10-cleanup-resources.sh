#!/bin/bash

# Source all output variables
if [ -f vpc-output.env ]; then
    source vpc-output.env
fi

if [ -f rds-output.env ]; then
    source rds-output.env
fi

if [ -f secrets-output.env ]; then
    source secrets-output.env
fi

if [ -f certificate-output.env ]; then
    source certificate-output.env
fi

if [ -f route53-output.env ]; then
    source route53-output.env
fi

if [ -f ecs-output.env ]; then
    source ecs-output.env
fi

# Set variables
AWS_REGION="us-east-1"
APP_NAME="feature-voting-app"
ECR_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
ECR_REPOSITORY_URI="${ECR_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${APP_NAME}"
EXECUTION_ROLE_NAME="ecsTaskExecutionRole-${APP_NAME}"
TASK_ROLE_NAME="ecsTaskRole-${APP_NAME}"

# Use the domain from previous scripts or default
if [ -z "$DOMAIN" ]; then
    DOMAIN="feature-voting-app.example.com"  # Default if not set
    echo "No domain found in env files, using default: ${DOMAIN}"
fi

echo "WARNING: This script will delete ALL resources created for the feature voting app."
echo "This action cannot be undone. Data may be lost."
read -p "Are you sure you want to continue? (y/n): " CONFIRM

if [[ $CONFIRM != "y" ]]; then
    echo "Cleanup cancelled."
    exit 1
fi

# 1. Delete ECS service and cluster
echo "Deleting ECS service..."
if [ ! -z "$CLUSTER_NAME" ] && [ ! -z "$SERVICE_NAME" ]; then
    aws ecs update-service --cluster ${CLUSTER_NAME} --service ${SERVICE_NAME} --desired-count 0 --region ${AWS_REGION}
    aws ecs delete-service --cluster ${CLUSTER_NAME} --service ${SERVICE_NAME} --force --region ${AWS_REGION}
    echo "Waiting for service to be deleted..."
    sleep 60
    aws ecs delete-cluster --cluster ${CLUSTER_NAME} --region ${AWS_REGION}
fi

# 2. Delete load balancer, target groups, and listeners
echo "Deleting load balancer resources..."
if [ ! -z "$HTTP_LISTENER_ARN" ]; then
    aws elbv2 delete-listener --listener-arn ${HTTP_LISTENER_ARN} --region ${AWS_REGION}
fi

if [ ! -z "$TEMP_LISTENER_ARN" ]; then
    aws elbv2 delete-listener --listener-arn ${TEMP_LISTENER_ARN} --region ${AWS_REGION} 2>/dev/null || true
fi

if [ ! -z "$LB_ARN" ]; then
    aws elbv2 delete-load-balancer --load-balancer-arn ${LB_ARN} --region ${AWS_REGION}
    echo "Waiting for load balancer to be deleted..."
    sleep 60
fi

if [ ! -z "$TG_ARN" ]; then
    aws elbv2 delete-target-group --target-group-arn ${TG_ARN} --region ${AWS_REGION}
fi

# 3. Delete IAM roles and policies
echo "Deleting IAM roles..."
if [ ! -z "$EXECUTION_ROLE_NAME" ]; then
    aws iam detach-role-policy --role-name ${EXECUTION_ROLE_NAME} --policy-arn arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy
    aws iam delete-role --role-name ${EXECUTION_ROLE_NAME}
fi

if [ ! -z "$TASK_ROLE_NAME" ]; then
    aws iam delete-role-policy --role-name ${TASK_ROLE_NAME} --policy-name SecretsAccessPolicy
    aws iam delete-role --role-name ${TASK_ROLE_NAME}
fi

# 4. Delete Route 53 record
echo "Deleting Route 53 record..."
if [ ! -z "$HOSTED_ZONE_ID" ]; then
    CHANGE_BATCH=$(cat <<EOF
{
  "Changes": [
    {
      "Action": "DELETE",
      "ResourceRecordSet": {
        "Name": "${DOMAIN}",
        "Type": "A",
        "AliasTarget": {
          "HostedZoneId": "Z35SXDOTRQ7X7K",
          "DNSName": "${LB_DNS_NAME}",
          "EvaluateTargetHealth": true
        }
      }
    }
  ]
}
EOF
)
    aws route53 change-resource-record-sets --hosted-zone-id ${HOSTED_ZONE_ID} --change-batch "${CHANGE_BATCH}" || true
fi

# 5. Delete certificate
echo "Deleting ACM certificate..."
if [ ! -z "$CERTIFICATE_ARN" ]; then
    aws acm delete-certificate --certificate-arn ${CERTIFICATE_ARN} --region ${AWS_REGION} || true
fi

# 6. Delete secrets
echo "Deleting secrets..."
if [ ! -z "$SECRET_ARN" ]; then
    aws secretsmanager delete-secret --secret-id ${SECRET_ARN} --force-delete-without-recovery --region ${AWS_REGION}
fi

# 7. Delete RDS
echo "Deleting RDS instance (this may take several minutes)..."
if [ ! -z "$DB_INSTANCE_IDENTIFIER" ]; then
    aws rds delete-db-instance --db-instance-identifier ${DB_INSTANCE_IDENTIFIER} --skip-final-snapshot --delete-automated-backups --region ${AWS_REGION}
    echo "Waiting for RDS instance to be deleted..."
    aws rds wait db-instance-deleted --db-instance-identifier ${DB_INSTANCE_IDENTIFIER} --region ${AWS_REGION}
    aws rds delete-db-subnet-group --db-subnet-group-name feature-voting-db-subnet-group --region ${AWS_REGION} || true
fi

# 8. Delete security groups
echo "Deleting security groups..."
if [ ! -z "$APP_SG_ID" ]; then
    aws ec2 delete-security-group --group-id ${APP_SG_ID} --region ${AWS_REGION} || true
fi

if [ ! -z "$DB_SG_ID" ]; then
    aws ec2 delete-security-group --group-id ${DB_SG_ID} --region ${AWS_REGION} || true
fi

# Try to delete load balancer security group (may fail if LB is still deleting)
LB_SG_ID=$(aws ec2 describe-security-groups --filters Name=group-name,Values=${APP_NAME}-lb-sg --query 'SecurityGroups[0].GroupId' --output text --region ${AWS_REGION})
if [ "$LB_SG_ID" != "None" ] && [ ! -z "$LB_SG_ID" ]; then
    aws ec2 delete-security-group --group-id ${LB_SG_ID} --region ${AWS_REGION} || true
fi

# 9. Delete VPC resources
echo "Deleting VPC resources..."
if [ ! -z "$VPC_ID" ]; then
    # Delete subnets
    if [ ! -z "$PUBLIC_SUBNET_1_ID" ]; then
        aws ec2 delete-subnet --subnet-id ${PUBLIC_SUBNET_1_ID} --region ${AWS_REGION}
    fi
    
    if [ ! -z "$PUBLIC_SUBNET_2_ID" ]; then
        aws ec2 delete-subnet --subnet-id ${PUBLIC_SUBNET_2_ID} --region ${AWS_REGION}
    fi
    
    # Delete route tables
    ROUTE_TABLES=$(aws ec2 describe-route-tables --filters Name=vpc-id,Values=${VPC_ID} --query 'RouteTables[?Associations[0].Main!=`true`].RouteTableId' --output text --region ${AWS_REGION})
    for RT_ID in ${ROUTE_TABLES}; do
        aws ec2 delete-route-table --route-table-id ${RT_ID} --region ${AWS_REGION} || true
    done
    
    # Detach and delete internet gateway
    IGW_ID=$(aws ec2 describe-internet-gateways --filters Name=attachment.vpc-id,Values=${VPC_ID} --query 'InternetGateways[0].InternetGatewayId' --output text --region ${AWS_REGION})
    if [ "$IGW_ID" != "None" ] && [ ! -z "$IGW_ID" ]; then
        aws ec2 detach-internet-gateway --internet-gateway-id ${IGW_ID} --vpc-id ${VPC_ID} --region ${AWS_REGION}
        aws ec2 delete-internet-gateway --internet-gateway-id ${IGW_ID} --region ${AWS_REGION}
    fi
    
    # Delete VPC
    aws ec2 delete-vpc --vpc-id ${VPC_ID} --region ${AWS_REGION}
fi

# 10. Delete ECR repository
echo "Deleting ECR repository..."
aws ecr delete-repository --repository-name ${APP_NAME} --force --region ${AWS_REGION} || true

# 11. Delete CloudWatch logs
echo "Deleting CloudWatch log group..."
aws logs delete-log-group --log-group-name /ecs/${APP_NAME} --region ${AWS_REGION} || true

# 12. Remove output files
echo "Removing output files..."
rm -f vpc-output.env rds-output.env secrets-output.env certificate-output.env route53-output.env ecs-output.env domain-output.env

echo "Cleanup completed successfully!" 