#!/bin/bash

# E-Commerce Deployment Script for AWS
# This script sets up the backend service on EC2 with connection to RDS

set -e  # Exit on any error

echo "Starting E-Commerce Backend Deployment..."

# Update system packages
sudo apt update && sudo apt upgrade -y

# Install Node.js and npm
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
sudo apt install -y nodejs

# Install PM2 globally for process management
sudo npm install -g pm2

# Install PostgreSQL client
sudo apt install -y postgresql-client

# Create app directory
sudo mkdir -p /var/www/ecommerce-backend
sudo chown $USER:$USER /var/www/ecommerce-backend
cd /var/www/ecommerce-backend

# Copy application files (assumes they're in the current directory or will be transferred)
# This would typically be done via git clone or scp
# git clone https://github.com/your-username/ecommerce-backend.git .

# Install dependencies
npm install

# Create environment file (you'd provide these values)
# This would normally be done more securely (e.g., via AWS Systems Manager Parameter Store)
cat > .env << EOF
NODE_ENV=production
PORT=5000
DB_HOST=<your-rds-endpoint>
DB_PORT=5432
DB_NAME=ecommerce_db
DB_USER=ecommerce_user
DB_PASSWORD=<your-db-password>
JWT_SECRET=<your-jwt-secret>
STRIPE_SECRET_KEY=<your-stripe-secret-key>
STRIPE_PUBLISHABLE_KEY=<your-stripe-publishable-key>
SENDGRID_API_KEY=<your-sendgrid-api-key>
REDIS_URL=redis://localhost:6379
FROM_EMAIL=noreply@yourdomain.com
EOF

# Start the application with PM2
pm2 start server.js --name ecommerce-backend --env production

# Save PM2 process list to restart on boot
pm2 startup
pm2 save

# Set up Nginx reverse proxy (install if not present)
sudo apt install -y nginx

# Create Nginx configuration
sudo tee /etc/nginx/sites-available/ecommerce-backend > /dev/null << EOF
server {
    listen 80;
    server_name <your-domain-or-ec2-public-ip>;

    location / {
        proxy_pass http://localhost:5000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_cache_bypass \$http_upgrade;
    }

    location /api-docs {
        proxy_pass http://localhost:5000;
    }
}
EOF

sudo ln -s /etc/nginx/sites-available/ecommerce-backend /etc/nginx/sites-enabled/
sudo nginx -t && sudo systemctl restart nginx

# Install and configure Redis for caching
sudo apt install -y redis-server
sudo systemctl enable redis-server
sudo systemctl start redis-server

# Configure firewall
sudo ufw allow OpenSSH
sudo ufw allow 'Nginx Full'
sudo ufw --force enable

echo "E-Commerce Backend Deployment Complete!"
echo "Application is running with PM2"
echo "Nginx is configured as reverse proxy"
echo "Don't forget to update your environment variables in .env file"