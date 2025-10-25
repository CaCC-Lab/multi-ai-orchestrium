# CI/CD & Deployment Guide

## Overview

Continuous Integration and Deployment strategy for E-Commerce Shopping Cart System using GitHub Actions and AWS infrastructure.

---

## 🔄 CI/CD Pipeline Architecture

```mermaid
graph LR
    A[Git Push] --> B[GitHub Actions]
    B --> C{Tests Pass?}
    C -->|No| D[Notify Developer]
    C -->|Yes| E{Branch?}
    E -->|develop| F[Deploy to Staging]
    E -->|main| G[Deploy to Production]
    F --> H[Staging Environment]
    G --> I[Production Environment]
    I --> J[Health Check]
    J -->|Success| K[Complete]
    J -->|Failure| L[Rollback]
```

---

## 🛠️ GitHub Actions Workflows

### 1. Pull Request Workflow

**.github/workflows/pr-checks.yml**

```yaml
name: PR Checks

on:
  pull_request:
    branches: [develop, main]

jobs:
  lint:
    name: Lint Code
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Setup Node.js
        uses: actions/setup-node@v3
        with:
          node-version: '18'
          cache: 'npm'
      
      - name: Install dependencies (Backend)
        run: cd backend && npm ci
      
      - name: Run ESLint (Backend)
        run: cd backend && npm run lint
      
      - name: Install dependencies (Frontend)
        run: cd frontend && npm ci
      
      - name: Run ESLint (Frontend)
        run: cd frontend && npm run lint

  test-backend:
    name: Backend Tests
    runs-on: ubuntu-latest
    services:
      postgres:
        image: postgres:14
        env:
          POSTGRES_USER: test
          POSTGRES_PASSWORD: test
          POSTGRES_DB: ecommerce_test
        ports:
          - 5432:5432
        options: >-
          --health-cmd pg_isready
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5
      
      redis:
        image: redis:7-alpine
        ports:
          - 6379:6379
        options: >-
          --health-cmd "redis-cli ping"
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5
    
    steps:
      - uses: actions/checkout@v3
      
      - name: Setup Node.js
        uses: actions/setup-node@v3
        with:
          node-version: '18'
          cache: 'npm'
      
      - name: Install dependencies
        run: cd backend && npm ci
      
      - name: Run migrations
        run: cd backend && npm run migrate
        env:
          DATABASE_URL: postgresql://test:test@localhost:5432/ecommerce_test
      
      - name: Run tests with coverage
        run: cd backend && npm run test:coverage
        env:
          DATABASE_URL: postgresql://test:test@localhost:5432/ecommerce_test
          REDIS_URL: redis://localhost:6379
      
      - name: Upload coverage to Codecov
        uses: codecov/codecov-action@v3
        with:
          files: ./backend/coverage/lcov.info
          flags: backend

  test-frontend:
    name: Frontend Tests
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Setup Node.js
        uses: actions/setup-node@v3
        with:
          node-version: '18'
          cache: 'npm'
      
      - name: Install dependencies
        run: cd frontend && npm ci
      
      - name: Run tests with coverage
        run: cd frontend && npm run test:coverage
      
      - name: Upload coverage to Codecov
        uses: codecov/codecov-action@v3
        with:
          files: ./frontend/coverage/lcov.info
          flags: frontend

  security-scan:
    name: Security Scan
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Run npm audit (Backend)
        run: cd backend && npm audit --production --audit-level=high
      
      - name: Run npm audit (Frontend)
        run: cd frontend && npm audit --production --audit-level=high
      
      - name: Run Snyk Security Scan
        uses: snyk/actions/node@master
        env:
          SNYK_TOKEN: ${{ secrets.SNYK_TOKEN }}
        with:
          command: test
          args: --all-projects --severity-threshold=high

  build:
    name: Build Docker Images
    runs-on: ubuntu-latest
    needs: [lint, test-backend, test-frontend]
    steps:
      - uses: actions/checkout@v3
      
      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v2
      
      - name: Build Backend Image
        uses: docker/build-push-action@v4
        with:
          context: ./backend
          push: false
          tags: ecommerce-backend:${{ github.sha }}
          cache-from: type=gha
          cache-to: type=gha,mode=max
      
      - name: Build Frontend Image
        uses: docker/build-push-action@v4
        with:
          context: ./frontend
          push: false
          tags: ecommerce-frontend:${{ github.sha }}
          cache-from: type=gha
          cache-to: type=gha,mode=max
```

---

### 2. Staging Deployment Workflow

**.github/workflows/deploy-staging.yml**

```yaml
name: Deploy to Staging

on:
  push:
    branches:
      - develop

jobs:
  deploy:
    name: Deploy to Staging
    runs-on: ubuntu-latest
    environment:
      name: staging
      url: https://staging.example.com
    
    steps:
      - uses: actions/checkout@v3
      
      - name: Configure AWS Credentials
        uses: aws-actions/configure-aws-credentials@v2
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region: us-east-1
      
      - name: Login to Amazon ECR
        id: login-ecr
        uses: aws-actions/amazon-ecr-login@v1
      
      - name: Build and Push Backend Image
        env:
          ECR_REGISTRY: ${{ steps.login-ecr.outputs.registry }}
          ECR_REPOSITORY: ecommerce-backend
          IMAGE_TAG: ${{ github.sha }}
        run: |
          docker build -t $ECR_REGISTRY/$ECR_REPOSITORY:$IMAGE_TAG ./backend
          docker push $ECR_REGISTRY/$ECR_REPOSITORY:$IMAGE_TAG
      
      - name: Build and Push Frontend Image
        env:
          ECR_REGISTRY: ${{ steps.login-ecr.outputs.registry }}
          ECR_REPOSITORY: ecommerce-frontend
          IMAGE_TAG: ${{ github.sha }}
        run: |
          docker build -t $ECR_REGISTRY/$ECR_REPOSITORY:$IMAGE_TAG ./frontend
          docker push $ECR_REGISTRY/$ECR_REPOSITORY:$IMAGE_TAG
      
      - name: Deploy to EC2 (Staging)
        uses: appleboy/ssh-action@master
        with:
          host: ${{ secrets.STAGING_HOST }}
          username: ${{ secrets.STAGING_USERNAME }}
          key: ${{ secrets.STAGING_SSH_KEY }}
          script: |
            cd /home/ubuntu/ecommerce-app
            export IMAGE_TAG=${{ github.sha }}
            docker-compose -f docker-compose.staging.yml pull
            docker-compose -f docker-compose.staging.yml up -d
            docker-compose -f docker-compose.staging.yml exec -T backend npm run migrate
      
      - name: Run E2E Tests
        uses: cypress-io/github-action@v5
        with:
          config: baseUrl=https://staging.example.com
          wait-on: 'https://staging.example.com'
          wait-on-timeout: 120
        env:
          CYPRESS_RECORD_KEY: ${{ secrets.CYPRESS_RECORD_KEY }}
      
      - name: Notify Slack
        uses: slackapi/slack-github-action@v1
        with:
          payload: |
            {
              "text": "✅ Staging deployment successful!",
              "blocks": [
                {
                  "type": "section",
                  "text": {
                    "type": "mrkdwn",
                    "text": "🚀 *Staging Deployment* \n Commit: `${{ github.sha }}` \n Status: Success"
                  }
                }
              ]
            }
        env:
          SLACK_WEBHOOK_URL: ${{ secrets.SLACK_WEBHOOK_URL }}
```

---

### 3. Production Deployment Workflow

**.github/workflows/deploy-production.yml**

```yaml
name: Deploy to Production

on:
  push:
    branches:
      - main
  workflow_dispatch:
    inputs:
      version:
        description: 'Version to deploy'
        required: true

jobs:
  deploy:
    name: Deploy to Production
    runs-on: ubuntu-latest
    environment:
      name: production
      url: https://example.com
    
    steps:
      - uses: actions/checkout@v3
      
      - name: Configure AWS Credentials
        uses: aws-actions/configure-aws-credentials@v2
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID_PROD }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY_PROD }}
          aws-region: us-east-1
      
      - name: Login to Amazon ECR
        id: login-ecr
        uses: aws-actions/amazon-ecr-login@v1
      
      - name: Build and Push Images
        env:
          ECR_REGISTRY: ${{ steps.login-ecr.outputs.registry }}
          IMAGE_TAG: ${{ github.sha }}
        run: |
          docker build -t $ECR_REGISTRY/ecommerce-backend:$IMAGE_TAG ./backend
          docker push $ECR_REGISTRY/ecommerce-backend:$IMAGE_TAG
          docker tag $ECR_REGISTRY/ecommerce-backend:$IMAGE_TAG $ECR_REGISTRY/ecommerce-backend:latest
          docker push $ECR_REGISTRY/ecommerce-backend:latest
          
          docker build -t $ECR_REGISTRY/ecommerce-frontend:$IMAGE_TAG ./frontend
          docker push $ECR_REGISTRY/ecommerce-frontend:$IMAGE_TAG
          docker tag $ECR_REGISTRY/ecommerce-frontend:$IMAGE_TAG $ECR_REGISTRY/ecommerce-frontend:latest
          docker push $ECR_REGISTRY/ecommerce-frontend:latest
      
      - name: Create Backup
        run: |
          aws rds create-db-snapshot \
            --db-instance-identifier ecommerce-prod-db \
            --db-snapshot-identifier pre-deploy-${{ github.sha }}
      
      - name: Deploy to Production (Blue-Green)
        run: |
          # Deploy to green environment
          ssh ${{ secrets.PROD_USERNAME }}@${{ secrets.PROD_HOST_GREEN }} << 'EOF'
            cd /home/ubuntu/ecommerce-app
            export IMAGE_TAG=${{ github.sha }}
            docker-compose pull
            docker-compose up -d
            docker-compose exec -T backend npm run migrate
          EOF
          
          # Health check
          curl --fail https://green.example.com/health || exit 1
          
          # Switch load balancer to green
          aws elbv2 modify-rule \
            --rule-arn ${{ secrets.ALB_RULE_ARN }} \
            --actions Type=forward,TargetGroupArn=${{ secrets.GREEN_TARGET_GROUP_ARN }}
          
          # Wait and monitor
          sleep 60
          
          # Stop blue environment
          ssh ${{ secrets.PROD_USERNAME }}@${{ secrets.PROD_HOST_BLUE }} << 'EOF'
            cd /home/ubuntu/ecommerce-app
            docker-compose down
          EOF
      
      - name: Smoke Tests
        run: |
          curl --fail https://example.com/health
          curl --fail https://example.com/api/v1/products
      
      - name: Create Git Tag
        run: |
          git tag -a v${{ github.run_number }} -m "Production release ${{ github.sha }}"
          git push origin v${{ github.run_number }}
      
      - name: Notify Slack
        uses: slackapi/slack-github-action@v1
        with:
          payload: |
            {
              "text": "🎉 Production deployment successful!",
              "blocks": [
                {
                  "type": "section",
                  "text": {
                    "type": "mrkdwn",
                    "text": "🚀 *Production Deployment* \n Version: `v${{ github.run_number }}` \n Commit: `${{ github.sha }}` \n Status: ✅ Success"
                  }
                }
              ]
            }
        env:
          SLACK_WEBHOOK_URL: ${{ secrets.SLACK_WEBHOOK_URL }}
```

---

## 🐳 Docker Configuration

### Backend Dockerfile

```dockerfile
FROM node:18-alpine AS base

WORKDIR /app

# Dependencies
COPY package*.json ./
RUN npm ci --only=production && npm cache clean --force

# Build
FROM base AS build
RUN npm ci
COPY . .
RUN npm run build

# Production
FROM node:18-alpine
WORKDIR /app

RUN addgroup -g 1001 -S nodejs && adduser -S nodejs -u 1001

COPY --from=base --chown=nodejs:nodejs /app/node_modules ./node_modules
COPY --from=build --chown=nodejs:nodejs /app/dist ./dist
COPY --chown=nodejs:nodejs package*.json ./

USER nodejs

EXPOSE 3000

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD node -e "require('http').get('http://localhost:3000/health', (r) => {process.exit(r.statusCode === 200 ? 0 : 1)})"

CMD ["node", "dist/server.js"]
```

### Frontend Dockerfile

```dockerfile
FROM node:18-alpine AS build

WORKDIR /app

COPY package*.json ./
RUN npm ci

COPY . .
RUN npm run build

# Production
FROM nginx:alpine

COPY --from=build /app/build /usr/share/nginx/html
COPY nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 80

HEALTHCHECK --interval=30s --timeout=5s CMD wget --no-verbose --tries=1 --spider http://localhost/health || exit 1

CMD ["nginx", "-g", "daemon off;"]
```

### docker-compose.yml (Production)

```yaml
version: '3.8'

services:
  backend:
    image: ${ECR_REGISTRY}/ecommerce-backend:${IMAGE_TAG}
    ports:
      - "3000:3000"
    environment:
      - NODE_ENV=production
      - DATABASE_URL=${DATABASE_URL}
      - REDIS_URL=${REDIS_URL}
      - JWT_SECRET=${JWT_SECRET}
      - STRIPE_SECRET_KEY=${STRIPE_SECRET_KEY}
      - SENDGRID_API_KEY=${SENDGRID_API_KEY}
    depends_on:
      - redis
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "wget", "--no-verbose", "--tries=1", "--spider", "http://localhost:3000/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s
    logging:
      driver: "awslogs"
      options:
        awslogs-group: "/ecs/ecommerce-backend"
        awslogs-region: "us-east-1"
        awslogs-stream-prefix: "ecs"

  frontend:
    image: ${ECR_REGISTRY}/ecommerce-frontend:${IMAGE_TAG}
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./ssl:/etc/nginx/ssl:ro
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "wget", "--no-verbose", "--tries=1", "--spider", "http://localhost/health"]
      interval: 30s
      timeout: 10s
      retries: 3
    logging:
      driver: "awslogs"
      options:
        awslogs-group: "/ecs/ecommerce-frontend"
        awslogs-region: "us-east-1"
        awslogs-stream-prefix: "ecs"

  redis:
    image: redis:7-alpine
    ports:
      - "6379:6379"
    volumes:
      - redis-data:/data
    restart: unless-stopped
    command: redis-server --appendonly yes
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 30s
      timeout: 10s
      retries: 3

volumes:
  redis-data:
```

---

## ☁️ AWS Infrastructure

### Required AWS Resources

1. **EC2 Instances**
   - Production: 2x t3.medium (Blue-Green deployment)
   - Staging: 1x t3.small
   - Region: us-east-1

2. **RDS PostgreSQL**
   - Production: db.t3.medium (Multi-AZ)
   - Staging: db.t3.micro
   - Automated backups: 7-day retention

3. **ElastiCache Redis**
   - Production: cache.t3.medium
   - Staging: cache.t3.micro

4. **S3 Buckets**
   - `ecommerce-prod-assets`: Product images, static files
   - `ecommerce-prod-backups`: Database backups
   - `ecommerce-staging-assets`: Staging assets

5. **CloudFront CDN**
   - Distribution for S3 assets
   - SSL certificate from ACM

6. **Application Load Balancer**
   - HTTPS listener (port 443)
   - HTTP → HTTPS redirect
   - Target groups: Blue, Green

7. **ECR Repositories**
   - `ecommerce-backend`
   - `ecommerce-frontend`

8. **IAM Roles**
   - EC2 instance role (S3, ECR, RDS access)
   - GitHub Actions deployment role

---

## 🔐 Secrets Management

### GitHub Secrets (Repository Settings)

**Staging:**
- `AWS_ACCESS_KEY_ID`
- `AWS_SECRET_ACCESS_KEY`
- `STAGING_HOST`
- `STAGING_USERNAME`
- `STAGING_SSH_KEY`

**Production:**
- `AWS_ACCESS_KEY_ID_PROD`
- `AWS_SECRET_ACCESS_KEY_PROD`
- `PROD_HOST_BLUE`
- `PROD_HOST_GREEN`
- `PROD_USERNAME`
- `PROD_SSH_KEY`
- `ALB_RULE_ARN`
- `GREEN_TARGET_GROUP_ARN`

**External Services:**
- `STRIPE_SECRET_KEY`
- `SENDGRID_API_KEY`
- `SNYK_TOKEN`
- `CYPRESS_RECORD_KEY`
- `SLACK_WEBHOOK_URL`

### AWS Secrets Manager

```bash
# Store production secrets
aws secretsmanager create-secret \
  --name ecommerce/prod/database \
  --secret-string '{"host":"db.example.com","username":"admin","password":"***"}'

aws secretsmanager create-secret \
  --name ecommerce/prod/jwt-secret \
  --secret-string '{"secret":"***"}'
```

---

## 📊 Monitoring & Logging

### CloudWatch Alarms

```bash
# High CPU alarm
aws cloudwatch put-metric-alarm \
  --alarm-name ecommerce-high-cpu \
  --alarm-description "Alert when CPU exceeds 80%" \
  --metric-name CPUUtilization \
  --namespace AWS/EC2 \
  --statistic Average \
  --period 300 \
  --threshold 80 \
  --comparison-operator GreaterThanThreshold \
  --evaluation-periods 2

# High error rate
aws cloudwatch put-metric-alarm \
  --alarm-name ecommerce-high-errors \
  --alarm-description "Alert on high 5xx errors" \
  --metric-name 5XXError \
  --namespace AWS/ApplicationELB \
  --statistic Sum \
  --period 60 \
  --threshold 10 \
  --comparison-operator GreaterThanThreshold \
  --evaluation-periods 1
```

### Application Monitoring

- **Sentry:** Error tracking and alerting
- **Datadog/New Relic:** APM, metrics, traces
- **CloudWatch Logs:** Centralized logging
- **UptimeRobot:** Uptime monitoring

---

## 🔄 Rollback Procedures

### Automated Rollback

```bash
#!/bin/bash
# rollback.sh

set -e

PREVIOUS_TAG=$1

echo "Rolling back to version: $PREVIOUS_TAG"

# Switch load balancer back to blue
aws elbv2 modify-rule \
  --rule-arn $ALB_RULE_ARN \
  --actions Type=forward,TargetGroupArn=$BLUE_TARGET_GROUP_ARN

# Deploy previous version to blue
ssh $PROD_USERNAME@$PROD_HOST_BLUE << EOF
  cd /home/ubuntu/ecommerce-app
  export IMAGE_TAG=$PREVIOUS_TAG
  docker-compose pull
  docker-compose up -d
EOF

# Health check
curl --fail https://example.com/health

echo "Rollback complete!"
```

### Database Rollback

```bash
# Restore from snapshot
aws rds restore-db-instance-from-db-snapshot \
  --db-instance-identifier ecommerce-prod-db-rollback \
  --db-snapshot-identifier pre-deploy-abc123

# Promote to primary (manual decision)
```

---

## ✅ Deployment Checklist

### Pre-Deployment
- [ ] All tests passing
- [ ] Code review approved
- [ ] Security scan passed
- [ ] Database migrations reviewed
- [ ] Environment variables updated
- [ ] Backup created
- [ ] Rollback plan documented

### During Deployment
- [ ] Monitor deployment logs
- [ ] Run health checks
- [ ] Verify database migrations
- [ ] Check error rates
- [ ] Monitor performance metrics

### Post-Deployment
- [ ] Smoke tests passed
- [ ] User acceptance testing
- [ ] Monitor for 30 minutes
- [ ] Update documentation
- [ ] Notify stakeholders

---

**Document Version:** 1.0  
**Last Updated:** October 24, 2025
