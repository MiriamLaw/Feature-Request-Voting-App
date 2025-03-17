# AWS Deployment Scripts for Feature Voting App

This directory contains all the scripts needed to deploy the Feature Voting App to AWS ECS.

## Scripts Overview

The scripts are numbered in the order they should be executed:

00. **00-deploy-all.sh** - Master script that runs all deployment steps in sequence
01. **01-configure-aws.sh** - Configure AWS CLI credentials (prompts for credentials)
02. **02-create-ecr-push-image.sh** - Create ECR repository and push Docker image
03. **03-create-vpc.sh** - Create VPC, subnets, and security groups
04. **04-create-rds.sh** - Create RDS MySQL database
05. **05-create-secrets.sh** - Store environment variables in AWS Secrets Manager (loads from .env file)
06. **06-create-certificate.sh** - Request SSL certificate from AWS Certificate Manager
07. **07-setup-route53.sh** - Set up Route 53 for DNS management
08. **08-create-ecs.sh** - Create ECS cluster, task definition, and service
09. **09-configure-https-dns.sh** - Configure HTTPS and DNS records
10. **10-cleanup-resources.sh** - Clean up all AWS resources (use only when you want to tear down)

## Usage Instructions

### Option 1: Run the Automated Deployment (Recommended)

To deploy the entire infrastructure in one go:

```bash
cd aws-deploy
./00-deploy-all.sh
```

This script will guide you through each step and pause at appropriate points for user input.

### Option 2: Run Scripts Individually (For Learning)

If you want to run each script individually (useful for learning AWS deployment):

```bash
cd aws-deploy
./01-configure-aws.sh
# (Wait for completion and verify)
./02-create-ecr-push-image.sh
# (Continue with each script in sequence)
```

### Important Notes

1. **AWS Credentials**: The scripts will prompt you for your AWS credentials, which are never stored in the scripts directly.

2. **Sensitive Information**: OAuth credentials and other sensitive data are loaded from your `.env` file. Make sure this file is properly configured.

3. **Domain Name**: You'll need a domain name to complete the HTTPS setup. The scripts allow you to customize the domain name or use the default.

4. **Database Password**: The default database password is set to "NewSecurePassHundo". This is for demonstration purposes only - for real production deployments, use a stronger password.

5. **Environment Variables**: The deployment will set up environment variables based on your .env file. Double-check that these are correctly configured before deploying.

6. **Cleanup**: If you need to remove all AWS resources, run `./10-cleanup-resources.sh`.

## Deployment Time

The entire deployment process may take 30-45 minutes, with most of the time spent waiting for the RDS instance to be created. 