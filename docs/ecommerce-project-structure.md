# E-Commerce Shopping Cart System - Project Structure

## Directory Structure

```
ecommerce-cart/
├── backend/
│   ├── src/
│   │   ├── config/           # Configuration files
│   │   ├── controllers/      # Route controllers
│   │   ├── middleware/       # Express middleware
│   │   ├── models/           # Sequelize models
│   │   ├── routes/           # API routes
│   │   ├── services/         # Business logic
│   │   ├── utils/            # Utility functions
│   │   └── validators/       # Input validation
│   ├── migrations/           # Database migrations
│   ├── seeders/              # Database seeders
│   ├── tests/                # Test files
│   │   ├── unit/
│   │   └── integration/
│   ├── .env.example
│   ├── package.json
│   └── server.js
│
├── frontend/
│   ├── public/
│   ├── src/
│   │   ├── components/       # React components
│   │   │   ├── auth/
│   │   │   ├── cart/
│   │   │   ├── products/
│   │   │   ├── checkout/
│   │   │   ├── admin/
│   │   │   └── common/
│   │   ├── redux/            # Redux store
│   │   │   ├── actions/
│   │   │   ├── reducers/
│   │   │   └── store.js
│   │   ├── services/         # API services
│   │   ├── hooks/            # Custom hooks
│   │   ├── utils/            # Utility functions
│   │   ├── styles/           # CSS/SCSS files
│   │   ├── App.js
│   │   └── index.js
│   ├── tests/
│   ├── package.json
│   └── .env.example
│
├── docs/
│   ├── api/                  # API documentation
│   ├── architecture/         # Architecture diagrams
│   ├── user-manual/          # User documentation
│   └── admin-guide/          # Admin documentation
│
├── scripts/
│   ├── deploy/               # Deployment scripts
│   └── setup/                # Setup scripts
│
├── .github/
│   └── workflows/            # GitHub Actions
│
├── docker-compose.yml
├── .gitignore
└── README.md
```

## Core Modules

### Backend Modules
- **Authentication**: JWT-based user authentication
- **Products**: Product catalog management
- **Cart**: Shopping cart operations
- **Orders**: Order processing and tracking
- **Payments**: Stripe payment integration
- **Email**: SendGrid email notifications
- **Admin**: Admin panel operations
- **Inventory**: Stock management

### Frontend Modules
- **Auth Pages**: Login, Register, Logout
- **Product Pages**: Catalog, Search, Filters, Details
- **Cart Pages**: Cart view, quantity management
- **Checkout Pages**: Shipping, Payment, Confirmation
- **User Pages**: Profile, Order History
- **Admin Pages**: Product management, Order management, Inventory
