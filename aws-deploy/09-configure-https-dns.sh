#!/bin/bash

# Source output variables from previous scripts
source certificate-output.env
source route53-output.env
source ecs-output.env
source secrets-output.env

# Set variables
AWS_REGION="us-east-1"

# Use the domain from previous scripts
if [ -z "$DOMAIN" ]; then
    echo "Error: No domain name found. Make sure you ran the previous scripts correctly."
    exit 1
fi

echo "Using domain: ${DOMAIN}"

# Check if certificate is validated
echo "Checking certificate validation status..."
CERTIFICATE_STATUS=$(aws acm describe-certificate \
    --certificate-arn ${CERTIFICATE_ARN} \
    --region ${AWS_REGION} \
    --query 'Certificate.Status' \
    --output text)

if [ "${CERTIFICATE_STATUS}" != "ISSUED" ]; then
    echo "Certificate is not yet validated (current status: ${CERTIFICATE_STATUS})"
    echo "Please validate the certificate before proceeding."
    echo "Check validation details with:"
    echo "aws acm describe-certificate --certificate-arn ${CERTIFICATE_ARN} --region ${AWS_REGION}"
    exit 1
fi

echo "Certificate is validated. Creating HTTPS listener..."

# Create HTTPS listener
HTTPS_LISTENER_ARN=$(aws elbv2 create-listener \
    --load-balancer-arn ${LB_ARN} \
    --protocol HTTPS \
    --port 443 \
    --certificates CertificateArn=${CERTIFICATE_ARN} \
    --ssl-policy ELBSecurityPolicy-2016-08 \
    --default-actions Type=forward,TargetGroupArn=${TG_ARN} \
    --region ${AWS_REGION} \
    --query 'Listeners[0].ListenerArn' \
    --output text)

echo "HTTPS listener created successfully."

# Delete the temporary HTTP listener on port 8080
echo "Deleting temporary HTTP listener..."
aws elbv2 delete-listener \
    --listener-arn ${TEMP_LISTENER_ARN} \
    --region ${AWS_REGION}

echo "Creating DNS record in Route 53..."
# Create an A record that points to the load balancer
CHANGE_BATCH=$(cat <<EOF
{
  "Changes": [
    {
      "Action": "CREATE",
      "ResourceRecordSet": {
        "Name": "${DOMAIN}",
        "Type": "A",
        "AliasTarget": {
          "HostedZoneId": "Z35SXDOTRQ7X7K",  # This is the hosted zone ID for us-east-1 ALBs
          "DNSName": "${LB_DNS_NAME}",
          "EvaluateTargetHealth": true
        }
      }
    }
  ]
}
EOF
)

aws route53 change-resource-record-sets \
    --hosted-zone-id ${HOSTED_ZONE_ID} \
    --change-batch "${CHANGE_BATCH}"

echo "HTTPS and DNS configuration completed successfully!"
echo "You can now access your application at: https://${DOMAIN}"
echo ""
echo "IMPORTANT: Update the NEXTAUTH_URL in AWS Secrets Manager to use HTTPS:"
echo "aws secretsmanager update-secret --secret-id ${SECRET_NAME} --secret-string '{\"NEXTAUTH_URL\":\"https://${DOMAIN}\", ...other secrets...}'" 