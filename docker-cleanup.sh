#!/bin/bash

# Script to clean up unused Docker images, containers, and volumes
# This helps to free up disk space used by Docker

echo "Starting Docker cleanup..."

# Remove all unused images (not just dangling ones) forcefully
echo "Removing unused Docker images..."
docker image prune -a -f

# Additionally remove any dangling containers
echo "Removing dangling containers..."
docker container prune -f

# Additionally remove any unused volumes
echo "Removing unused volumes..."
docker volume prune -f

# Optional: Remove unused networks
echo "Removing unused networks..."
docker network prune -f

echo "Docker cleanup completed successfully!"
echo "Run this script periodically to maintain disk space." 