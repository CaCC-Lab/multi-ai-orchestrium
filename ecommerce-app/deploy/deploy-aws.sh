#!/bin/bash

# E-commerce Application Deployment Script for AWS
# This script automates the deployment of the e-commerce application to AWS EC2

set -e  # Exit immediately if a command exits with a non-zero status

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}Starting E-commerce Application Deployment${NC}"

# Configuration variables
EC2_INSTANCE="your-ec2-instance"
EC2_USER="ubuntu"  # or ec2-user for Amazon Linux
APP_NAME="ecommerce-app"
APP_DIR="/home/ubuntu/$APP_NAME"

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check prerequisites
print_status "Checking prerequisites..."

if ! command_exists aws; then
    print_error "AWS CLI is not installed. Please install it first."
    exit 1
fi

if ! command_exists docker; then
    print_error "Docker is not installed. Please install it first."
    exit 1
fi

if ! command_exists docker-compose; then
    print_error "Docker Compose is not installed. Please install it first."
    exit 1
fi

# Ask for confirmation
read -p "This script will deploy the application to $EC2_INSTANCE. Continue? (y/N) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    print_warning "Deployment cancelled by user."
    exit 1
fi

# Prepare the application
print_status "Preparing application for deployment..."

# Build the Docker images
print_status "Building Docker images..."
cd ecommerce-app
docker-compose build

# Create a deployment package
print_status "Creating deployment package..."
tar -czf "${APP_NAME}_deploy.tar.gz" docker-compose.yml backend/ frontend/

# Copy to EC2 instance
print_status "Copying application to EC2 instance..."
scp -i ~/.ssh/your-key.pem "${APP_NAME}_deploy.tar.gz" "$EC2_USER@$EC2_INSTANCE:/tmp/"

# Connect to EC2 instance and deploy
print_status "Deploying to EC2 instance..."

ssh -i ~/.ssh/your-key.pem "$EC2_USER@$EC2_INSTANCE" << EOF
set -e

# Create app directory if it doesn't exist
sudo mkdir -p $APP_DIR

# Extract the deployment package
sudo tar -xzf /tmp/${APP_NAME}_deploy.tar.gz -C $APP_DIR

# Navigate to the app directory
cd $APP_DIR

# Create necessary directories for volumes
sudo mkdir -p postgres_data redis_data

# Set up environment variables
cat > .env << ENV_EOF
NODE_ENV=production
DB_HOST=db
DB_NAME=ecommerce_db
DB_USER=postgres
DB_PASSWORD=your_secure_password
DB_PORT=5432
REDIS_HOST=redis
REDIS_PORT=6379
JWT_SECRET=$(openssl rand -base64 32)
JWT_EXPIRE=7d
STRIPE_SECRET_KEY=your_stripe_secret_key
EMAIL_HOST=smtp.sendgrid.net
EMAIL_PORT=587
EMAIL_USER=apikey
EMAIL_PASS=your_sendgrid_api_key
FRONTEND_URL=http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4):3000
ENV_EOF

# Start the application
sudo docker-compose up -d

# Check if services are running
echo "Waiting for services to start..."
sleep 30

# Check status
sudo docker-compose ps

echo "Deployment completed! The application should be accessible at http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4):3000"
EOF

print_status "Deployment script completed!"
print_status "Application URL: http://$(aws ec2 describe-instances --instance-ids $EC2_INSTANCE --query 'Reservations[*].Instances[*].PublicIpAddress' --output text):3000"