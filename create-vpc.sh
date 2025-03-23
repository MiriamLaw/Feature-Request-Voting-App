#!/bin/bash

# Set variables
VPC_NAME="feature-voting-vpc"
AWS_REGION="us-east-1"

echo "Creating VPC..."
VPC_ID=$(aws ec2 create-vpc \
    --cidr-block 10.0.0.0/16 \
    --tag-specifications "ResourceType=vpc,Tags=[{Key=Name,Value=${VPC_NAME}}]" \
    --query 'Vpc.VpcId' \
    --output text)

echo "Enabling DNS hostnames for VPC..."
aws ec2 modify-vpc-attribute \
    --vpc-id ${VPC_ID} \
    --enable-dns-hostnames "{\"Value\":true}"

echo "Creating Internet Gateway..."
IGW_ID=$(aws ec2 create-internet-gateway \
    --tag-specifications "ResourceType=internet-gateway,Tags=[{Key=Name,Value=${VPC_NAME}-igw}]" \
    --query 'InternetGateway.InternetGatewayId' \
    --output text)

echo "Attaching Internet Gateway to VPC..."
aws ec2 attach-internet-gateway \
    --vpc-id ${VPC_ID} \
    --internet-gateway-id ${IGW_ID}

# Create public subnets (across 2 AZs for high availability)
echo "Creating public subnets..."
PUBLIC_SUBNET_1_ID=$(aws ec2 create-subnet \
    --vpc-id ${VPC_ID} \
    --cidr-block 10.0.1.0/24 \
    --availability-zone ${AWS_REGION}a \
    --tag-specifications "ResourceType=subnet,Tags=[{Key=Name,Value=${VPC_NAME}-public-1}]" \
    --query 'Subnet.SubnetId' \
    --output text)

PUBLIC_SUBNET_2_ID=$(aws ec2 create-subnet \
    --vpc-id ${VPC_ID} \
    --cidr-block 10.0.2.0/24 \
    --availability-zone ${AWS_REGION}b \
    --tag-specifications "ResourceType=subnet,Tags=[{Key=Name,Value=${VPC_NAME}-public-2}]" \
    --query 'Subnet.SubnetId' \
    --output text)

# Enable auto-assign public IP on public subnets
aws ec2 modify-subnet-attribute \
    --subnet-id ${PUBLIC_SUBNET_1_ID} \
    --map-public-ip-on-launch

aws ec2 modify-subnet-attribute \
    --subnet-id ${PUBLIC_SUBNET_2_ID} \
    --map-public-ip-on-launch

# Create route table for public subnets
echo "Creating route table for public subnets..."
PUBLIC_RTB_ID=$(aws ec2 create-route-table \
    --vpc-id ${VPC_ID} \
    --tag-specifications "ResourceType=route-table,Tags=[{Key=Name,Value=${VPC_NAME}-public-rtb}]" \
    --query 'RouteTable.RouteTableId' \
    --output text)

# Add route to the internet through the Internet Gateway
aws ec2 create-route \
    --route-table-id ${PUBLIC_RTB_ID} \
    --destination-cidr-block 0.0.0.0/0 \
    --gateway-id ${IGW_ID}

# Associate public subnets with the public route table
echo "Associating public subnets with route table..."
aws ec2 associate-route-table \
    --subnet-id ${PUBLIC_SUBNET_1_ID} \
    --route-table-id ${PUBLIC_RTB_ID}

aws ec2 associate-route-table \
    --subnet-id ${PUBLIC_SUBNET_2_ID} \
    --route-table-id ${PUBLIC_RTB_ID}

# Create security group for the application
echo "Creating security group for the application..."
APP_SG_ID=$(aws ec2 create-security-group \
    --group-name "${VPC_NAME}-app-sg" \
    --description "Security group for feature voting app" \
    --vpc-id ${VPC_ID} \
    --query 'GroupId' \
    --output text)

# Allow inbound HTTP and HTTPS traffic
aws ec2 authorize-security-group-ingress \
    --group-id ${APP_SG_ID} \
    --protocol tcp \
    --port 80 \
    --cidr 0.0.0.0/0

aws ec2 authorize-security-group-ingress \
    --group-id ${APP_SG_ID} \
    --protocol tcp \
    --port 443 \
    --cidr 0.0.0.0/0

# Create security group for the database
echo "Creating security group for the database..."
DB_SG_ID=$(aws ec2 create-security-group \
    --group-name "${VPC_NAME}-db-sg" \
    --description "Security group for MySQL database" \
    --vpc-id ${VPC_ID} \
    --query 'GroupId' \
    --output text)

# Allow MySQL traffic from the application security group
aws ec2 authorize-security-group-ingress \
    --group-id ${DB_SG_ID} \
    --protocol tcp \
    --port 3306 \
    --source-group ${APP_SG_ID}

# Output important IDs to be used in subsequent scripts
echo "VPC_ID=${VPC_ID}" > vpc-output.env
echo "PUBLIC_SUBNET_1_ID=${PUBLIC_SUBNET_1_ID}" >> vpc-output.env
echo "PUBLIC_SUBNET_2_ID=${PUBLIC_SUBNET_2_ID}" >> vpc-output.env
echo "APP_SG_ID=${APP_SG_ID}" >> vpc-output.env
echo "DB_SG_ID=${DB_SG_ID}" >> vpc-output.env

echo "VPC infrastructure created successfully!"
echo "VPC ID: ${VPC_ID}"
echo "Public Subnet 1 ID: ${PUBLIC_SUBNET_1_ID}"
echo "Public Subnet 2 ID: ${PUBLIC_SUBNET_2_ID}"
echo "App Security Group ID: ${APP_SG_ID}"
echo "DB Security Group ID: ${DB_SG_ID}"