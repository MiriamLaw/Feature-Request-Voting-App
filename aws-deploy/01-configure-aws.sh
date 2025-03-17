#!/bin/bash

echo "Configuring AWS CLI..."
echo "Please enter your AWS credentials when prompted."
echo ""

# Prompt for AWS credentials instead of hardcoding them
read -p "Enter your AWS Access Key ID: " AWS_ACCESS_KEY_ID
read -sp "Enter your AWS Secret Access Key: " AWS_SECRET_ACCESS_KEY
echo ""  # Add a newline after the secret input

# Set AWS configuration
aws configure set aws_access_key_id $AWS_ACCESS_KEY_ID
aws configure set aws_secret_access_key $AWS_SECRET_ACCESS_KEY
aws configure set default.region us-east-1
aws configure set default.output json

echo "AWS CLI configuration complete!" 