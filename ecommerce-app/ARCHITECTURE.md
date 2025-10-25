# E-Commerce System Architecture

## System Overview

The e-commerce platform follows a three-tier architecture with a React frontend, Node.js/Express backend, and PostgreSQL database. The system is designed for scalability, security, and maintainability.

---

## High-Level Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                         Client Layer                         │
│  ┌─────────────┐  ┌──────────────┐  ┌─────────────────┐    │
│  │   Browser   │  │    Mobile    │  │     Tablet      │    │
│  │  (Desktop)  │  │   (Safari/   │  │   (Responsive)  │    │
│  │             │  │   Chrome)    │  │                 │    │
│  └─────────────┘  └──────────────┘  └─────────────────┘    │
└─────────────────────────────────────────────────────────────┘
                            │ HTTPS
                            ↓
┌─────────────────────────────────────────────────────────────┐
│                      CDN (CloudFront)                        │
│                    Static Assets Delivery                    │
└─────────────────────────────────────────────────────────────┘
                            │
                            ↓
┌─────────────────────────────────────────────────────────────┐
│                    Load Balancer (ALB)                       │
└─────────────────────────────────────────────────────────────┘
                            │
         ┌──────────────────┴──────────────────┐
         ↓                                     ↓
┌────────────────────┐              ┌────────────────────┐
│   Frontend (React) │              │  Backend (Express) │
│   - Redux Store    │              │  - REST API        │
│   - React Router   │  ← API →     │  - Business Logic  │
│   - UI Components  │              │  - Authentication  │
└────────────────────┘              └────────────────────┘
                                              │
                    ┌─────────────────────────┼──────────────────┐
                    ↓                         ↓                  ↓
         ┌──────────────────┐    ┌───────────────────┐  ┌──────────────┐
         │   PostgreSQL     │    │      Redis        │  │  External    │
         │   (Primary DB)   │    │   (Cache/Session) │  │   Services   │
         │                  │    │                   │  │  - Stripe    │
         └──────────────────┘    └───────────────────┘  │  - SendGrid  │
                                                         └──────────────┘
```

---

## Frontend Architecture

### Technology Stack
- **Framework**: React 18+
- **State Management**: Redux Toolkit
- **Routing**: React Router v6
- **Styling**: Tailwind CSS / Material-UI
- **Forms**: Formik + Yup
- **HTTP Client**: Axios
- **Build Tool**: Vite

### Folder Structure
```
frontend/
├── public/
│   ├── favicon.ico
│   └── index.html
├── src/
│   ├── assets/          # Images, fonts, static files
│   ├── components/      # Reusable UI components
│   │   ├── common/      # Buttons, inputs, modals
│   │   ├── layout/      # Header, footer, sidebar
│   │   └── product/     # Product card, list, detail
│   ├── pages/           # Page components
│   │   ├── Home.jsx
│   │   ├── Products.jsx
│   │   ├── Cart.jsx
│   │   ├── Checkout.jsx
│   │   └── admin/       # Admin pages
│   ├── store/           # Redux store
│   │   ├── slices/      # Redux slices
│   │   │   ├── authSlice.js
│   │   │   ├── cartSlice.js
│   │   │   ├── productSlice.js
│   │   │   └── orderSlice.js
│   │   └── store.js     # Store configuration
│   ├── services/        # API calls
│   │   ├── api.js       # Axios configuration
│   │   ├── authService.js
│   │   ├── productService.js
│   │   └── orderService.js
│   ├── hooks/           # Custom React hooks
│   ├── utils/           # Utility functions
│   ├── constants/       # Constants and configs
│   ├── routes/          # Route definitions
│   ├── App.jsx
│   └── main.jsx
├── .env.example
├── package.json
└── vite.config.js
```

### Component Architecture
- **Atomic Design Pattern**
  - Atoms: Basic UI elements (Button, Input, Label)
  - Molecules: Simple component groups (SearchBar, ProductCard)
  - Organisms: Complex components (Header, ProductList, CheckoutForm)
  - Templates: Page layouts
  - Pages: Complete pages

### State Management Strategy
- **Redux Store Structure**:
  ```javascript
  {
    auth: { user, token, isAuthenticated, loading },
    products: { items, currentProduct, filters, loading },
    cart: { items, total, itemCount },
    orders: { list, currentOrder, history },
    ui: { notifications, modals, loading }
  }
  ```

### Routing Strategy
```javascript
/ → Home
/products → Product List
/products/:id → Product Detail
/cart → Shopping Cart
/checkout → Checkout Flow
/orders → Order History
/orders/:id → Order Detail
/profile → User Profile
/admin/* → Admin Panel (protected)
```

---

## Backend Architecture

### Technology Stack
- **Runtime**: Node.js 18+
- **Framework**: Express.js
- **ORM**: Sequelize
- **Authentication**: JWT (jsonwebtoken)
- **Validation**: express-validator
- **Security**: Helmet, CORS, bcrypt
- **Email**: SendGrid SDK
- **Payment**: Stripe SDK

### Folder Structure
```
backend/
├── src/
│   ├── config/          # Configuration files
│   │   ├── database.js
│   │   ├── redis.js
│   │   ├── stripe.js
│   │   └── sendgrid.js
│   ├── models/          # Sequelize models
│   │   ├── User.js
│   │   ├── Product.js
│   │   ├── Order.js
│   │   ├── Cart.js
│   │   └── index.js
│   ├── controllers/     # Request handlers
│   │   ├── authController.js
│   │   ├── productController.js
│   │   ├── cartController.js
│   │   ├── orderController.js
│   │   └── paymentController.js
│   ├── services/        # Business logic
│   │   ├── authService.js
│   │   ├── productService.js
│   │   ├── cartService.js
│   │   ├── orderService.js
│   │   ├── paymentService.js
│   │   └── emailService.js
│   ├── middleware/      # Custom middleware
│   │   ├── auth.js      # JWT verification
│   │   ├── rbac.js      # Role-based access
│   │   ├── validate.js  # Input validation
│   │   ├── errorHandler.js
│   │   └── rateLimit.js
│   ├── routes/          # API routes
│   │   ├── auth.js
│   │   ├── products.js
│   │   ├── cart.js
│   │   ├── orders.js
│   │   ├── payments.js
│   │   └── admin.js
│   ├── utils/           # Utility functions
│   │   ├── jwt.js
│   │   ├── logger.js
│   │   └── cache.js
│   ├── validators/      # Input validation schemas
│   ├── migrations/      # Database migrations
│   ├── seeders/         # Seed data
│   └── app.js           # Express app setup
├── tests/               # Test files
├── .env.example
├── package.json
└── server.js            # Entry point
```

### Layered Architecture

```
Request → Routes → Middleware → Controllers → Services → Models → Database
                                                    ↓
                                            External Services
```

1. **Routes Layer**: Define endpoints and map to controllers
2. **Middleware Layer**: Authentication, validation, logging
3. **Controller Layer**: Handle HTTP requests/responses
4. **Service Layer**: Business logic and orchestration
5. **Model Layer**: Database interaction via Sequelize
6. **External Services**: Third-party integrations (Stripe, SendGrid)

### API Design

**RESTful Endpoints**:
```
Authentication
POST   /api/auth/register
POST   /api/auth/login
POST   /api/auth/logout
POST   /api/auth/refresh
POST   /api/auth/forgot-password
POST   /api/auth/reset-password

Products
GET    /api/products?page=1&limit=20&search=laptop&category=electronics
GET    /api/products/:id
POST   /api/products (admin)
PUT    /api/products/:id (admin)
DELETE /api/products/:id (admin)

Cart
GET    /api/cart
POST   /api/cart/items
PUT    /api/cart/items/:id
DELETE /api/cart/items/:id
DELETE /api/cart

Orders
POST   /api/orders
GET    /api/orders
GET    /api/orders/:id
PUT    /api/orders/:id/cancel

Payments
POST   /api/payments/create-intent
POST   /api/payments/webhook

Admin
GET    /api/admin/orders
PUT    /api/admin/orders/:id/status
GET    /api/admin/users
PUT    /api/admin/users/:id/status
```

---

## Database Architecture

### PostgreSQL Schema Design

#### Core Tables

**users**
```sql
id (PK, UUID)
email (UNIQUE, NOT NULL)
password_hash (NOT NULL)
first_name
last_name
role (ENUM: user, admin)
is_active (BOOLEAN)
created_at
updated_at
```

**products**
```sql
id (PK, UUID)
name (NOT NULL)
description (TEXT)
price (DECIMAL)
category_id (FK)
brand
sku (UNIQUE)
stock_quantity (INTEGER)
image_url
is_active (BOOLEAN)
created_at
updated_at
```

**categories**
```sql
id (PK, UUID)
name (NOT NULL)
slug (UNIQUE)
parent_id (FK, NULLABLE)
created_at
```

**carts**
```sql
id (PK, UUID)
user_id (FK, UNIQUE)
created_at
updated_at
```

**cart_items**
```sql
id (PK, UUID)
cart_id (FK)
product_id (FK)
quantity (INTEGER)
price_at_add (DECIMAL)
created_at
updated_at
```

**orders**
```sql
id (PK, UUID)
user_id (FK)
order_number (UNIQUE)
status (ENUM: pending, paid, processing, shipped, delivered, cancelled)
subtotal (DECIMAL)
tax (DECIMAL)
shipping_cost (DECIMAL)
total (DECIMAL)
currency (VARCHAR)
shipping_address_id (FK)
payment_id (FK)
created_at
updated_at
```

**order_items**
```sql
id (PK, UUID)
order_id (FK)
product_id (FK)
quantity (INTEGER)
price (DECIMAL)
created_at
```

**addresses**
```sql
id (PK, UUID)
user_id (FK)
address_line1 (NOT NULL)
address_line2
city (NOT NULL)
state
postal_code (NOT NULL)
country (NOT NULL)
is_default (BOOLEAN)
created_at
updated_at
```

**payments**
```sql
id (PK, UUID)
order_id (FK, UNIQUE)
stripe_payment_intent_id (UNIQUE)
amount (DECIMAL)
currency
status (ENUM: pending, succeeded, failed)
payment_method
created_at
updated_at
```

### Relationships
- User → Orders (One-to-Many)
- User → Addresses (One-to-Many)
- User → Cart (One-to-One)
- Order → OrderItems (One-to-Many)
- Order → Payment (One-to-One)
- Cart → CartItems (One-to-Many)
- Product → CartItems (One-to-Many)
- Product → OrderItems (One-to-Many)
- Category → Products (One-to-Many)

### Indexes
```sql
CREATE INDEX idx_products_category ON products(category_id);
CREATE INDEX idx_products_sku ON products(sku);
CREATE INDEX idx_orders_user ON orders(user_id);
CREATE INDEX idx_orders_status ON orders(status);
CREATE INDEX idx_order_items_order ON order_items(order_id);
CREATE INDEX idx_cart_items_cart ON cart_items(cart_id);
CREATE INDEX idx_users_email ON users(email);
```

---

## Caching Strategy

### Redis Implementation

**Cache Keys Pattern**:
```
products:list:{page}:{limit}:{filters}
product:{id}
user:{id}:cart
user:{id}:session
category:list
```

**Caching Rules**:
- **Product List**: Cache for 5 minutes
- **Product Detail**: Cache for 10 minutes
- **User Cart**: Cache for 15 minutes
- **User Session**: Cache until expiration
- **Categories**: Cache for 1 hour

**Cache Invalidation**:
- Product updated → Invalidate `product:{id}` and `products:list:*`
- Cart updated → Invalidate `user:{id}:cart`
- Order placed → Invalidate cart cache

---

## Security Architecture

### Authentication Flow

```
1. User Login → Backend validates credentials
2. Backend generates JWT (access token + refresh token)
3. Access token (15 min expiry) stored in memory
4. Refresh token (7 days) stored in httpOnly cookie
5. Client includes access token in Authorization header
6. On expiry, client uses refresh token to get new access token
```

### Authorization (RBAC)

**Roles**:
- `user`: Regular customer
- `admin`: Administrator

**Permissions**:
```javascript
{
  user: ['read:products', 'write:cart', 'write:orders', 'read:orders:own'],
  admin: ['*'] // All permissions
}
```

### Security Measures

1. **Input Validation**: express-validator on all inputs
2. **SQL Injection**: Parameterized queries via Sequelize
3. **XSS Protection**: Sanitize inputs, Content Security Policy
4. **CSRF**: CSRF tokens on state-changing operations
5. **Rate Limiting**: 100 requests/15 min per IP
6. **Password Security**: bcrypt with 10 rounds
7. **HTTPS**: Enforced in production
8. **Helmet**: Security headers
9. **Secrets**: Environment variables, AWS Secrets Manager

---

## Payment Integration

### Stripe Flow

```
1. User initiates checkout
2. Frontend requests payment intent from backend
3. Backend creates Stripe PaymentIntent
4. Backend returns client_secret to frontend
5. Frontend shows Stripe Elements (card input)
6. User enters card details
7. Frontend confirms payment with Stripe
8. Stripe processes payment
9. Stripe webhook notifies backend of result
10. Backend updates order status
11. Backend sends confirmation email
```

### Webhook Handling
- Endpoint: `/api/payments/webhook`
- Verify webhook signature
- Handle events: `payment_intent.succeeded`, `payment_intent.failed`
- Idempotent processing (check if already processed)

---

## Email System

### SendGrid Integration

**Email Types**:
1. **Welcome Email**: On user registration
2. **Order Confirmation**: On successful order
3. **Shipping Notification**: When order ships
4. **Password Reset**: On password reset request

**Template Structure**:
- HTML templates with dynamic data
- Transactional email API
- Error logging for failed emails

---

## Deployment Architecture

### AWS Infrastructure

```
┌────────────────────────────────────────────────────────────┐
│                     Route 53 (DNS)                         │
└────────────────────────────────────────────────────────────┘
                            │
                            ↓
┌────────────────────────────────────────────────────────────┐
│               CloudFront (CDN + SSL/TLS)                   │
└────────────────────────────────────────────────────────────┘
                            │
                ┌───────────┴───────────┐
                ↓                       ↓
┌───────────────────────┐   ┌───────────────────────┐
│   S3 (Frontend Build) │   │   ALB (Load Balancer) │
└───────────────────────┘   └───────────────────────┘
                                        │
                        ┌───────────────┴───────────────┐
                        ↓                               ↓
             ┌──────────────────┐          ┌──────────────────┐
             │   EC2 (Backend)  │          │   EC2 (Backend)  │
             │   Auto-scaling   │          │   Auto-scaling   │
             └──────────────────┘          └──────────────────┘
                        │
        ┌───────────────┼───────────────┐
        ↓               ↓               ↓
┌──────────────┐ ┌──────────────┐ ┌──────────────┐
│  RDS (Primary│ │ElastiCache   │ │ CloudWatch   │
│  PostgreSQL) │ │    (Redis)   │ │ (Monitoring) │
└──────────────┘ └──────────────┘ └──────────────┘
```

### CI/CD Pipeline (GitHub Actions)

```
1. Code push to GitHub
    ↓
2. GitHub Actions triggered
    ↓
3. Run linting (ESLint)
    ↓
4. Run tests (Jest, Mocha)
    ↓
5. Build Docker images
    ↓
6. Push to ECR (Elastic Container Registry)
    ↓
7. Deploy to staging (auto)
    ↓
8. Run integration tests
    ↓
9. Manual approval for production
    ↓
10. Deploy to production
    ↓
11. Smoke tests
    ↓
12. Rollback on failure
```

---

## Monitoring & Logging

### CloudWatch Metrics
- API response times
- Error rates
- Database connection pool
- Cache hit ratio
- Active users

### Application Logging
- Winston logger
- Log levels: error, warn, info, debug
- Centralized logging to CloudWatch Logs

### Alerts
- API error rate > 5%
- Response time > 1s
- Database CPU > 80%
- Low disk space

---

## Scalability Considerations

### Horizontal Scaling
- Stateless backend (JWT, no server sessions)
- Auto-scaling EC2 based on CPU/memory
- Load balancer distributes traffic

### Database Scaling
- Read replicas for read-heavy operations
- Connection pooling (50 connections)
- Query optimization and indexing

### Caching
- Redis for frequently accessed data
- CDN for static assets
- Browser caching headers

### Performance Targets
- 1000 concurrent users
- < 500ms API response (p95)
- < 2s page load (p90)

---

## Disaster Recovery

### Backup Strategy
- RDS automated backups (daily)
- Point-in-time recovery (7 days)
- Manual snapshots before major changes

### Failover
- Multi-AZ RDS deployment
- Health checks on EC2 instances
- Auto-recovery on instance failure

---

## Technology Decisions

| Requirement | Technology | Rationale |
|------------|------------|-----------|
| Backend | Node.js + Express | Fast, JavaScript full-stack, large ecosystem |
| Database | PostgreSQL | ACID compliance, complex queries, reliable |
| ORM | Sequelize | Mature, TypeScript support, migrations |
| Frontend | React | Component-based, large ecosystem, hiring ease |
| State | Redux Toolkit | Predictable state, DevTools, middleware |
| Cache | Redis | Fast, versatile, session storage |
| Payment | Stripe | PCI compliant, easy integration, reliable |
| Email | SendGrid | Transactional email API, templates, analytics |
| Hosting | AWS | Scalable, reliable, comprehensive services |

---

## Future Enhancements

- GraphQL API for flexible queries
- Real-time features (WebSocket for order updates)
- Elasticsearch for advanced search
- Recommendation engine
- Progressive Web App (PWA)
- Microservices architecture (as scale increases)
- Kubernetes for container orchestration
