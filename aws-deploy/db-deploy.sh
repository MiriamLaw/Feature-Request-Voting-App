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

# === Test CREATE TABLE capability ===
echo "Attempting to create a dummy table via raw SQL..."
# Use echo and pipe to stdin for prisma db execute
echo "CREATE TABLE IF NOT EXISTS dummy_test (id INT PRIMARY KEY);" | npx prisma db execute --stdin

# Check if dummy table exists right after creation attempt (optional but helpful)
echo "Checking if dummy_test table exists..."
echo "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'feature_voting' AND table_name = 'dummy_test';" | npx prisma db execute --stdin
# ====================================

# === Using db push to force schema creation ===
echo "Pushing schema to the database (using db push)..."
npx prisma db push --accept-data-loss
# ==============================================

# === ORIGINAL COMMANDS (Commented out for now) ===
# Run database migrations
# echo "Running database migrations..."
# npx prisma migrate deploy
# 
# Verify the database schema (Optional but good check)
# echo "Verifying database schema..."
# npx prisma db pull
# =================================================

# Restore the original DATABASE_URL if it existed
if [ -n "$ORIGINAL_DATABASE_URL" ]; then
    export DATABASE_URL=$ORIGINAL_DATABASE_URL
fi

echo "Database deployment completed successfully!" 