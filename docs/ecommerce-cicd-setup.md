# E-Commerce Shopping Cart System - CI/CD Setup

## CI/CD Overview

**Platform**: GitHub Actions
**Environments**: Development, Staging, Production
**Strategy**: Trunk-based development with feature branches

---

## 1. GitHub Actions Workflows

### Workflow Structure

```
.github/
└── workflows/
    ├── test.yml           # Run tests on PR
    ├── build.yml          # Build and validate
    ├── deploy-staging.yml # Deploy to staging
    ├── deploy-prod.yml    # Deploy to production
    └── security.yml       # Security scans
```

---

### Test Workflow (test.yml)

```yaml
name: Test Suite

on:
  push:
    branches: [ develop ]
  pull_request:
    branches: [ main, develop ]

jobs:
  lint:
    name: Lint Code
    runs-on: ubuntu-latest
    
    steps:
      - name: Checkout code
        uses: actions/checkout@v3

      - name: Setup Node.js
        uses: actions/setup-node@v3
        with:
          node-version: '18'
          cache: 'npm'

      - name: Install dependencies
        run: npm ci

      - name: Run ESLint
        run: npm run lint

      - name: Run Prettier check
        run: npm run format:check

  test-backend:
    name: Backend Tests
    runs-on: ubuntu-latest

    services:
      postgres:
        image: postgres:14
        env:
          POSTGRES_USER: postgres
          POSTGRES_PASSWORD: postgres
          POSTGRES_DB: ecommerce_test
        options: >-
          --health-cmd pg_isready
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5
        ports:
          - 5432:5432

      redis:
        image: redis:7
        options: >-
          --health-cmd "redis-cli ping"
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5
        ports:
          - 6379:6379

    steps:
      - name: Checkout code
        uses: actions/checkout@v3

      - name: Setup Node.js
        uses: actions/setup-node@v3
        with:
          node-version: '18'
          cache: 'npm'
          cache-dependency-path: backend/package-lock.json

      - name: Install dependencies
        working-directory: ./backend
        run: npm ci

      - name: Run migrations
        working-directory: ./backend
        run: npm run migrate
        env:
          NODE_ENV: test
          DATABASE_URL: postgresql://postgres:postgres@localhost:5432/ecommerce_test

      - name: Run unit tests
        working-directory: ./backend
        run: npm run test:unit
        env:
          NODE_ENV: test
          DATABASE_URL: postgresql://postgres:postgres@localhost:5432/ecommerce_test
          REDIS_HOST: localhost
          REDIS_PORT: 6379
          JWT_ACCESS_SECRET: test-secret-key
          JWT_REFRESH_SECRET: test-refresh-secret

      - name: Run integration tests
        working-directory: ./backend
        run: npm run test:integration
        env:
          NODE_ENV: test
          DATABASE_URL: postgresql://postgres:postgres@localhost:5432/ecommerce_test
          REDIS_HOST: localhost
          REDIS_PORT: 6379
          STRIPE_SECRET_KEY: ${{ secrets.STRIPE_TEST_SECRET_KEY }}

      - name: Generate coverage report
        working-directory: ./backend
        run: npm run test:coverage

      - name: Upload coverage to Codecov
        uses: codecov/codecov-action@v3
        with:
          file: ./backend/coverage/lcov.info
          flags: backend
          fail_ci_if_error: true

      - name: Check coverage threshold
        working-directory: ./backend
        run: |
          COVERAGE=$(cat coverage/coverage-summary.json | jq '.total.lines.pct')
          echo "Coverage: $COVERAGE%"
          if (( $(echo "$COVERAGE < 80" | bc -l) )); then
            echo "❌ Coverage $COVERAGE% is below 80% threshold"
            exit 1
          fi
          echo "✅ Coverage meets 80% threshold"

  test-frontend:
    name: Frontend Tests
    runs-on: ubuntu-latest

    steps:
      - name: Checkout code
        uses: actions/checkout@v3

      - name: Setup Node.js
        uses: actions/setup-node@v3
        with:
          node-version: '18'
          cache: 'npm'
          cache-dependency-path: frontend/package-lock.json

      - name: Install dependencies
        working-directory: ./frontend
        run: npm ci

      - name: Run tests
        working-directory: ./frontend
        run: npm test -- --coverage --watchAll=false

      - name: Upload coverage
        uses: codecov/codecov-action@v3
        with:
          file: ./frontend/coverage/lcov.info
          flags: frontend

      - name: Build
        working-directory: ./frontend
        run: npm run build
        env:
          CI: true

  e2e-tests:
    name: E2E Tests
    runs-on: ubuntu-latest
    needs: [test-backend, test-frontend]

    steps:
      - name: Checkout code
        uses: actions/checkout@v3

      - name: Setup Node.js
        uses: actions/setup-node@v3
        with:
          node-version: '18'

      - name: Install dependencies
        run: npm ci

      - name: Start services
        run: |
          docker-compose -f docker-compose.test.yml up -d
          sleep 30

      - name: Run migrations
        run: npm run migrate
        env:
          DATABASE_URL: postgresql://postgres:postgres@localhost:5432/ecommerce_test

      - name: Run Cypress tests
        uses: cypress-io/github-action@v5
        with:
          working-directory: ./frontend
          start: npm start
          wait-on: 'http://localhost:3000'
          wait-on-timeout: 120
          browser: chrome
          headless: true

      - name: Upload Cypress screenshots
        if: failure()
        uses: actions/upload-artifact@v3
        with:
          name: cypress-screenshots
          path: frontend/cypress/screenshots

      - name: Upload Cypress videos
        if: always()
        uses: actions/upload-artifact@v3
        with:
          name: cypress-videos
          path: frontend/cypress/videos

      - name: Cleanup
        if: always()
        run: docker-compose -f docker-compose.test.yml down
```

---

### Build Workflow (build.yml)

```yaml
name: Build and Validate

on:
  push:
    branches: [ main, develop ]
  pull_request:
    branches: [ main ]

jobs:
  build-backend:
    name: Build Backend
    runs-on: ubuntu-latest

    steps:
      - name: Checkout code
        uses: actions/checkout@v3

      - name: Setup Node.js
        uses: actions/setup-node@v3
        with:
          node-version: '18'

      - name: Install dependencies
        working-directory: ./backend
        run: npm ci

      - name: Build
        working-directory: ./backend
        run: npm run build

      - name: Upload build artifacts
        uses: actions/upload-artifact@v3
        with:
          name: backend-build
          path: backend/dist

  build-frontend:
    name: Build Frontend
    runs-on: ubuntu-latest

    steps:
      - name: Checkout code
        uses: actions/checkout@v3

      - name: Setup Node.js
        uses: actions/setup-node@v3
        with:
          node-version: '18'

      - name: Install dependencies
        working-directory: ./frontend
        run: npm ci

      - name: Build
        working-directory: ./frontend
        run: npm run build
        env:
          REACT_APP_API_URL: ${{ secrets.API_URL }}
          REACT_APP_STRIPE_PUBLIC_KEY: ${{ secrets.STRIPE_PUBLIC_KEY }}

      - name: Upload build artifacts
        uses: actions/upload-artifact@v3
        with:
          name: frontend-build
          path: frontend/build

  docker-build:
    name: Build Docker Images
    runs-on: ubuntu-latest
    needs: [build-backend, build-frontend]

    steps:
      - name: Checkout code
        uses: actions/checkout@v3

      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v2

      - name: Login to Docker Hub
        uses: docker/login-action@v2
        with:
          username: ${{ secrets.DOCKER_USERNAME }}
          password: ${{ secrets.DOCKER_PASSWORD }}

      - name: Build and push backend image
        uses: docker/build-push-action@v4
        with:
          context: ./backend
          file: ./backend/Dockerfile
          push: true
          tags: |
            ${{ secrets.DOCKER_USERNAME }}/ecommerce-backend:${{ github.sha }}
            ${{ secrets.DOCKER_USERNAME }}/ecommerce-backend:latest
          cache-from: type=registry,ref=${{ secrets.DOCKER_USERNAME }}/ecommerce-backend:buildcache
          cache-to: type=registry,ref=${{ secrets.DOCKER_USERNAME }}/ecommerce-backend:buildcache,mode=max

      - name: Build and push frontend image
        uses: docker/build-push-action@v4
        with:
          context: ./frontend
          file: ./frontend/Dockerfile
          push: true
          tags: |
            ${{ secrets.DOCKER_USERNAME }}/ecommerce-frontend:${{ github.sha }}
            ${{ secrets.DOCKER_USERNAME }}/ecommerce-frontend:latest
```

---

### Deploy to Staging (deploy-staging.yml)

```yaml
name: Deploy to Staging

on:
  push:
    branches: [ develop ]
  workflow_dispatch:

jobs:
  deploy:
    name: Deploy to Staging Environment
    runs-on: ubuntu-latest
    environment: staging

    steps:
      - name: Checkout code
        uses: actions/checkout@v3

      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v2
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region: us-east-1

      - name: Login to Amazon ECR
        id: login-ecr
        uses: aws-actions/amazon-ecr-login@v1

      - name: Build, tag, and push backend image to ECR
        env:
          ECR_REGISTRY: ${{ steps.login-ecr.outputs.registry }}
          ECR_REPOSITORY: ecommerce-backend-staging
          IMAGE_TAG: ${{ github.sha }}
        run: |
          docker build -t $ECR_REGISTRY/$ECR_REPOSITORY:$IMAGE_TAG -t $ECR_REGISTRY/$ECR_REPOSITORY:latest ./backend
          docker push $ECR_REGISTRY/$ECR_REPOSITORY:$IMAGE_TAG
          docker push $ECR_REGISTRY/$ECR_REPOSITORY:latest

      - name: Deploy backend to ECS
        run: |
          aws ecs update-service \
            --cluster ecommerce-staging \
            --service backend-service \
            --force-new-deployment \
            --region us-east-1

      - name: Build and deploy frontend to S3
        working-directory: ./frontend
        run: |
          npm ci
          npm run build
          aws s3 sync build/ s3://ecommerce-frontend-staging --delete
        env:
          REACT_APP_API_URL: https://api-staging.example.com
          REACT_APP_STRIPE_PUBLIC_KEY: ${{ secrets.STRIPE_PUBLIC_KEY_STAGING }}

      - name: Invalidate CloudFront cache
        run: |
          aws cloudfront create-invalidation \
            --distribution-id ${{ secrets.CLOUDFRONT_DISTRIBUTION_ID_STAGING }} \
            --paths "/*"

      - name: Run database migrations
        run: |
          aws ecs run-task \
            --cluster ecommerce-staging \
            --task-definition migration-task \
            --launch-type FARGATE \
            --network-configuration "awsvpcConfiguration={subnets=[${{ secrets.SUBNET_IDS }}],securityGroups=[${{ secrets.SECURITY_GROUP_ID }}],assignPublicIp=ENABLED}"

      - name: Wait for deployment
        run: |
          aws ecs wait services-stable \
            --cluster ecommerce-staging \
            --services backend-service

      - name: Run smoke tests
        run: |
          curl -f https://api-staging.example.com/health || exit 1
          curl -f https://staging.example.com || exit 1

      - name: Notify Slack
        if: always()
        uses: slackapi/slack-github-action@v1
        with:
          payload: |
            {
              "text": "Staging Deployment ${{ job.status }}",
              "blocks": [
                {
                  "type": "section",
                  "text": {
                    "type": "mrkdwn",
                    "text": "Deployment to staging: *${{ job.status }}*\nCommit: ${{ github.sha }}\nAuthor: ${{ github.actor }}"
                  }
                }
              ]
            }
        env:
          SLACK_WEBHOOK_URL: ${{ secrets.SLACK_WEBHOOK_URL }}
```

---

### Deploy to Production (deploy-prod.yml)

```yaml
name: Deploy to Production

on:
  push:
    branches: [ main ]
  workflow_dispatch:

jobs:
  deploy:
    name: Deploy to Production
    runs-on: ubuntu-latest
    environment: production

    steps:
      - name: Checkout code
        uses: actions/checkout@v3

      - name: Create deployment
        uses: chrnorm/deployment-action@v2
        id: deployment
        with:
          token: ${{ github.token }}
          environment: production

      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v2
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID_PROD }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY_PROD }}
          aws-region: us-east-1

      - name: Login to Amazon ECR
        id: login-ecr
        uses: aws-actions/amazon-ecr-login@v1

      - name: Build and push images
        env:
          ECR_REGISTRY: ${{ steps.login-ecr.outputs.registry }}
          IMAGE_TAG: ${{ github.sha }}
        run: |
          docker build -t $ECR_REGISTRY/ecommerce-backend-prod:$IMAGE_TAG -t $ECR_REGISTRY/ecommerce-backend-prod:latest ./backend
          docker push $ECR_REGISTRY/ecommerce-backend-prod:$IMAGE_TAG
          docker push $ECR_REGISTRY/ecommerce-backend-prod:latest

      - name: Create database backup
        run: |
          aws rds create-db-snapshot \
            --db-instance-identifier ecommerce-prod \
            --db-snapshot-identifier pre-deploy-$(date +%Y%m%d%H%M%S)

      - name: Deploy with blue-green strategy
        run: |
          # Deploy to green environment
          aws ecs update-service \
            --cluster ecommerce-prod \
            --service backend-service-green \
            --force-new-deployment \
            --desired-count 2

          # Wait for green to be stable
          aws ecs wait services-stable \
            --cluster ecommerce-prod \
            --services backend-service-green

          # Run health checks
          ./scripts/health-check.sh https://api-green.example.com

          # Switch traffic to green
          aws elbv2 modify-listener \
            --listener-arn ${{ secrets.ALB_LISTENER_ARN }} \
            --default-actions Type=forward,TargetGroupArn=${{ secrets.GREEN_TARGET_GROUP_ARN }}

          # Wait and monitor
          sleep 300

          # Scale down blue
          aws ecs update-service \
            --cluster ecommerce-prod \
            --service backend-service-blue \
            --desired-count 0

      - name: Deploy frontend to S3
        working-directory: ./frontend
        run: |
          npm ci
          npm run build
          aws s3 sync build/ s3://ecommerce-frontend-prod --delete
        env:
          REACT_APP_API_URL: https://api.example.com
          REACT_APP_STRIPE_PUBLIC_KEY: ${{ secrets.STRIPE_PUBLIC_KEY_PROD }}

      - name: Invalidate CloudFront
        run: |
          aws cloudfront create-invalidation \
            --distribution-id ${{ secrets.CLOUDFRONT_DISTRIBUTION_ID_PROD }} \
            --paths "/*"

      - name: Update deployment status (success)
        if: success()
        uses: chrnorm/deployment-status@v2
        with:
          token: ${{ github.token }}
          deployment-id: ${{ steps.deployment.outputs.deployment_id }}
          state: success
          environment-url: https://example.com

      - name: Update deployment status (failure)
        if: failure()
        uses: chrnorm/deployment-status@v2
        with:
          token: ${{ github.token }}
          deployment-id: ${{ steps.deployment.outputs.deployment_id }}
          state: failure

      - name: Rollback on failure
        if: failure()
        run: |
          # Revert to blue environment
          aws elbv2 modify-listener \
            --listener-arn ${{ secrets.ALB_LISTENER_ARN }} \
            --default-actions Type=forward,TargetGroupArn=${{ secrets.BLUE_TARGET_GROUP_ARN }}

      - name: Notify team
        if: always()
        uses: slackapi/slack-github-action@v1
        with:
          payload: |
            {
              "text": "Production Deployment ${{ job.status }}",
              "blocks": [
                {
                  "type": "section",
                  "text": {
                    "type": "mrkdwn",
                    "text": "🚀 Production deployment: *${{ job.status }}*\nCommit: `${{ github.sha }}`\nAuthor: ${{ github.actor }}\nURL: https://example.com"
                  }
                }
              ]
            }
        env:
          SLACK_WEBHOOK_URL: ${{ secrets.SLACK_WEBHOOK_URL }}
```

---

### Security Scanning (security.yml)

```yaml
name: Security Scans

on:
  push:
    branches: [ main, develop ]
  pull_request:
    branches: [ main, develop ]
  schedule:
    - cron: '0 0 * * 0'  # Weekly on Sunday

jobs:
  dependency-scan:
    name: Dependency Vulnerability Scan
    runs-on: ubuntu-latest

    steps:
      - name: Checkout code
        uses: actions/checkout@v3

      - name: Run npm audit (backend)
        working-directory: ./backend
        run: npm audit --audit-level=high

      - name: Run npm audit (frontend)
        working-directory: ./frontend
        run: npm audit --audit-level=high

      - name: Run Snyk scan
        uses: snyk/actions/node@master
        env:
          SNYK_TOKEN: ${{ secrets.SNYK_TOKEN }}
        with:
          args: --severity-threshold=high

  sast-scan:
    name: Static Application Security Testing
    runs-on: ubuntu-latest

    steps:
      - name: Checkout code
        uses: actions/checkout@v3

      - name: Run Semgrep
        uses: returntocorp/semgrep-action@v1
        with:
          config: >-
            p/security-audit
            p/secrets
            p/owasp-top-ten

  container-scan:
    name: Container Image Scan
    runs-on: ubuntu-latest

    steps:
      - name: Checkout code
        uses: actions/checkout@v3

      - name: Build image
        run: docker build -t ecommerce-backend:test ./backend

      - name: Run Trivy vulnerability scanner
        uses: aquasecurity/trivy-action@master
        with:
          image-ref: ecommerce-backend:test
          format: 'sarif'
          output: 'trivy-results.sarif'

      - name: Upload Trivy results to GitHub Security tab
        uses: github/codeql-action/upload-sarif@v2
        with:
          sarif_file: 'trivy-results.sarif'

  secret-scan:
    name: Secret Detection
    runs-on: ubuntu-latest

    steps:
      - name: Checkout code
        uses: actions/checkout@v3
        with:
          fetch-depth: 0

      - name: TruffleHog OSS
        uses: trufflesecurity/trufflehog@main
        with:
          path: ./
          base: ${{ github.event.repository.default_branch }}
          head: HEAD
```

---

## 2. Environment Configuration

### GitHub Secrets

**Staging:**
- `AWS_ACCESS_KEY_ID`
- `AWS_SECRET_ACCESS_KEY`
- `CLOUDFRONT_DISTRIBUTION_ID_STAGING`
- `STRIPE_PUBLIC_KEY_STAGING`
- `STRIPE_SECRET_KEY_STAGING`
- `DATABASE_URL_STAGING`
- `REDIS_URL_STAGING`

**Production:**
- `AWS_ACCESS_KEY_ID_PROD`
- `AWS_SECRET_ACCESS_KEY_PROD`
- `CLOUDFRONT_DISTRIBUTION_ID_PROD`
- `STRIPE_PUBLIC_KEY_PROD`
- `STRIPE_SECRET_KEY_PROD`
- `DATABASE_URL_PROD`
- `REDIS_URL_PROD`

**General:**
- `DOCKER_USERNAME`
- `DOCKER_PASSWORD`
- `SNYK_TOKEN`
- `SLACK_WEBHOOK_URL`
- `CODECOV_TOKEN`

---

## 3. Deployment Scripts

### Health Check Script

```bash
#!/bin/bash
# scripts/health-check.sh

API_URL=$1
MAX_RETRIES=30
RETRY_DELAY=10

echo "Starting health checks for $API_URL"

for i in $(seq 1 $MAX_RETRIES); do
  HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" $API_URL/health)
  
  if [ "$HTTP_CODE" = "200" ]; then
    echo "✅ Health check passed"
    exit 0
  fi
  
  echo "Attempt $i/$MAX_RETRIES: HTTP $HTTP_CODE - Retrying in ${RETRY_DELAY}s..."
  sleep $RETRY_DELAY
done

echo "❌ Health check failed after $MAX_RETRIES attempts"
exit 1
```

---

## 4. Docker Configuration

### Backend Dockerfile

```dockerfile
# backend/Dockerfile
FROM node:18-alpine AS builder

WORKDIR /app

COPY package*.json ./
RUN npm ci --only=production

COPY . .

FROM node:18-alpine

WORKDIR /app

COPY --from=builder /app/node_modules ./node_modules
COPY --from=builder /app .

EXPOSE 3000

CMD ["node", "src/server.js"]
```

### Frontend Dockerfile

```dockerfile
# frontend/Dockerfile
FROM node:18-alpine AS builder

WORKDIR /app

COPY package*.json ./
RUN npm ci

COPY . .
RUN npm run build

FROM nginx:alpine

COPY --from=builder /app/build /usr/share/nginx/html
COPY nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
```

---

## 5. Monitoring & Alerting

### CloudWatch Alarms

```yaml
# cloudformation/alarms.yml
Resources:
  HighErrorRateAlarm:
    Type: AWS::CloudWatch::Alarm
    Properties:
      AlarmName: ecommerce-high-error-rate
      MetricName: 5XXError
      Namespace: AWS/ApplicationELB
      Statistic: Sum
      Period: 300
      EvaluationPeriods: 2
      Threshold: 10
      ComparisonOperator: GreaterThanThreshold
      AlarmActions:
        - !Ref SNSTopic

  HighResponseTimeAlarm:
    Type: AWS::CloudWatch::Alarm
    Properties:
      AlarmName: ecommerce-high-response-time
      MetricName: TargetResponseTime
      Namespace: AWS/ApplicationELB
      Statistic: Average
      Period: 300
      EvaluationPeriods: 2
      Threshold: 500
      ComparisonOperator: GreaterThanThreshold
      AlarmActions:
        - !Ref SNSTopic
```

---

## CI/CD Best Practices

1. **Fast Feedback**: Run fastest tests first
2. **Parallel Execution**: Run independent jobs in parallel
3. **Caching**: Cache dependencies to speed up builds
4. **Artifact Management**: Store build artifacts for rollback
5. **Blue-Green Deployment**: Zero-downtime deployments
6. **Automated Rollback**: Rollback on health check failures
7. **Security Scanning**: Automated security checks
8. **Environment Parity**: Staging mirrors production
9. **Feature Flags**: Use feature flags for gradual rollouts
10. **Monitoring**: Track deployment metrics and errors
