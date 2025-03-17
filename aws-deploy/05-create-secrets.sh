#!/bin/bash

# Source RDS output variables
source rds-output.env

# Load environment variables from .env file
if [ -f "../.env" ]; then
    echo "Loading environment variables from .env file..."
    export $(grep -v '^#' ../.env | xargs)
fi

# Set variables
AWS_REGION="us-east-1"
SECRET_NAME="feature-voting-app-secrets"

# Use existing NEXTAUTH_SECRET or generate a new one
if [ -z "$NEXTAUTH_SECRET" ]; then
    echo "No NEXTAUTH_SECRET found in .env, generating one..."
    NEXTAUTH_SECRET=$(openssl rand -base64 32)
    echo "Generated NEXTAUTH_SECRET for you."
else
    echo "Using NEXTAUTH_SECRET from .env file."
fi

# Set the domain
echo ""
read -p "Enter the domain for your app (default: feature-voting-app.example.com): " DOMAIN
if [ -z "$DOMAIN" ]; then
    DOMAIN="feature-voting-app.example.com"
fi

# Create a JSON string with the app secrets
SECRETS_JSON=$(cat <<EOF
{
  "DATABASE_URL": "mysql://${DB_USERNAME}:${DB_PASSWORD}@${RDS_ENDPOINT}:3306/${DB_NAME}",
  "NEXTAUTH_SECRET": "${NEXTAUTH_SECRET}",
  "NEXTAUTH_URL": "https://${DOMAIN}",
  "GOOGLE_ID": "${GOOGLE_ID}",
  "GOOGLE_SECRET": "${GOOGLE_SECRET}"
}
EOF
)

# Create the secret in AWS Secrets Manager
echo "Creating secret in AWS Secrets Manager..."
SECRET_ARN=$(aws secretsmanager create-secret \
    --name ${SECRET_NAME} \
    --description "Environment variables for feature voting app" \
    --secret-string "${SECRETS_JSON}" \
    --region ${AWS_REGION} \
    --query 'ARN' \
    --output text)

# Save the secret ARN for later use
echo "SECRET_ARN=${SECRET_ARN}" > secrets-output.env
echo "DOMAIN=${DOMAIN}" >> secrets-output.env

echo "Secret created successfully!"
echo "Secret ARN: ${SECRET_ARN}" 