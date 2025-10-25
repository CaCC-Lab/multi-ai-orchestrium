# E-Commerce Application Deployment Guide

## Prerequisites

Before deploying the application, ensure you have:

- AWS account with EC2 and RDS access
- SSH key pair for EC2 access
- Docker and Docker Compose installed on your local machine
- AWS CLI configured with appropriate credentials

## Deployment Options

### Option 1: Local Development with Docker

1. Clone the repository:
   ```bash
   git clone <repository-url>
   cd ecommerce-app
   ```

2. Set up environment variables in `backend/.env`:
   ```env
   NODE_ENV=development
   DB_HOST=localhost
   DB_NAME=ecommerce_db
   DB_USER=postgres
   DB_PASSWORD=your_password
   DB_PORT=5432
   REDIS_HOST=localhost
   REDIS_PORT=6379
   JWT_SECRET=your_jwt_secret_key
   JWT_EXPIRE=7d
   STRIPE_SECRET_KEY=your_stripe_secret_key
   EMAIL_HOST=smtp.sendgrid.net
   EMAIL_PORT=587
   EMAIL_USER=apikey
   EMAIL_PASS=your_sendgrid_api_key
   FRONTEND_URL=http://localhost:3000
   ```

3. Start the application:
   ```bash
   docker-compose up -d
   ```

### Option 2: Production Deployment to AWS EC2

1. Make sure the deployment script is executable:
   ```bash
   chmod +x deploy/deploy-aws.sh
   ```

2. Update the configuration in `deploy/deploy-aws.sh`:
   - Set your EC2 instance ID
   - Update SSH key path
   - Set appropriate AWS region

3. Run the deployment script:
   ```bash
   ./deploy/deploy-aws.sh
   ```

## Environment Variables

### Backend (.env)
- `NODE_ENV`: Environment (development/production)
- `DB_HOST`, `DB_NAME`, `DB_USER`, `DB_PASSWORD`, `DB_PORT`: Database configuration
- `REDIS_HOST`, `REDIS_PORT`: Redis cache configuration
- `JWT_SECRET`, `JWT_EXPIRE`: JWT authentication settings
- `STRIPE_SECRET_KEY`: Stripe API key
- `EMAIL_HOST`, `EMAIL_PORT`, `EMAIL_USER`, `EMAIL_PASS`: Email service configuration
- `FRONTEND_URL`: Frontend application URL

### Frontend (.env)
- `REACT_APP_API_URL`: Backend API URL

## AWS Infrastructure Setup

For production deployment, you'll need:

1. **EC2 Instance Configuration**:
   - Instance type: t3.medium or larger
   - Security group allowing ports: 22 (SSH), 80 (HTTP), 443 (HTTPS), 5000 (API)
   - IAM role with necessary permissions

2. **RDS Database**:
   - PostgreSQL instance (version 12+)
   - Appropriate security group allowing access from EC2 instance
   - Database name, username, and password

3. **Redis ElastiCache** (optional but recommended):
   - Redis cluster for caching
   - Security group allowing access from EC2 instance

4. **SSL Certificate** (optional):
   - AWS Certificate Manager for HTTPS

## Backup and Recovery

### Database Backups
- RDS provides automated backups
- Set backup retention period as per business requirements
- Test restore procedures regularly

### Application Backups
- Version control for application code
- Docker image backups to ECR (Elastic Container Registry)
- Environment configuration backups

## Monitoring and Logging

1. **Application Logging**: Logs are written to standard output and can be viewed with:
   ```bash
   docker-compose logs -f
   ```

2. **Performance Monitoring**:
   - Use AWS CloudWatch for infrastructure monitoring
   - Implement application-level performance monitoring

3. **Health Checks**:
   - Backend: `GET /api/health`
   - Frontend: Root path (`/`)

## Scaling Recommendations

1. **Vertical Scaling**:
   - Increase EC2 instance size as needed
   - Increase RDS instance size for database performance

2. **Horizontal Scaling** (Advanced):
   - Use AWS Application Load Balancer
   - Run multiple backend container instances
   - Use RDS read replicas for database scaling
   - Implement Redis cluster for distributed caching

## Security Best Practices

1. **Network Security**:
   - Use private subnets for database and cache
   - Restrict security group access to minimum required
   - Implement WAF (Web Application Firewall) if needed

2. **Application Security**:
   - Keep dependencies updated
   - Rotate secrets regularly
   - Implement proper input validation
   - Use HTTPS in production

3. **Database Security**:
   - Enable encryption at rest
   - Use parameter groups with security configurations
   - Regularly update database engine

## Troubleshooting

### Common Issues

1. **Application not starting**:
   - Check logs: `docker-compose logs -f`
   - Verify environment variables are set correctly
   - Ensure database and Redis are accessible

2. **Database connection errors**:
   - Verify network connectivity between containers
   - Check database credentials
   - Ensure database is running and accessible

3. **Email delivery issues**:
   - Verify email service configuration
   - Check API key validity
   - Review rate limits

### Useful Commands

```bash
# View all container logs
docker-compose logs

# View specific service logs
docker-compose logs backend
docker-compose logs db

# Check container status
docker-compose ps

# Restart specific service
docker-compose restart backend

# Stop all services
docker-compose down

# Update and restart services
docker-compose pull
docker-compose up -d
```