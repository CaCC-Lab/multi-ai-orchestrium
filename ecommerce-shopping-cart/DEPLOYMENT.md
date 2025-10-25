# E-Commerce Shopping Cart System

## Deployment Instructions

This document provides instructions for deploying the E-Commerce Shopping Cart System.

## Prerequisites

- Node.js (v16 or higher)
- PostgreSQL database
- Redis server (for caching)
- Stripe API key
- SendGrid API key
- AWS EC2 instance (or other cloud server)

## Environment Variables

Create a `.env` file in the backend directory with the following variables:

```env
NODE_ENV=production
PORT=5000
DB_HOST=your_db_host
DB_NAME=your_db_name
DB_USERNAME=your_db_username
DB_PASSWORD=your_db_password
JWT_SECRET=your_jwt_secret
STRIPE_API_KEY=your_stripe_api_key
SENDGRID_API_KEY=your_sendgrid_api_key
REDIS_URL=redis://your_redis_host:6379
FRONTEND_URL=https://yourfrontend.com
```

## Deployment Methods

### Method 1: Manual Deployment

1. Clone the repository to your server:
```bash
git clone https://github.com/yourusername/ecommerce-shopping-cart.git
```

2. Install dependencies:
```bash
cd ecommerce-shopping-cart/backend
npm install
cd ../frontend
npm install
npm run build
```

3. Set up environment variables as mentioned above

4. Run database migrations:
```bash
cd backend
npx sequelize-cli db:migrate
```

5. Start the application:
```bash
npm start
```

### Method 2: Using PM2

1. Install PM2 globally:
```bash
npm install -g pm2
```

2. Start the application with PM2 using the ecosystem config:
```bash
cd ecommerce-shopping-cart
pm2 start ecosystem.config.js --env production
```

3. To keep the app running after reboot:
```bash
pm2 startup
pm2 save
```

### Method 3: Using Docker

1. Build and run with Docker Compose:
```bash
docker-compose up -d
```

## CI/CD Pipeline

The project includes a GitHub Actions workflow for continuous integration and deployment. The workflow will:
1. Run tests on pull requests and pushes to main/develop
2. Build and push Docker images on successful main branch commits
3. Deploy to production server

## Scaling Considerations

- Use a load balancer for horizontal scaling
- Implement Redis cluster for caching
- Use CDN for static assets
- Set up database replication for read-heavy operations

## Monitoring and Logging

- The application uses Winston for logging
- Performance monitoring middleware logs response times
- Health check endpoint available at `/health`
- Use PM2's monitoring capabilities or set up external monitoring