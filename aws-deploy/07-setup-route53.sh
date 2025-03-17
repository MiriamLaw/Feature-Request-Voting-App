#!/bin/bash

# Source the domain if available
if [ -f secrets-output.env ]; then
    source secrets-output.env
elif [ -f domain-output.env ]; then
    source domain-output.env
elif [ -f certificate-output.env ]; then
    source certificate-output.env
fi

# Prompt for domain if not already set
if [ -z "$DOMAIN" ]; then
    read -p "Enter the domain for your app (default: feature-voting-app.example.com): " DOMAIN
    if [ -z "$DOMAIN" ]; then
        DOMAIN="feature-voting-app.example.com"
    fi
fi

# Extract root domain (e.g., 'example.com' from 'feature-voting-app.example.com')
ROOT_DOMAIN=$(echo $DOMAIN | awk -F. '{print $(NF-1)"."$NF}')

echo "This script helps you set up Route 53 for DNS management."
echo "Note: You must already own a domain name to proceed."
echo ""
echo "Using domain: ${DOMAIN}"
echo "Root domain: ${ROOT_DOMAIN}"
echo ""
echo "1. If you don't already have a domain name, you can purchase one through Route 53 with:"
echo "   aws route53domains register-domain --domain-name your-domain.com --admin-contact ... --registrant-contact ... --tech-contact ..."
echo ""
echo "2. Creating a Route 53 hosted zone for your domain..."

HOSTED_ZONE_ID=$(aws route53 create-hosted-zone \
    --name ${ROOT_DOMAIN} \
    --caller-reference "$(date +%s)" \
    --query 'HostedZone.Id' \
    --output text)

# Extract just the ID part from the full path (format: /hostedzone/Z1234567890)
HOSTED_ZONE_ID=$(echo ${HOSTED_ZONE_ID} | sed 's/\/hostedzone\///')

echo "Hosted zone created with ID: ${HOSTED_ZONE_ID}"
echo ""
echo "3. If you purchased your domain elsewhere, you need to update your domain's name servers."
echo "   Get the name servers with this command:"
echo "   aws route53 get-hosted-zone --id ${HOSTED_ZONE_ID} --query 'DelegationSet.NameServers'"
echo ""
echo "4. Wait for DNS propagation (can take up to 48 hours, but often less)"

# Save the hosted zone ID for later use
echo "HOSTED_ZONE_ID=${HOSTED_ZONE_ID}" > route53-output.env
echo "DOMAIN=${DOMAIN}" >> route53-output.env
echo "ROOT_DOMAIN=${ROOT_DOMAIN}" >> route53-output.env

echo "Route 53 setup initiated successfully!"
echo "Hosted Zone ID: ${HOSTED_ZONE_ID}"
echo ""
echo "Note: The next scripts will create Load Balancer and create DNS records pointing to it." 