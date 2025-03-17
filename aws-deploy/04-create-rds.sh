#!/bin/bash

# Source VPC output variables
source vpc-output.env

# Set variables
DB_NAME="feature_voting"
DB_USERNAME="root"
DB_PASSWORD="NewSecurePassHundo"
DB_INSTANCE_CLASS="db.t3.micro"
DB_SUBNET_GROUP_NAME="feature-voting-db-subnet-group"
DB_INSTANCE_IDENTIFIER="feature-voting-db"

# Create DB subnet group with the public subnets
echo "Creating DB subnet group..."
aws rds create-db-subnet-group \
    --db-subnet-group-name ${DB_SUBNET_GROUP_NAME} \
    --db-subnet-group-description "Subnet group for feature voting app DB" \
    --subnet-ids ${PUBLIC_SUBNET_1_ID} ${PUBLIC_SUBNET_2_ID} \
    --tags Key=Name,Value=${DB_SUBNET_GROUP_NAME}

# Create RDS instance
echo "Creating RDS MySQL instance (this may take several minutes)..."
RDS_ENDPOINT=$(aws rds create-db-instance \
    --db-instance-identifier ${DB_INSTANCE_IDENTIFIER} \
    --db-instance-class ${DB_INSTANCE_CLASS} \
    --engine mysql \
    --engine-version 8.0 \
    --allocated-storage 20 \
    --db-name ${DB_NAME} \
    --master-username ${DB_USERNAME} \
    --master-user-password ${DB_PASSWORD} \
    --vpc-security-group-ids ${DB_SG_ID} \
    --db-subnet-group-name ${DB_SUBNET_GROUP_NAME} \
    --publicly-accessible \
    --backup-retention-period 1 \
    --no-multi-az \
    --port 3306 \
    --no-auto-minor-version-upgrade \
    --tags Key=Name,Value=${DB_INSTANCE_IDENTIFIER} \
    --query 'DBInstance.Endpoint.Address' \
    --output text)

# This will fail initially since the RDS instance takes time to create
# We need to wait for the RDS instance to be available
echo "Waiting for RDS instance to be available (this may take 5-10 minutes)..."
aws rds wait db-instance-available --db-instance-identifier ${DB_INSTANCE_IDENTIFIER}

# Get the RDS endpoint
RDS_ENDPOINT=$(aws rds describe-db-instances \
    --db-instance-identifier ${DB_INSTANCE_IDENTIFIER} \
    --query 'DBInstances[0].Endpoint.Address' \
    --output text)

# Save RDS info for later use
echo "RDS_ENDPOINT=${RDS_ENDPOINT}" > rds-output.env
echo "DB_NAME=${DB_NAME}" >> rds-output.env
echo "DB_USERNAME=${DB_USERNAME}" >> rds-output.env
echo "DB_PASSWORD=${DB_PASSWORD}" >> rds-output.env

echo "RDS MySQL instance created successfully!"
echo "RDS Endpoint: ${RDS_ENDPOINT}"
echo "Database Name: ${DB_NAME}"
echo "Username: ${DB_USERNAME}" 