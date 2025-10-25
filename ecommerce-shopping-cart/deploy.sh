#!/bin/bash

# Deployment script for E-Commerce Shopping Cart System

set -e  # Exit immediately if a command exits with a non-zero status

echo "Starting deployment of E-Commerce Shopping Cart System..."

# Check if environment variables are set
if [ -z "$DB_HOST" ] || [ -z "$DB_NAME" ] || [ -z "$DB_USERNAME" ] || [ -z "$DB_PASSWORD" ]; then
    echo "Error: Database environment variables not set"
    exit 1
fi

# Navigate to project directory
cd /home/ubuntu/ecommerce-shopping-cart

# Pull the latest code
echo "Pulling latest code from repository..."
git pull origin main

# Install/update dependencies
echo "Installing/updating dependencies..."
cd backend
npm install --production
cd ../frontend
npm install --production

# Build frontend
echo "Building frontend..."
npm run build

# Navigate back to backend
cd ../backend

# Run database migrations
echo "Running database migrations..."
npx sequelize-cli db:migrate

# Restart the application
echo "Restarting application..."
if [ -f "ecosystem.config.js" ]; then
    # Using PM2
    npm install -g pm2
    pm2 start ecosystem.config.js --update-env
else
    # Using systemd
    sudo systemctl stop ecommerce-app
    sudo systemctl start ecommerce-app
fi

echo "Deployment completed successfully!"