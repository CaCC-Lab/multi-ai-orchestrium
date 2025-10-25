# E-Commerce Shopping Cart - Technical Architecture

## System Overview

This document outlines the technical architecture for the E-Commerce Shopping Cart system, a full-stack web application built with modern technologies to deliver a scalable, secure, and performant online shopping experience.

---

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                         CLIENT LAYER                             │
├─────────────────────────────────────────────────────────────────┤
│  React Application (SPA)                                         │
│  ├── Components (React)                                          │
│  ├── State Management (Redux)                                    │
│  ├── Routing (React Router)                                      │
│  └── API Client (Axios)                                          │
└───────────────────────┬─────────────────────────────────────────┘
                        │ HTTPS/REST
                        │
┌───────────────────────▼─────────────────────────────────────────┐
│                      CDN LAYER (CloudFront)                      │
│  ├── Static Assets (JS, CSS, Images)                            │
│  └── Cache Headers                                               │
└───────────────────────┬─────────────────────────────────────────┘
                        │
┌───────────────────────▼─────────────────────────────────────────┐
│                   LOAD BALANCER (AWS ELB)                        │
└───────────────────────┬─────────────────────────────────────────┘
                        │
┌───────────────────────▼─────────────────────────────────────────┐
│                    APPLICATION LAYER                             │
├─────────────────────────────────────────────────────────────────┤
│  Node.js + Express Server (EC2)                                  │
│  ├── Routes                                                      │
│  ├── Controllers                                                 │
│  ├── Services                                                    │
│  ├── Middleware                                                  │
│  └── Validators                                                  │
└────────┬──────────────┬──────────────┬──────────────┬───────────┘
         │              │              │              │
         │              │              │              │
┌────────▼────────┐ ┌──▼─────────┐ ┌─▼──────────┐ ┌─▼──────────┐
│  PostgreSQL     │ │   Redis    │ │  Stripe    │ │ SendGrid   │
│  (RDS)          │ │ (ElastiCache)│ │   API      │ │    API     │
│  - Users        │ │  - Cache   │ │  - Payments│ │  - Emails  │
│  - Products     │ │  - Sessions│ └────────────┘ └────────────┘
│  - Orders       │ └────────────┘
│  - Carts        │
└─────────────────┘
         │
         │
┌────────▼────────┐
│    AWS S3       │
│ - Product Images│
└─────────────────┘
```

---

## Technology Stack

### Frontend
- **Framework**: React 18+
- **State Management**: Redux Toolkit
- **Routing**: React Router v6
- **HTTP Client**: Axios
- **Form Handling**: Formik / React Hook Form
- **Validation**: Yup
- **UI Components**: Material-UI / Ant Design / Custom
- **Styling**: CSS Modules / Styled Components / Tailwind CSS
- **Payment UI**: @stripe/react-stripe-js
- **Build Tool**: Vite / Create React App

### Backend
- **Runtime**: Node.js (LTS)
- **Framework**: Express.js
- **ORM**: Sequelize
- **Authentication**: JWT (jsonwebtoken)
- **Validation**: Joi / express-validator
- **File Upload**: Multer
- **Email**: @sendgrid/mail
- **Payment**: stripe
- **Image Processing**: Sharp
- **Logging**: Winston
- **Testing**: Jest, Supertest

### Database
- **Primary Database**: PostgreSQL 14+
- **Cache**: Redis 6+
- **ORM**: Sequelize

### Infrastructure
- **Hosting**: AWS
  - EC2 (Application Server)
  - RDS (PostgreSQL)
  - ElastiCache (Redis)
  - S3 (File Storage)
  - CloudFront (CDN)
  - ELB (Load Balancer)
- **CI/CD**: GitHub Actions
- **Containerization**: Docker
- **Monitoring**: CloudWatch, Sentry (optional)

### Third-Party Services
- **Payment Processing**: Stripe
- **Email Service**: SendGrid
- **SSL Certificates**: AWS Certificate Manager

---

## System Components

### 1. Frontend Architecture

```
src/
├── components/          # Reusable UI components
│   ├── common/         # Shared components (Button, Input, Modal)
│   ├── layout/         # Layout components (Header, Footer, Sidebar)
│   ├── auth/           # Authentication components
│   ├── products/       # Product-related components
│   ├── cart/           # Cart components
│   └── checkout/       # Checkout components
├── pages/              # Page-level components
│   ├── HomePage.jsx
│   ├── ProductListPage.jsx
│   ├── ProductDetailPage.jsx
│   ├── CartPage.jsx
│   ├── CheckoutPage.jsx
│   └── AdminDashboard.jsx
├── store/              # Redux store
│   ├── slices/         # Redux slices (auth, products, cart, orders)
│   ├── actions/        # Action creators
│   ├── selectors/      # Reselect selectors
│   └── store.js        # Store configuration
├── services/           # API service layer
│   ├── api.js          # Axios instance
│   ├── authService.js
│   ├── productService.js
│   ├── cartService.js
│   └── orderService.js
├── hooks/              # Custom React hooks
├── utils/              # Utility functions
├── constants/          # Constants and enums
├── routes/             # Route configuration
└── App.jsx             # Root component
```

**Key Patterns**:
- **Component-based architecture**: Modular, reusable components
- **Container/Presentational pattern**: Separate logic from UI
- **Redux for global state**: Predictable state management
- **Custom hooks**: Reusable stateful logic
- **Service layer**: Centralized API communication

### 2. Backend Architecture

```
backend/
├── controllers/        # Request handlers
│   ├── authController.js
│   ├── productController.js
│   ├── cartController.js
│   ├── orderController.js
│   └── adminController.js
├── services/           # Business logic
│   ├── authService.js
│   ├── productService.js
│   ├── cartService.js
│   ├── orderService.js
│   ├── paymentService.js
│   └── emailService.js
├── models/             # Sequelize models
│   ├── User.js
│   ├── Product.js
│   ├── Category.js
│   ├── Cart.js
│   ├── Order.js
│   └── associations.js
├── middleware/         # Express middleware
│   ├── auth.js         # Authentication
│   ├── authorize.js    # Authorization
│   ├── errorHandler.js
│   ├── validator.js
│   ├── rateLimiter.js
│   └── logger.js
├── routes/             # API routes
│   ├── authRoutes.js
│   ├── productRoutes.js
│   ├── cartRoutes.js
│   ├── orderRoutes.js
│   └── adminRoutes.js
├── utils/              # Utility functions
│   ├── jwtUtils.js
│   ├── emailTemplates.js
│   └── s3Utils.js
├── migrations/         # Database migrations
├── seeders/            # Database seeders
├── __tests__/          # Tests
└── server.js           # Entry point
```

**Key Patterns**:
- **MVC architecture**: Models, Controllers, Services
- **Layered architecture**: Routes → Controllers → Services → Models
- **Middleware chain**: Reusable request processing
- **Repository pattern**: Data access abstraction
- **Dependency injection**: Loose coupling

### 3. Database Schema

#### Users Table
```sql
CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email VARCHAR(255) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    first_name VARCHAR(100),
    last_name VARCHAR(100),
    role VARCHAR(20) DEFAULT 'user', -- 'user', 'admin', 'superadmin'
    is_verified BOOLEAN DEFAULT false,
    verification_token VARCHAR(255),
    reset_password_token VARCHAR(255),
    reset_password_expires TIMESTAMP,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_users_role ON users(role);
```

#### Products Table
```sql
CREATE TABLE products (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(255) NOT NULL,
    slug VARCHAR(255) UNIQUE NOT NULL,
    description TEXT,
    price DECIMAL(10, 2) NOT NULL,
    compare_at_price DECIMAL(10, 2),
    sku VARCHAR(100) UNIQUE,
    stock_quantity INTEGER DEFAULT 0,
    low_stock_threshold INTEGER DEFAULT 10,
    category_id UUID REFERENCES categories(id),
    images JSONB, -- Array of image URLs
    is_active BOOLEAN DEFAULT true,
    rating_average DECIMAL(3, 2) DEFAULT 0,
    rating_count INTEGER DEFAULT 0,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_products_category ON products(category_id);
CREATE INDEX idx_products_slug ON products(slug);
CREATE INDEX idx_products_price ON products(price);
CREATE INDEX idx_products_name ON products USING GIN(to_tsvector('english', name));
```

#### Categories Table
```sql
CREATE TABLE categories (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(100) NOT NULL,
    slug VARCHAR(100) UNIQUE NOT NULL,
    parent_id UUID REFERENCES categories(id),
    description TEXT,
    image_url VARCHAR(500),
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);
```

#### Carts Table
```sql
CREATE TABLE carts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES users(id),
    session_id VARCHAR(255), -- For guest carts
    expires_at TIMESTAMP,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_carts_user ON carts(user_id);
CREATE INDEX idx_carts_session ON carts(session_id);
```

#### Cart Items Table
```sql
CREATE TABLE cart_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    cart_id UUID REFERENCES carts(id) ON DELETE CASCADE,
    product_id UUID REFERENCES products(id),
    quantity INTEGER NOT NULL,
    price DECIMAL(10, 2) NOT NULL, -- Price at time of adding
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_cart_items_cart ON cart_items(cart_id);
```

#### Orders Table
```sql
CREATE TABLE orders (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    order_number VARCHAR(50) UNIQUE NOT NULL,
    user_id UUID REFERENCES users(id),
    status VARCHAR(50) DEFAULT 'pending', -- pending, confirmed, shipped, delivered, cancelled
    payment_status VARCHAR(50) DEFAULT 'pending', -- pending, paid, failed, refunded
    currency VARCHAR(3) DEFAULT 'USD',
    subtotal DECIMAL(10, 2) NOT NULL,
    tax DECIMAL(10, 2) DEFAULT 0,
    shipping_cost DECIMAL(10, 2) DEFAULT 0,
    total DECIMAL(10, 2) NOT NULL,
    stripe_payment_intent_id VARCHAR(255),
    shipping_address JSONB,
    billing_address JSONB,
    tracking_number VARCHAR(100),
    notes TEXT,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_orders_user ON orders(user_id);
CREATE INDEX idx_orders_status ON orders(status);
CREATE INDEX idx_orders_order_number ON orders(order_number);
```

#### Order Items Table
```sql
CREATE TABLE order_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id UUID REFERENCES orders(id) ON DELETE CASCADE,
    product_id UUID REFERENCES products(id),
    product_name VARCHAR(255) NOT NULL, -- Snapshot
    product_sku VARCHAR(100),
    quantity INTEGER NOT NULL,
    price DECIMAL(10, 2) NOT NULL,
    total DECIMAL(10, 2) NOT NULL,
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_order_items_order ON order_items(order_id);
```

#### Reviews Table
```sql
CREATE TABLE reviews (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    product_id UUID REFERENCES products(id) ON DELETE CASCADE,
    user_id UUID REFERENCES users(id),
    rating INTEGER CHECK (rating >= 1 AND rating <= 5),
    title VARCHAR(255),
    comment TEXT,
    is_verified_purchase BOOLEAN DEFAULT false,
    is_approved BOOLEAN DEFAULT true,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_reviews_product ON reviews(product_id);
CREATE INDEX idx_reviews_user ON reviews(user_id);
```

---

## API Architecture

### RESTful API Design

**Base URL**: `https://api.example.com/api/v1`

#### Authentication Endpoints
```
POST   /auth/register         - Register new user
POST   /auth/login            - Login user
POST   /auth/logout           - Logout user
POST   /auth/refresh          - Refresh access token
POST   /auth/forgot-password  - Request password reset
POST   /auth/reset-password   - Reset password
GET    /auth/verify/:token    - Verify email
POST   /auth/resend-verification - Resend verification email
```

#### Product Endpoints
```
GET    /products              - List products (with pagination, filters, search)
GET    /products/:id          - Get single product
POST   /products              - Create product (admin)
PUT    /products/:id          - Update product (admin)
DELETE /products/:id          - Delete product (admin)
POST   /products/:id/images   - Upload product image (admin)
GET    /products/:id/reviews  - Get product reviews
POST   /products/:id/reviews  - Create review (authenticated)
```

#### Category Endpoints
```
GET    /categories            - List categories
GET    /categories/:id        - Get single category
POST   /categories            - Create category (admin)
PUT    /categories/:id        - Update category (admin)
DELETE /categories/:id        - Delete category (admin)
```

#### Cart Endpoints
```
GET    /cart                  - Get user cart
POST   /cart/items            - Add item to cart
PUT    /cart/items/:id        - Update cart item quantity
DELETE /cart/items/:id        - Remove item from cart
DELETE /cart                  - Clear cart
```

#### Order Endpoints
```
GET    /orders                - Get user orders
GET    /orders/:id            - Get single order
POST   /orders                - Create order
POST   /orders/:id/cancel     - Cancel order
GET    /orders/:id/invoice    - Download invoice
```

#### Checkout Endpoints
```
POST   /checkout/validate     - Validate checkout
POST   /checkout/payment-intent - Create Stripe payment intent
POST   /checkout/confirm      - Confirm order after payment
```

#### Admin Endpoints
```
GET    /admin/dashboard       - Get dashboard analytics
GET    /admin/orders          - Get all orders (with filters)
PUT    /admin/orders/:id      - Update order status
GET    /admin/users           - Get all users
PUT    /admin/users/:id       - Update user
POST   /admin/products/import - Bulk import products
```

#### Webhook Endpoints
```
POST   /webhooks/stripe       - Stripe webhook handler
```

### API Response Format

**Success Response**:
```json
{
  "success": true,
  "data": { ... },
  "meta": {
    "pagination": {
      "page": 1,
      "limit": 20,
      "total": 100,
      "totalPages": 5
    }
  }
}
```

**Error Response**:
```json
{
  "success": false,
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "Invalid input data",
    "details": [
      {
        "field": "email",
        "message": "Email is required"
      }
    ]
  }
}
```

---

## Authentication & Authorization

### JWT Token Strategy

1. **Access Token**:
   - Short-lived (15 minutes)
   - Stored in memory (React state)
   - Sent in Authorization header: `Bearer <token>`

2. **Refresh Token**:
   - Long-lived (7 days)
   - Stored in httpOnly cookie (secure)
   - Used to obtain new access tokens

### Token Flow
```
1. User logs in → Receive access token + refresh token
2. Access token stored in Redux state
3. Refresh token stored in httpOnly cookie
4. Every API request includes access token in header
5. If access token expires (401) → Use refresh token to get new access token
6. If refresh token expires → Redirect to login
```

### Role-Based Access Control (RBAC)

**Roles**:
- `user`: Regular customer
- `admin`: Store administrator
- `superadmin`: System administrator

**Middleware**:
```javascript
// Require authentication
app.use('/api/cart', authenticate);

// Require specific role
app.use('/api/admin', authenticate, authorize(['admin', 'superadmin']));
```

---

## Security Measures

### Input Validation
- Joi schemas for request validation
- Sanitize user inputs
- Type checking with TypeScript (optional)

### SQL Injection Prevention
- Use Sequelize ORM (parameterized queries)
- Never concatenate user input into queries

### XSS Protection
- Set security headers (helmet.js)
- Content Security Policy (CSP)
- Escape user-generated content
- Sanitize HTML inputs

### CSRF Protection
- CSRF tokens for state-changing requests
- SameSite cookie attribute
- Verify Origin/Referer headers

### Password Security
- bcrypt hashing (salt rounds: 10)
- Password strength requirements
- Rate limiting on login attempts

### Rate Limiting
```javascript
// General rate limit: 100 requests per 15 minutes
app.use(rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 100
}));

// Strict rate limit for auth: 5 requests per 15 minutes
app.use('/api/auth/login', rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 5
}));
```

### Session Management
- Secure, httpOnly cookies
- Session expiration
- Token rotation
- Logout functionality

### HTTPS
- Enforce HTTPS in production
- SSL certificates via AWS Certificate Manager
- Redirect HTTP to HTTPS

---

## Performance Optimization

### Caching Strategy

**Redis Cache Layers**:
1. **Application Cache**:
   - Product catalog (15 minutes TTL)
   - Category list (1 hour TTL)
   - User sessions

2. **Query Result Cache**:
   - Popular products
   - Search results (short TTL)

3. **Cache Invalidation**:
   - On product update/delete
   - On category changes
   - Manual flush for admin actions

### Database Optimization

1. **Indexing**:
   - Primary keys (UUID)
   - Foreign keys
   - Search fields (name, email)
   - Filter fields (category, price)
   - Full-text search indexes

2. **Query Optimization**:
   - Use eager loading (includes) wisely
   - Limit SELECT fields
   - Pagination for large datasets
   - Database query analysis

3. **Connection Pooling**:
   - Sequelize connection pool (min: 5, max: 30)

### CDN Strategy
- Static assets (JS, CSS, images) served via CloudFront
- Cache-Control headers
- Asset versioning for cache busting

### Frontend Optimization
- Code splitting (React.lazy)
- Lazy loading images
- Debounced search
- Memoization (React.memo, useMemo)
- Virtualized lists for long product lists

---

## Deployment Architecture

### AWS Infrastructure

```
┌──────────────────────────────────────────────────────────┐
│                    Route 53 (DNS)                        │
└────────────────────┬─────────────────────────────────────┘
                     │
┌────────────────────▼─────────────────────────────────────┐
│              CloudFront (CDN)                            │
│  - Static Assets (S3)                                    │
│  - SSL Termination                                       │
└────────────────────┬─────────────────────────────────────┘
                     │
┌────────────────────▼─────────────────────────────────────┐
│        Application Load Balancer (ALB)                   │
│  - Health Checks                                         │
│  - SSL Termination                                       │
└────────────────────┬─────────────────────────────────────┘
                     │
         ┌───────────┴───────────┐
         │                       │
┌────────▼────────┐    ┌────────▼────────┐
│   EC2 Instance  │    │   EC2 Instance  │
│   (App Server)  │    │   (App Server)  │
│   - Node.js     │    │   - Node.js     │
│   - Docker      │    │   - Docker      │
└────────┬────────┘    └────────┬────────┘
         │                       │
         └───────────┬───────────┘
                     │
         ┌───────────┼───────────┬──────────────┐
         │           │           │              │
┌────────▼──────┐ ┌─▼────────┐ ┌▼──────────┐ ┌─▼─────────┐
│   RDS         │ │ElastiCache│ │    S3     │ │CloudWatch │
│ (PostgreSQL)  │ │  (Redis)  │ │  (Images) │ │(Monitoring)│
└───────────────┘ └───────────┘ └───────────┘ └───────────┘
```

### CI/CD Pipeline

**GitHub Actions Workflow**:
```yaml
name: Deploy to Production

on:
  push:
    branches: [main]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - Checkout code
      - Install dependencies
      - Run linters
      - Run unit tests
      - Run integration tests

  build:
    needs: test
    runs-on: ubuntu-latest
    steps:
      - Build Docker images
      - Push to ECR

  deploy:
    needs: build
    runs-on: ubuntu-latest
    steps:
      - SSH to EC2
      - Pull latest images
      - Run database migrations
      - Restart services
      - Health check
```

---

## Monitoring & Logging

### Application Logging
- **Winston**: Structured logging
- **Log Levels**: error, warn, info, debug
- **Log Rotation**: Daily, 14 days retention

### Error Tracking
- **Sentry** (optional): Real-time error tracking
- Capture unhandled exceptions
- Performance monitoring

### Metrics
- API response times
- Database query times
- Cache hit/miss rates
- Error rates
- User activity

### Alerting
- High error rates
- Slow API responses
- Database connection issues
- Low disk space
- High CPU/memory usage

---

## Scalability Considerations

### Horizontal Scaling
- Multiple EC2 instances behind load balancer
- Stateless application design
- Shared session store (Redis)

### Database Scaling
- Read replicas for read-heavy operations
- Connection pooling
- Query optimization

### Caching
- Redis for session and data caching
- CloudFront for static assets
- Browser caching headers

### Async Processing
- Bull queue for background jobs
- Email sending
- Image processing
- Report generation

---

## Testing Strategy

### Unit Tests
- Test individual functions and components
- Mock external dependencies
- 80%+ code coverage target

### Integration Tests
- Test API endpoints
- Test database operations
- Test third-party integrations

### End-to-End Tests
- Test complete user flows
- Cypress/Playwright
- Critical paths (checkout, payment)

### Performance Tests
- Load testing (k6, Artillery)
- 1000 concurrent users target
- API response time < 500ms

### Security Tests
- OWASP ZAP scanning
- Dependency vulnerability scanning
- Penetration testing

---

## Disaster Recovery

### Backup Strategy
- **Database**: Automated daily backups (RDS)
- **Code**: Git repository (GitHub)
- **Assets**: S3 versioning

### Recovery Plan
1. Restore database from latest backup
2. Deploy from latest stable release
3. Verify data integrity
4. Resume operations

### Rollback Strategy
- Keep previous Docker images
- Database migration rollback scripts
- Feature flags for gradual rollouts

---

## Future Enhancements

### Phase 11+
- Advanced analytics and reporting
- Customer reviews and ratings system
- Wishlist functionality
- Product recommendations (ML)
- Real-time inventory updates (WebSockets)
- Multi-vendor marketplace
- Internationalization (i18n)
- Mobile app (React Native)
- Progressive Web App (PWA)
- Social media integration
- Advanced search (Elasticsearch)

---

## Conclusion

This architecture provides a solid foundation for a scalable, secure, and performant e-commerce application. The modular design allows for easy maintenance and future enhancements while adhering to industry best practices and modern development patterns.
