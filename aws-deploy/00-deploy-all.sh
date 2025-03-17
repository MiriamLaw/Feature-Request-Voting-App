#!/bin/bash

# Make all scripts executable
chmod +x ./*.sh

echo "==================== FEATURE VOTING APP DEPLOYMENT ===================="
echo "This master script will deploy your feature voting app to AWS ECS."
echo "It will run each script in sequence and pause between critical steps."
echo ""
echo "Prerequisites:"
echo "1. AWS CLI installed and configured with sufficient permissions"
echo "2. Docker installed and running"
echo "3. Your code must be ready to build with the provided Dockerfile"
echo ""
echo "The deployment process will:"
echo "1. Configure AWS CLI"
echo "2. Create ECR repository and push Docker image"
echo "3. Create VPC, subnets, and security groups"
echo "4. Create RDS MySQL database"
echo "5. Create secrets in AWS Secrets Manager"
echo "6. Request SSL certificate from AWS Certificate Manager"
echo "7. Set up Route 53 for DNS management"
echo "8. Create ECS cluster, task definition, and service"
echo "9. Configure HTTPS and DNS records"
echo ""
echo "IMPORTANT: The deployment will take approximately 30-45 minutes, with most"
echo "           of the time spent waiting for the RDS instance to be created."
echo ""
read -p "Press Enter to start the deployment or Ctrl+C to cancel..."

# Step 1: Configure AWS CLI
echo ""
echo "========== Step 1: Configure AWS CLI =========="
echo "You'll need to provide your AWS access key and secret access key."
echo "These credentials will be used to create resources in your AWS account."
echo ""
./01-configure-aws.sh
echo ""
read -p "AWS CLI configured. Press Enter to continue to the next step..."

# Step 2: Create ECR repository and push Docker image
echo ""
echo "========== Step 2: Create ECR repository and push Docker image =========="
echo "This step will create an ECR repository and push your Docker image to it."
echo "Make sure Docker is running and your code is ready to build."
echo ""
./02-create-ecr-push-image.sh
echo ""
read -p "Docker image pushed to ECR. Press Enter to continue to the next step..."

# Step 3: Create VPC, subnets, and security groups
echo ""
echo "========== Step 3: Create VPC, subnets, and security groups =========="
echo "This step will create the network infrastructure for your application."
echo ""
./03-create-vpc.sh
echo ""
read -p "VPC infrastructure created. Press Enter to continue to the next step..."

# Step 4: Create RDS MySQL database
echo ""
echo "========== Step 4: Create RDS MySQL database =========="
echo "This step will create an RDS MySQL database. This may take 5-10 minutes."
echo ""
./04-create-rds.sh
echo ""
read -p "RDS MySQL database created. Press Enter to continue to the next step..."

# Step 5: Create secrets in AWS Secrets Manager
echo ""
echo "========== Step 5: Create secrets in AWS Secrets Manager =========="
echo "This step will create secrets in AWS Secrets Manager for your app's environment variables."
echo ""
./05-create-secrets.sh
echo ""
read -p "Secrets created in AWS Secrets Manager. Press Enter to continue to the next step..."

# Step 6: Request SSL certificate from AWS Certificate Manager
echo ""
echo "========== Step 6: Request SSL certificate from AWS Certificate Manager =========="
echo "This step will request an SSL certificate from AWS Certificate Manager."
echo ""
./06-create-certificate.sh
echo ""
echo "IMPORTANT: Before continuing, you need to validate the certificate."
echo "           This requires you to have a domain name and create DNS records."
echo "           The validation process can take up to 30 minutes."
echo ""
read -p "Certificate requested. Have you validated the certificate? (y/n): " CERT_VALIDATED

if [[ $CERT_VALIDATED != "y" ]]; then
    echo "Please validate the certificate before continuing."
    echo "Run the script again when the certificate has been validated."
    exit 0
fi

# Step 7: Set up Route 53 for DNS management
echo ""
echo "========== Step 7: Set up Route 53 for DNS management =========="
echo "This step will set up Route 53 for DNS management."
echo "You must have a domain name registered to continue."
echo ""
./07-setup-route53.sh
echo ""
read -p "Route 53 set up. Press Enter to continue to the next step..."

# Step 8: Create ECS cluster, task definition, and service
echo ""
echo "========== Step 8: Create ECS cluster, task definition, and service =========="
echo "This step will create an ECS cluster, task definition, and service."
echo ""
./08-create-ecs.sh
echo ""
read -p "ECS infrastructure created. Press Enter to continue to the next step..."

# Step 9: Configure HTTPS and DNS records
echo ""
echo "========== Step 9: Configure HTTPS and DNS records =========="
echo "This step will configure HTTPS with your validated certificate and update DNS records."
echo ""
./09-configure-https-dns.sh
echo ""

echo "==================== DEPLOYMENT COMPLETE ===================="
echo "Your feature voting app has been deployed to AWS ECS!"
echo "You can access your application at the domain you specified."
echo ""
echo "To clean up all resources, run: ./10-cleanup-resources.sh" 