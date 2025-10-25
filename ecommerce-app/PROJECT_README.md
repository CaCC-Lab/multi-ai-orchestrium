# E-Commerce Shopping Cart System

Complete e-commerce platform with product catalog, shopping cart, checkout with Stripe payment integration, and admin management panel.

## 📋 Project Documentation

This project includes comprehensive documentation for planning and development:

### Core Documentation
- **[PROJECT_SPECIFICATION.md](PROJECT_SPECIFICATION.md)** - Complete feature list, technical requirements, and success criteria
- **[ARCHITECTURE.md](ARCHITECTURE.md)** - System architecture, technology stack, and design decisions
- **[TASK_BREAKDOWN.md](TASK_BREAKDOWN.md)** - Detailed task breakdown organized by development phases
- **[PROJECT_TIMELINE.md](PROJECT_TIMELINE.md)** - 13-week development timeline with milestones
- **[DATABASE_SCHEMA.sql](DATABASE_SCHEMA.sql)** - Complete PostgreSQL database schema

### Guides
- **[USER_MANUAL.md](USER_MANUAL.md)** - End-user documentation
- **[ADMIN_GUIDE.md](ADMIN_GUIDE.md)** - Administrator documentation
- **[DEPLOYMENT.md](DEPLOYMENT.md)** - Deployment instructions

## 🚀 Quick Start

### Prerequisites
- Node.js 18+
- PostgreSQL 14+
- Redis 6+
- Stripe Account
- SendGrid Account
- AWS Account (for production)

### Environment Setup

1. **Clone and Install**
   ```bash
   git clone <repository-url>
   cd ecommerce-app
   
   # Install backend dependencies
   cd backend
   npm install
   
   # Install frontend dependencies
   cd ../frontend
   npm install
   ```

2. **Environment Variables**
   
   Backend `.env`:
   ```env
   # Server
   NODE_ENV=development
   PORT=5000
   
   # Database
   DB_HOST=localhost
   DB_PORT=5432
   DB_NAME=ecommerce_db
   DB_USER=postgres
   DB_PASSWORD=your_password
   
   # JWT
   JWT_SECRET=your_jwt_secret_key
   JWT_REFRESH_SECRET=your_refresh_secret_key
   JWT_EXPIRE=15m
   JWT_REFRESH_EXPIRE=7d
   
   # Redis
   REDIS_HOST=localhost
   REDIS_PORT=6379
   REDIS_PASSWORD=
   
   # Stripe
   STRIPE_SECRET_KEY=sk_test_...
   STRIPE_PUBLISHABLE_KEY=pk_test_...
   STRIPE_WEBHOOK_SECRET=whsec_...
   
   # SendGrid
   SENDGRID_API_KEY=SG...
   SENDGRID_FROM_EMAIL=noreply@ecommerce.com
   
   # Frontend URL
   FRONTEND_URL=http://localhost:5173
   ```
   
   Frontend `.env`:
   ```env
   VITE_API_URL=http://localhost:5000/api
   VITE_STRIPE_PUBLISHABLE_KEY=pk_test_...
   ```

3. **Database Setup**
   ```bash
   # Create database
   createdb ecommerce_db
   
   # Run migrations
   cd backend
   npm run migrate
   
   # Seed data (optional)
   npm run seed
   ```

4. **Start Development Servers**
   ```bash
   # Terminal 1: Backend
   cd backend
   npm run dev
   
   # Terminal 2: Frontend
   cd frontend
   npm run dev
   ```

5. **Access Application**
   - Frontend: http://localhost:5173
   - Backend API: http://localhost:5000
   - API Docs: http://localhost:5000/api-docs

## 📦 Project Structure

```
ecommerce-app/
├── backend/              # Node.js/Express backend
│   ├── src/
│   │   ├── config/       # Configuration files
│   │   ├── controllers/  # Route controllers
│   │   ├── models/       # Sequelize models
│   │   ├── services/     # Business logic
│   │   ├── middleware/   # Custom middleware
│   │   ├── routes/       # API routes
│   │   ├── utils/        # Utility functions
│   │   └── validators/   # Input validation
│   ├── tests/            # Backend tests
│   └── package.json
├── frontend/             # React frontend
│   ├── src/
│   │   ├── components/   # React components
│   │   ├── pages/        # Page components
│   │   ├── store/        # Redux store
│   │   ├── services/     # API services
│   │   └── utils/        # Utility functions
│   ├── public/           # Static assets
│   └── package.json
├── deploy/               # Deployment scripts
├── docs/                 # Additional documentation
└── docker-compose.yml    # Docker composition
```

## 🛠️ Development

### Available Scripts

**Backend:**
```bash
npm run dev          # Start development server with nodemon
npm run start        # Start production server
npm run test         # Run tests
npm run test:watch   # Run tests in watch mode
npm run lint         # Run ESLint
npm run migrate      # Run database migrations
npm run seed         # Seed database
```

**Frontend:**
```bash
npm run dev          # Start Vite dev server
npm run build        # Build for production
npm run preview      # Preview production build
npm run test         # Run tests
npm run lint         # Run ESLint
```

### Testing

- **Unit Tests**: Jest (backend), Vitest (frontend)
- **Integration Tests**: Supertest (backend API)
- **E2E Tests**: Playwright/Cypress
- **Coverage Goal**: 80%+

Run all tests:
```bash
# Backend
cd backend && npm test

# Frontend
cd frontend && npm test
```

## 🔒 Security

- Password hashing with bcrypt (10 rounds)
- JWT authentication with refresh tokens
- Rate limiting (100 requests/15min per IP)
- Input validation and sanitization
- SQL injection prevention (parameterized queries)
- XSS protection
- CSRF tokens
- Helmet.js security headers
- HTTPS enforced in production

## 📊 Database

- **Primary Database**: PostgreSQL 14+
- **ORM**: Sequelize
- **Migrations**: Sequelize CLI
- **Caching**: Redis

See [DATABASE_SCHEMA.sql](DATABASE_SCHEMA.sql) for complete schema.

### Key Tables
- `users` - User accounts
- `products` - Product catalog
- `orders` - Order management
- `cart_items` - Shopping cart
- `payments` - Payment tracking
- `addresses` - Shipping/billing addresses

## 🔄 API Documentation

API documentation is available via Swagger/OpenAPI at `/api-docs` when running the backend.

### Main Endpoints
- `/api/auth/*` - Authentication
- `/api/products/*` - Product catalog
- `/api/cart/*` - Shopping cart
- `/api/orders/*` - Orders
- `/api/payments/*` - Payments
- `/api/admin/*` - Admin operations

## 🎨 Frontend

- **Framework**: React 18+
- **State Management**: Redux Toolkit
- **Routing**: React Router v6
- **UI Framework**: Tailwind CSS / Material-UI
- **Forms**: Formik + Yup
- **HTTP Client**: Axios

## 💳 Payment Integration

Stripe integration for payment processing:
- Payment Intents API
- Stripe Elements for card input
- Webhook handling for payment events
- PCI DSS compliant (no card storage)

## 📧 Email Notifications

SendGrid integration for transactional emails:
- Welcome emails
- Order confirmations
- Shipping notifications
- Password reset emails

## 🚀 Deployment

### Production Environment
- **Hosting**: AWS EC2
- **Database**: AWS RDS (PostgreSQL)
- **Cache**: AWS ElastiCache (Redis)
- **CDN**: CloudFront
- **CI/CD**: GitHub Actions

See [DEPLOYMENT.md](DEPLOYMENT.md) for detailed deployment instructions.

### Docker Deployment

```bash
# Build and run with Docker Compose
docker-compose up -d

# Scale backend
docker-compose up -d --scale backend=3
```

## 📈 Performance

Target Performance Metrics:
- Page Load: < 2 seconds (90th percentile)
- API Response: < 500ms (95th percentile)
- Concurrent Users: 1000+

Optimization Strategies:
- Redis caching
- Database query optimization
- CDN for static assets
- Code splitting
- Image optimization
- Gzip compression

## 🧪 Quality Assurance

- ESLint for code quality
- Prettier for code formatting
- Unit tests (80%+ coverage)
- Integration tests
- E2E tests for critical flows
- Load testing
- Security audits

## 📝 Development Workflow

1. **Feature Branch**: Create branch from `main`
2. **Development**: Implement feature with tests
3. **Testing**: Run all tests locally
4. **Code Review**: Create PR for review
5. **CI Pipeline**: Automated tests and build
6. **Merge**: Merge to `main` after approval
7. **Deploy**: Automatic deployment to staging
8. **Production**: Manual approval for production

## 🗓️ Project Timeline

**Total Duration**: 13 weeks

- **Phase 1 (Weeks 1-2)**: Foundation & Setup
- **Phase 2 (Weeks 3-5)**: Core Features
- **Phase 3 (Weeks 6-8)**: E-commerce Features
- **Phase 4 (Weeks 9-10)**: Admin Panel
- **Phase 5 (Weeks 11-12)**: Polish & Testing
- **Phase 6 (Week 13)**: Deployment

See [PROJECT_TIMELINE.md](PROJECT_TIMELINE.md) for detailed schedule.

## 🎯 Key Features

### Customer Features
- ✅ User registration and authentication
- ✅ Product browsing with search and filters
- ✅ Shopping cart management
- ✅ Secure checkout with Stripe
- ✅ Order history and tracking
- ✅ User profile and address management
- ✅ Multi-currency support
- ✅ Responsive design (mobile/tablet/desktop)

### Admin Features
- ✅ Product management (CRUD)
- ✅ Order management
- ✅ Inventory tracking
- ✅ User management
- ✅ Sales reports
- ✅ Dashboard with analytics

## 🤝 Contributing

1. Fork the repository
2. Create feature branch (`git checkout -b feature/amazing-feature`)
3. Commit changes (`git commit -m 'Add amazing feature'`)
4. Push to branch (`git push origin feature/amazing-feature`)
5. Open Pull Request

## 📄 License

This project is licensed under the MIT License - see LICENSE file for details.

## 📞 Support

For questions or issues:
- Create an issue on GitHub
- Contact: support@ecommerce.com
- Documentation: See docs/ folder

## 🔗 Related Documentation

- [Project Specification](PROJECT_SPECIFICATION.md)
- [Architecture Overview](ARCHITECTURE.md)
- [Task Breakdown](TASK_BREAKDOWN.md)
- [Timeline & Milestones](PROJECT_TIMELINE.md)
- [Database Schema](DATABASE_SCHEMA.sql)
- [User Manual](USER_MANUAL.md)
- [Admin Guide](ADMIN_GUIDE.md)
- [Deployment Guide](DEPLOYMENT.md)

---

**Status**: 🚧 In Planning Phase  
**Version**: 0.1.0  
**Last Updated**: 2025
