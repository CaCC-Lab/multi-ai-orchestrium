# E-Commerce Shopping Cart System - Technical Architecture

## System Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                         Client Layer                         │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐   │
│  │ Desktop  │  │  Tablet  │  │  Mobile  │  │  Admin   │   │
│  │  Browser │  │  Browser │  │  Browser │  │   Panel  │   │
│  └────┬─────┘  └────┬─────┘  └────┬─────┘  └────┬─────┘   │
└───────┼─────────────┼─────────────┼─────────────┼──────────┘
        │             │             │             │
        └─────────────┴─────────────┴─────────────┘
                        │
        ┌───────────────▼────────────────┐
        │          CloudFront CDN         │
        │      (Static Assets)            │
        └───────────────┬────────────────┘
                        │
        ┌───────────────▼────────────────┐
        │      Load Balancer (ELB)        │
        └───────────────┬────────────────┘
                        │
        ┌───────────────▼────────────────┐
        │     React Frontend (S3)         │
        │    - Redux State Management     │
        │    - Client-side Routing        │
        └───────────────┬────────────────┘
                        │
                    HTTPS/REST
                        │
        ┌───────────────▼────────────────┐
        │     API Gateway / Nginx         │
        │    - Rate Limiting              │
        │    - Request Validation         │
        └───────────────┬────────────────┘
                        │
        ┌───────────────▼────────────────┐
        │    Express.js Backend (EC2)     │
        │  ┌──────────────────────────┐  │
        │  │   Controller Layer       │  │
        │  └──────────┬───────────────┘  │
        │  ┌──────────▼───────────────┐  │
        │  │   Service Layer          │  │
        │  └──────────┬───────────────┘  │
        │  ┌──────────▼───────────────┐  │
        │  │   Data Access Layer      │  │
        │  └──────────┬───────────────┘  │
        └─────────────┼──────────────────┘
                      │
        ┌─────────────┼─────────────┐
        │             │             │
        ▼             ▼             ▼
  ┌─────────┐   ┌─────────┐   ┌─────────┐
  │PostgreSQL│   │  Redis  │   │   S3    │
  │   (RDS)  │   │ (Cache) │   │ (Images)│
  └─────────┘   └─────────┘   └─────────┘
        │
        │
  ┌─────▼──────────────────────────┐
  │    External Services            │
  │  - Stripe (Payments)            │
  │  - SendGrid (Email)             │
  │  - Currency API (Exchange)      │
  └─────────────────────────────────┘
```

---

## Technology Stack

### Frontend
- **Framework**: React 18+
- **State Management**: Redux Toolkit
- **Routing**: React Router v6
- **HTTP Client**: Axios
- **Forms**: React Hook Form + Yup validation
- **Styling**: Tailwind CSS / Material-UI
- **Build Tool**: Vite / Create React App
- **Testing**: Jest + React Testing Library

### Backend
- **Runtime**: Node.js 18+ LTS
- **Framework**: Express.js 4.x
- **ORM**: Sequelize 6.x
- **Authentication**: JWT (jsonwebtoken)
- **Validation**: Joi / Express-validator
- **Password Hashing**: bcrypt
- **File Upload**: Multer
- **Email**: SendGrid SDK
- **Payment**: Stripe SDK
- **Testing**: Jest + Supertest

### Database
- **Primary DB**: PostgreSQL 14+
- **Cache**: Redis 7+
- **ORM**: Sequelize with migrations
- **Connection Pool**: pg-pool

### Infrastructure
- **Hosting**: AWS EC2 (t3.medium minimum)
- **Database**: AWS RDS PostgreSQL
- **Cache**: AWS ElastiCache Redis
- **Storage**: AWS S3 for images
- **CDN**: CloudFront
- **Load Balancer**: AWS ELB
- **CI/CD**: GitHub Actions

### DevOps
- **Containerization**: Docker + Docker Compose
- **Reverse Proxy**: Nginx
- **Process Manager**: PM2
- **Monitoring**: CloudWatch / DataDog
- **Logging**: Winston + CloudWatch Logs

---

## Architecture Patterns

### Backend Architecture: Layered Architecture

```
┌─────────────────────────────────────────┐
│         Routes / Controllers             │
│  - Request parsing                       │
│  - Response formatting                   │
│  - Input validation                      │
└──────────────┬──────────────────────────┘
               │
┌──────────────▼──────────────────────────┐
│           Middleware Layer               │
│  - Authentication (JWT)                  │
│  - Authorization (RBAC)                  │
│  - Rate Limiting                         │
│  - Error Handling                        │
└──────────────┬──────────────────────────┘
               │
┌──────────────▼──────────────────────────┐
│          Service Layer                   │
│  - Business logic                        │
│  - Transaction management                │
│  - External API calls                    │
│  - Email notifications                   │
└──────────────┬──────────────────────────┘
               │
┌──────────────▼──────────────────────────┐
│       Data Access Layer (DAL)            │
│  - Sequelize models                      │
│  - Database queries                      │
│  - Cache operations                      │
└──────────────┬──────────────────────────┘
               │
┌──────────────▼──────────────────────────┐
│         Database Layer                   │
│  - PostgreSQL                            │
│  - Redis Cache                           │
└─────────────────────────────────────────┘
```

### Frontend Architecture: Feature-based Structure

```
frontend/src/
├── features/
│   ├── auth/
│   │   ├── components/
│   │   ├── hooks/
│   │   ├── services/
│   │   └── authSlice.js (Redux)
│   ├── products/
│   │   ├── components/
│   │   ├── hooks/
│   │   ├── services/
│   │   └── productsSlice.js
│   ├── cart/
│   └── orders/
├── shared/
│   ├── components/
│   ├── hooks/
│   └── utils/
└── store/
    └── store.js
```

---

## Data Flow

### User Purchase Flow

```
1. User browses products
   └─> Frontend: ProductList component
       └─> Redux: Fetch products from API
           └─> Backend: GET /api/products
               └─> DB: Query products table
                   └─> Cache: Check Redis first
                       └─> Return products to frontend

2. User adds item to cart
   └─> Frontend: Add to Cart button
       └─> Redux: Dispatch addToCart action
           └─> Backend: POST /api/cart/items
               └─> Auth: Verify JWT token
                   └─> DB: Insert/Update cart_items
                       └─> Return updated cart

3. User proceeds to checkout
   └─> Frontend: Checkout page
       └─> Redux: Fetch cart items
           └─> Backend: GET /api/cart
               └─> DB: Query cart with items
                   └─> Validate inventory
                       └─> Return cart summary

4. User submits payment
   └─> Frontend: Payment form (Stripe Elements)
       └─> Stripe: Create payment method
           └─> Backend: POST /api/orders
               └─> Transaction START
                   ├─> Stripe: Charge payment
                   ├─> DB: Create order record
                   ├─> DB: Create order_items
                   ├─> DB: Reduce inventory
                   ├─> DB: Clear cart
                   └─> SendGrid: Send confirmation email
               └─> Transaction COMMIT
                   └─> Return order details

5. User receives confirmation
   └─> Frontend: Order confirmation page
       └─> Email: Order confirmation email
```

---

## Security Architecture

### Authentication Flow

```
1. User Login
   └─> POST /api/auth/login
       └─> Validate credentials
           └─> Compare hashed password (bcrypt)
               └─> Generate JWT tokens
                   ├─> Access Token (15 min expiry)
                   └─> Refresh Token (7 days expiry)
                       └─> Store refresh token in DB
                           └─> Return tokens to client

2. Protected Request
   └─> Include Authorization: Bearer <access_token>
       └─> JWT Middleware validates token
           └─> Check token expiry
               └─> Verify signature
                   └─> Extract user ID
                       └─> Attach user to request
                           └─> Process request

3. Token Refresh
   └─> POST /api/auth/refresh
       └─> Validate refresh token
           └─> Check DB for valid token
               └─> Generate new access token
                   └─> Return new token
```

### Security Layers

1. **Transport Security**
   - HTTPS only (TLS 1.3)
   - HSTS headers
   - Secure cookies (httpOnly, secure, sameSite)

2. **Input Validation**
   - Request validation middleware
   - SQL injection prevention (Sequelize ORM)
   - XSS prevention (sanitize-html)
   - CSRF tokens for state-changing operations

3. **Authentication & Authorization**
   - JWT with short expiry
   - Refresh token rotation
   - Role-based access control (RBAC)
   - Rate limiting per user/IP

4. **Data Protection**
   - Password hashing (bcrypt, rounds: 12)
   - Sensitive data encryption at rest
   - PII data masking in logs
   - Secure environment variables

5. **API Security**
   - Rate limiting (express-rate-limit)
   - Request size limits
   - CORS configuration
   - API versioning

---

## Caching Strategy

### Multi-layer Caching

```
1. Browser Cache
   └─> Static assets (CDN: CloudFront)
       └─> Cache-Control headers

2. Application Cache (Redis)
   └─> Product listings (TTL: 5 minutes)
   └─> Product details (TTL: 10 minutes)
   └─> User session data (TTL: 30 minutes)
   └─> Cart data (TTL: 1 hour)

3. Database Cache
   └─> Query result caching
   └─> Connection pooling
```

### Cache Invalidation Strategy

- **Time-based**: TTL expiration
- **Event-based**: Clear on update/delete
- **Manual**: Admin cache clear endpoint

---

## Performance Optimization

### Backend Optimization
- Connection pooling (max: 20 connections)
- Database query optimization
  - Proper indexing
  - Eager loading for relationships
  - Pagination for large datasets
- Redis caching for hot data
- Async operations for non-critical tasks
- Compression middleware (gzip)

### Frontend Optimization
- Code splitting (React.lazy)
- Image optimization (lazy loading)
- Bundle optimization (tree shaking)
- Memoization (useMemo, useCallback)
- Virtual scrolling for long lists
- Debouncing search inputs

### Database Optimization
- Indexes on frequently queried columns
- Compound indexes for multi-column queries
- Query optimization (EXPLAIN ANALYZE)
- Read replicas for read-heavy operations
- Partitioning for large tables

---

## Scalability Considerations

### Horizontal Scaling
- Stateless backend servers
- Session data in Redis (not in-memory)
- Load balancer distribution
- Auto-scaling groups (EC2)

### Database Scaling
- Read replicas for read operations
- Connection pooling
- Query optimization
- Caching layer (Redis)

### File Storage Scaling
- CDN for image delivery
- S3 for unlimited storage
- Image optimization service

---

## Monitoring & Observability

### Metrics to Monitor
- API response times (target: < 500ms)
- Error rates
- Database query performance
- Cache hit rates
- Payment success/failure rates
- User registration/login rates

### Logging Strategy
- Structured logging (JSON format)
- Log levels: ERROR, WARN, INFO, DEBUG
- Request/Response logging
- Error stack traces
- User action audit logs

### Alerting
- API downtime
- High error rates (> 5%)
- Database connection failures
- Payment processing failures
- Disk space warnings

---

## Disaster Recovery

### Backup Strategy
- Database: Daily automated backups (retention: 30 days)
- Point-in-time recovery enabled
- Cross-region backup replication
- Application code: Git repository

### Recovery Plan
- RTO (Recovery Time Objective): 1 hour
- RPO (Recovery Point Objective): 24 hours
- Automated backup restoration scripts
- Database rollback procedures
- Blue-green deployment strategy
