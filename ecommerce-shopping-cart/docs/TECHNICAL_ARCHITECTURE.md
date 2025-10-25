# Technical Architecture Document

## System Overview

Full-stack e-commerce platform built with modern web technologies, designed for scalability, security, and performance.

**Architecture Style:** Monolithic with microservice-ready design  
**Deployment Model:** Cloud-native (AWS)  
**Data Strategy:** Relational database with caching layer

---

## Architecture Diagram

The system follows a layered architecture pattern with clear separation of concerns:

```
┌─────────────────────────────────────────────────────────────┐
│                      Client Layer                            │
│              (Web Browsers, Mobile Devices)                  │
└─────────────────────────────────────────────────────────────┘
                            ↓ HTTPS
┌─────────────────────────────────────────────────────────────┐
│                   CDN & Load Balancing                       │
│           CloudFront CDN → Application Load Balancer         │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│                   Presentation Layer                         │
│   Nginx Reverse Proxy → React SPA (Redux) / Express API     │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│                    Business Logic Layer                      │
│  Auth | Product | Cart | Order | Payment | Email Services   │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│                      Data Layer                              │
│         PostgreSQL (RDS) | Redis Cache | S3 Storage          │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│                   External Services                          │
│              Stripe Payment API | SendGrid Email             │
└─────────────────────────────────────────────────────────────┘
```

See the full architecture diagram above for detailed component relationships.

---

## Technology Stack

### Frontend
- **Framework:** React 18+
- **State Management:** Redux Toolkit
- **Routing:** React Router v6
- **HTTP Client:** Axios
- **UI Framework:** Material-UI or Tailwind CSS
- **Form Validation:** Formik + Yup
- **Date Handling:** date-fns
- **Build Tool:** Vite or Create React App

### Backend
- **Runtime:** Node.js 18 LTS
- **Framework:** Express.js
- **ORM:** Sequelize
- **Authentication:** JWT (jsonwebtoken)
- **Validation:** Joi or express-validator
- **Password Hashing:** bcrypt
- **Security:** Helmet.js, express-rate-limit, cors
- **Logging:** Winston, Morgan

### Database
- **Primary Database:** PostgreSQL 14+
- **Caching:** Redis 7+
- **ORM:** Sequelize with migrations

### Infrastructure
- **Hosting:** AWS EC2
- **Database:** AWS RDS (PostgreSQL)
- **Cache:** AWS ElastiCache (Redis)
- **Storage:** AWS S3
- **CDN:** AWS CloudFront
- **Load Balancer:** AWS Application Load Balancer
- **Container Registry:** AWS ECR
- **Containerization:** Docker, Docker Compose

### External Services
- **Payment:** Stripe API
- **Email:** SendGrid API
- **Domain/SSL:** AWS Route 53, ACM

### DevOps
- **CI/CD:** GitHub Actions
- **Version Control:** Git, GitHub
- **Monitoring:** Sentry, AWS CloudWatch
- **Logging:** CloudWatch Logs
- **Container Orchestration:** Docker Compose (PM2 for process management)

---

## Component Architecture

### 1. Frontend Architecture

#### Component Structure
```
src/
├── components/
│   ├── common/           # Reusable UI components
│   │   ├── Button/
│   │   ├── Input/
│   │   └── Modal/
│   ├── layout/           # Layout components
│   │   ├── Header/
│   │   ├── Footer/
│   │   └── Sidebar/
│   └── features/         # Feature-specific components
│       ├── ProductCard/
│       ├── CartItem/
│       └── OrderSummary/
├── pages/                # Page-level components
│   ├── HomePage/
│   ├── ProductPage/
│   ├── CartPage/
│   └── CheckoutPage/
├── store/                # Redux store
│   ├── slices/
│   │   ├── authSlice.js
│   │   ├── cartSlice.js
│   │   └── productsSlice.js
│   └── store.js
├── services/             # API services
│   ├── api.js            # Axios configuration
│   ├── authService.js
│   ├── productService.js
│   └── orderService.js
├── hooks/                # Custom React hooks
│   ├── useAuth.js
│   ├── useCart.js
│   └── useDebounce.js
├── utils/                # Helper functions
│   ├── formatters.js
│   └── validators.js
└── App.js                # Root component
```

#### State Management Strategy
- **Redux Toolkit:** Global state (auth, cart, user)
- **React Query:** Server state caching (products, orders)
- **Local State:** Component-specific state (form inputs, UI toggles)

#### Routing Strategy
```javascript
<Routes>
  <Route path="/" element={<HomePage />} />
  <Route path="/products" element={<ProductListPage />} />
  <Route path="/products/:slug" element={<ProductDetailPage />} />
  <Route path="/cart" element={<CartPage />} />
  
  {/* Protected Routes */}
  <Route element={<PrivateRoute />}>
    <Route path="/checkout" element={<CheckoutPage />} />
    <Route path="/orders" element={<OrderHistoryPage />} />
    <Route path="/profile" element={<ProfilePage />} />
  </Route>
  
  {/* Admin Routes */}
  <Route element={<AdminRoute />}>
    <Route path="/admin" element={<AdminDashboard />} />
    <Route path="/admin/products" element={<AdminProducts />} />
    <Route path="/admin/orders" element={<AdminOrders />} />
  </Route>
</Routes>
```

---

### 2. Backend Architecture

#### Project Structure (MVC Pattern)
```
backend/
├── src/
│   ├── config/           # Configuration files
│   │   ├── database.js
│   │   ├── redis.js
│   │   └── stripe.js
│   ├── controllers/      # Request handlers
│   │   ├── authController.js
│   │   ├── productController.js
│   │   ├── cartController.js
│   │   └── orderController.js
│   ├── models/           # Sequelize models
│   │   ├── User.js
│   │   ├── Product.js
│   │   ├── Order.js
│   │   └── index.js
│   ├── routes/           # API routes
│   │   ├── auth.routes.js
│   │   ├── product.routes.js
│   │   └── index.js
│   ├── middleware/       # Express middleware
│   │   ├── auth.middleware.js
│   │   ├── validation.middleware.js
│   │   ├── errorHandler.middleware.js
│   │   └── rateLimiter.middleware.js
│   ├── services/         # Business logic
│   │   ├── authService.js
│   │   ├── productService.js
│   │   ├── cartService.js
│   │   ├── orderService.js
│   │   ├── paymentService.js
│   │   └── emailService.js
│   ├── utils/            # Helper functions
│   │   ├── jwt.util.js
│   │   ├── email.util.js
│   │   └── logger.util.js
│   ├── validators/       # Input validation schemas
│   │   ├── auth.validator.js
│   │   └── product.validator.js
│   ├── migrations/       # Database migrations
│   └── seeders/          # Database seeders
├── tests/                # Test files
└── server.js             # Entry point
```

#### Request Flow
```
Request → Middleware Chain → Controller → Service → Model → Database
                ↓                                      ↓
            Response ← Controller ← Service ← Model ← Result
```

#### Middleware Stack (Order Matters)
1. **helmet** - Security headers
2. **cors** - CORS configuration
3. **express.json()** - Body parser
4. **morgan** - HTTP logging
5. **express-rate-limit** - Rate limiting
6. **Custom auth middleware** - JWT verification
7. **Route handlers**
8. **Error handler** - Global error handling

---

### 3. Database Architecture

#### Entity Relationships
- **Users** (1:N) → Orders, CartItems, Addresses, Reviews
- **Products** (1:1) → Inventory
- **Products** (1:N) → ProductImages, Reviews, OrderItems
- **Orders** (1:N) → OrderItems, Payments
- **Categories** (self-referential) → Parent/Child hierarchy

#### Indexing Strategy
- Primary keys (default)
- Foreign keys (for joins)
- Email (users) - unique, fast lookup
- SKU, Slug (products) - unique, fast lookup
- Order number - unique, tracking
- Created_at timestamps - sorting, filtering
- Full-text search on product names/descriptions

#### Data Integrity
- Foreign key constraints with appropriate ON DELETE actions
- Check constraints for prices, quantities (non-negative)
- Unique constraints on emails, SKUs, order numbers
- Triggers for auto-updating timestamps
- Triggers for inventory reservation

---

### 4. Caching Strategy

#### Redis Cache Layers

**Layer 1: API Response Caching**
- Product listings (TTL: 5 minutes)
- Product details (TTL: 10 minutes)
- Category tree (TTL: 1 hour)

**Layer 2: Session Caching**
- User sessions (TTL: 30 minutes, sliding expiration)
- Shopping cart (TTL: 7 days)

**Layer 3: Rate Limiting**
- Rate limit counters per IP/user
- Token blacklist for logged-out JWTs

#### Cache Invalidation
- Product update → Invalidate product cache, listing cache
- Order placement → Clear cart cache
- Admin actions → Targeted cache invalidation

---

### 5. Security Architecture

#### Authentication Flow
```
1. User submits credentials → POST /auth/login
2. Backend validates credentials (bcrypt)
3. Generate JWT tokens:
   - Access Token (short-lived: 15-60 min)
   - Refresh Token (long-lived: 7-30 days)
4. Store refresh token in httpOnly cookie or database
5. Return tokens to client
6. Client includes access token in Authorization header
7. Backend verifies JWT on protected routes
8. Token expires → Client requests new token with refresh token
```

#### Authorization Levels
- **Anonymous:** Browse products, view categories
- **Authenticated:** Add to cart, checkout, view orders
- **Admin:** Manage products, orders, users

#### Security Layers
1. **Network:** HTTPS, TLS 1.2+
2. **Application:** Helmet.js headers, CORS, CSRF tokens
3. **Authentication:** JWT, bcrypt, rate limiting
4. **Authorization:** Role-based access control
5. **Input Validation:** Joi schemas, SQL injection prevention
6. **Output Encoding:** XSS prevention
7. **Data:** Encryption at rest (RDS), environment secrets

---

## Data Flow Examples

### 1. User Registration Flow
```
Client → POST /api/v1/auth/register
         ↓
      Validation middleware
         ↓
      authController.register()
         ↓
      authService.register()
         ↓
      - Hash password (bcrypt)
      - Create user in database
      - Generate JWT tokens
         ↓
      Return {user, tokens}
         ↓
      Client stores tokens
```

### 2. Add to Cart Flow
```
Client → POST /api/v1/cart/items {productId, quantity}
         ↓
      Auth middleware (verify JWT)
         ↓
      cartController.addItem()
         ↓
      cartService.addItem()
         ↓
      - Check product exists & in stock
      - Check if item already in cart
         - Yes: Update quantity
         - No: Create cart item
      - Update Redis cache
         ↓
      Return updated cart
         ↓
      Client updates Redux store
```

### 3. Checkout Flow
```
Client → POST /api/v1/orders {addressId, paymentIntentId}
         ↓
      Auth middleware
         ↓
      orderController.create()
         ↓
      orderService.create()
         ↓
      Database Transaction:
      1. Validate cart items
      2. Verify inventory availability
      3. Reserve inventory
      4. Create order record
      5. Create order items
      6. Clear cart
      7. Process payment (Stripe)
      8. Send confirmation email
         ↓
      Return order details
         ↓
      Client redirects to confirmation page
```

---

## Scalability Considerations

### Horizontal Scaling
- **Stateless Backend:** No server-side sessions (JWT-based)
- **Load Balancer:** Distribute traffic across multiple instances
- **Database Connection Pooling:** Reuse connections efficiently

### Vertical Scaling
- **EC2 Instance Size:** Start with t3.medium, scale to c5.xlarge
- **RDS Instance Size:** Start with db.t3.medium, scale to db.r5.large

### Database Optimization
- **Read Replicas:** Offload read queries
- **Connection Pooling:** Sequelize pool configuration
- **Query Optimization:** N+1 query prevention, eager loading
- **Partitioning:** Partition large tables (orders) by date

### Caching Optimization
- **Redis Cluster:** Scale Redis horizontally
- **CDN:** Serve static assets from CloudFront
- **Browser Caching:** Set appropriate cache headers

---

## Monitoring & Observability

### Metrics to Track
- **Application:** Request rate, response time, error rate
- **Infrastructure:** CPU, memory, disk I/O, network
- **Database:** Query performance, connection count, replication lag
- **Business:** Orders/hour, revenue, cart abandonment rate

### Logging Strategy
- **Structured Logging:** JSON format with Winston
- **Log Levels:** error, warn, info, debug
- **Log Aggregation:** CloudWatch Logs
- **Sensitive Data:** Never log passwords, tokens, payment info

### Alerting
- **Critical Alerts:** 5xx errors, payment failures, database down
- **Warning Alerts:** High response times, low disk space
- **Info Alerts:** Deployments, configuration changes

---

## Disaster Recovery

### Backup Strategy
- **Database:** Automated daily backups, 7-day retention
- **Manual Snapshots:** Before major deployments
- **S3 Assets:** Versioning enabled, lifecycle policies

### Recovery Procedures
- **RTO (Recovery Time Objective):** < 1 hour
- **RPO (Recovery Point Objective):** < 1 hour (last backup)
- **Rollback:** Blue-green deployment for quick rollback

---

## Future Enhancements

### Phase 1 (Next 6 months)
- Product recommendations (ML-based)
- Advanced search (Elasticsearch)
- Wishlist functionality
- Social login (OAuth)

### Phase 2 (6-12 months)
- Mobile app (React Native)
- Multi-warehouse inventory
- Advanced analytics dashboard
- A/B testing framework

### Phase 3 (12+ months)
- Microservices architecture
- Event-driven architecture (message queues)
- GraphQL API
- International shipping

---

**Document Version:** 1.0  
**Last Updated:** October 24, 2025  
**Architecture Review Date:** January 24, 2026
