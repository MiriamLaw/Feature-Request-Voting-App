#!/bin/bash

# Source the RDS output file which contains the database URL
source rds-output.env

# Store the original DATABASE_URL if it exists
if [ -n "$DATABASE_URL" ]; then
    ORIGINAL_DATABASE_URL=$DATABASE_URL
fi

# Set the RDS database URL explicitly
export DATABASE_URL=mysql://root:NewSecurePassHundo@feature-voting-db.cedqquwo84hd.us-east-1.rds.amazonaws.com:3306/feature_voting

# Navigate to the project root directory (assuming this script is in aws-deploy folder)
cd ..

echo "Using database: $DATABASE_URL"

# Generate Prisma Client
echo "Generating Prisma Client..."
npx prisma generate

# Run database migrations
echo "Running database migrations..."
npx prisma migrate deploy

# Verify the database schema
echo "Verifying database schema..."
npx prisma db pull

# Restore the original DATABASE_URL if it existed
if [ -n "$ORIGINAL_DATABASE_URL" ]; then
    export DATABASE_URL=$ORIGINAL_DATABASE_URL
fi

echo "Database deployment completed successfully!" 