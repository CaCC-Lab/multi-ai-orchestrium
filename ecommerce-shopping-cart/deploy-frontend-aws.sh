#!/bin/bash

# E-Commerce Frontend Deployment Script for AWS
# This script sets up the React frontend on EC2

set -e  # Exit on any error

echo "Starting E-Commerce Frontend Deployment..."

# Update system packages
sudo apt update && sudo apt upgrade -y

# Install Node.js and npm
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
sudo apt install -y nodejs

# Install serve globally to serve static files
sudo npm install -g serve

# Create app directory
sudo mkdir -p /var/www/ecommerce-frontend
sudo chown $USER:$USER /var/www/ecommerce-frontend
cd /var/www/ecommerce-frontend

# Copy application files (assumes they're in the current directory or will be transferred)
# This would typically be done via git clone or scp
# git clone https://github.com/your-username/ecommerce-frontend.git .
# cd ecommerce-frontend

# Install dependencies
npm install

# Build the application
REACT_APP_API_URL=https://<your-backend-domain> npm run build

# Install and configure Nginx
sudo apt install -y nginx

# Remove default Nginx page
sudo rm /etc/nginx/sites-enabled/default

# Create Nginx configuration for frontend
sudo tee /etc/nginx/sites-available/ecommerce-frontend > /dev/null << EOF
server {
    listen 80;
    server_name <your-frontend-domain-or-ec2-public-ip>;

    root /var/www/ecommerce-frontend/build;
    index index.html index.htm;

    # Serve static assets with longer cache
    location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg|woff|woff2|ttf|eot)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
    }

    # Handle React Router routes
    location / {
        try_files \$uri \$uri/ /index.html;
    }
}
EOF

sudo ln -s /etc/nginx/sites-available/ecommerce-frontend /etc/nginx/sites-enabled/
sudo nginx -t && sudo systemctl restart nginx

# Configure firewall
sudo ufw allow OpenSSH
sudo ufw allow 'Nginx Full'
sudo ufw --force enable

echo "E-Commerce Frontend Deployment Complete!"
echo "Frontend is built and served via Nginx"
echo "React Router is configured for client-side routing"