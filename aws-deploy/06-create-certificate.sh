#!/bin/bash

# Source the domain if available
if [ -f secrets-output.env ]; then
    source secrets-output.env
fi

# Set variables
AWS_REGION="us-east-1"

# Prompt for domain if not already set
if [ -z "$DOMAIN" ]; then
    read -p "Enter the domain for your app (default: feature-voting-app.example.com): " DOMAIN
    if [ -z "$DOMAIN" ]; then
        DOMAIN="feature-voting-app.example.com"
    fi
    echo "DOMAIN=${DOMAIN}" > domain-output.env
fi

ALTERNATE_DOMAIN="*.${DOMAIN}"  # Wildcard for subdomains

echo "Creating SSL certificate with AWS Certificate Manager for domain: ${DOMAIN}"
CERTIFICATE_ARN=$(aws acm request-certificate \
    --domain-name ${DOMAIN} \
    --validation-method DNS \
    --subject-alternative-names ${ALTERNATE_DOMAIN} \
    --region ${AWS_REGION} \
    --query 'CertificateArn' \
    --output text)

# Save the certificate ARN for later use
echo "CERTIFICATE_ARN=${CERTIFICATE_ARN}" > certificate-output.env
echo "DOMAIN=${DOMAIN}" >> certificate-output.env

echo "Certificate requested successfully!"
echo "Certificate ARN: ${CERTIFICATE_ARN}"
echo ""
echo "IMPORTANT: Before proceeding, you need to:"
echo "1. Purchase a domain name (e.g., from Route 53 or another domain registrar)"
echo "2. Create a Route 53 hosted zone for your domain"
echo "3. Validate the certificate by adding the DNS records provided by AWS ACM"
echo "4. Wait for certificate validation to complete (this can take up to 30 minutes)"
echo ""
echo "To check validation status, run:"
echo "aws acm describe-certificate --certificate-arn ${CERTIFICATE_ARN} --region ${AWS_REGION}" 