# E-Commerce Shopping Cart System - Testing Strategy

## Testing Overview

**Coverage Target**: 80% minimum
**Testing Pyramid**: 70% Unit, 20% Integration, 10% E2E

---

## 1. Unit Testing

### Backend Unit Tests (Jest + Supertest)

**Test Structure:**
```
tests/
├── unit/
│   ├── controllers/
│   ├── services/
│   ├── models/
│   ├── middleware/
│   └── utils/
```

**Example Test - User Service:**
```javascript
// tests/unit/services/userService.test.js
const userService = require('../../../src/services/userService');
const { User } = require('../../../src/models');
const bcrypt = require('bcrypt');
const jwt = require('jsonwebtoken');

jest.mock('../../../src/models');
jest.mock('bcrypt');
jest.mock('jsonwebtoken');

describe('UserService', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  describe('registerUser', () => {
    it('should create a new user with hashed password', async () => {
      const userData = {
        email: 'test@example.com',
        password: 'Password123!',
        firstName: 'John',
        lastName: 'Doe'
      };

      bcrypt.hash.mockResolvedValue('hashedPassword123');
      User.create.mockResolvedValue({
        id: 1,
        email: userData.email,
        firstName: userData.firstName,
        lastName: userData.lastName,
        passwordHash: 'hashedPassword123'
      });

      const result = await userService.registerUser(userData);

      expect(bcrypt.hash).toHaveBeenCalledWith(userData.password, 12);
      expect(User.create).toHaveBeenCalledWith({
        email: userData.email,
        passwordHash: 'hashedPassword123',
        firstName: userData.firstName,
        lastName: userData.lastName
      });
      expect(result.email).toBe(userData.email);
    });

    it('should throw error if email already exists', async () => {
      User.create.mockRejectedValue(new Error('Unique constraint violation'));

      await expect(
        userService.registerUser({
          email: 'existing@example.com',
          password: 'Password123!'
        })
      ).rejects.toThrow('Email already registered');
    });
  });

  describe('loginUser', () => {
    it('should return tokens for valid credentials', async () => {
      const credentials = {
        email: 'test@example.com',
        password: 'Password123!'
      };

      User.findOne.mockResolvedValue({
        id: 1,
        email: credentials.email,
        passwordHash: 'hashedPassword',
        role: 'customer'
      });

      bcrypt.compare.mockResolvedValue(true);
      jwt.sign.mockReturnValue('mockToken');

      const result = await userService.loginUser(credentials);

      expect(User.findOne).toHaveBeenCalledWith({ 
        where: { email: credentials.email } 
      });
      expect(bcrypt.compare).toHaveBeenCalledWith(
        credentials.password, 
        'hashedPassword'
      );
      expect(result).toHaveProperty('accessToken');
      expect(result).toHaveProperty('refreshToken');
    });

    it('should throw error for invalid password', async () => {
      User.findOne.mockResolvedValue({
        id: 1,
        passwordHash: 'hashedPassword'
      });
      bcrypt.compare.mockResolvedValue(false);

      await expect(
        userService.loginUser({
          email: 'test@example.com',
          password: 'WrongPassword'
        })
      ).rejects.toThrow('Invalid credentials');
    });
  });
});
```

**Example Test - Cart Service:**
```javascript
// tests/unit/services/cartService.test.js
describe('CartService', () => {
  describe('addItemToCart', () => {
    it('should add new item to cart', async () => {
      const userId = 1;
      const productId = 10;
      const quantity = 2;

      Cart.findOne.mockResolvedValue({ id: 1, userId });
      Product.findByPk.mockResolvedValue({
        id: productId,
        price: 99.99,
        stockQuantity: 50
      });
      CartItem.findOne.mockResolvedValue(null);
      CartItem.create.mockResolvedValue({
        id: 1,
        cartId: 1,
        productId,
        quantity,
        price: 99.99,
        subtotal: 199.98
      });

      const result = await cartService.addItemToCart(userId, productId, quantity);

      expect(result.quantity).toBe(quantity);
      expect(result.subtotal).toBe(199.98);
    });

    it('should update quantity if item already in cart', async () => {
      Cart.findOne.mockResolvedValue({ id: 1 });
      Product.findByPk.mockResolvedValue({ id: 10, price: 99.99, stockQuantity: 50 });
      CartItem.findOne.mockResolvedValue({
        id: 1,
        quantity: 1,
        update: jest.fn().mockResolvedValue({ quantity: 3, subtotal: 299.97 })
      });

      const result = await cartService.addItemToCart(1, 10, 2);

      expect(result.quantity).toBe(3);
    });

    it('should throw error if insufficient stock', async () => {
      Cart.findOne.mockResolvedValue({ id: 1 });
      Product.findByPk.mockResolvedValue({ 
        id: 10, 
        price: 99.99, 
        stockQuantity: 1 
      });

      await expect(
        cartService.addItemToCart(1, 10, 5)
      ).rejects.toThrow('Insufficient stock');
    });
  });
});
```

**Unit Testing Checklist:**
- [ ] All service methods tested
- [ ] All utility functions tested
- [ ] Edge cases covered
- [ ] Error scenarios tested
- [ ] Mock external dependencies
- [ ] Test data validation
- [ ] Test business logic calculations

---

### Frontend Unit Tests (Jest + React Testing Library)

**Test Structure:**
```
frontend/tests/
├── components/
├── hooks/
├── redux/
└── utils/
```

**Example Test - Product Component:**
```javascript
// tests/components/ProductCard.test.js
import { render, screen, fireEvent } from '@testing-library/react';
import { Provider } from 'react-redux';
import ProductCard from '../../../src/components/products/ProductCard';
import { store } from '../../../src/redux/store';

describe('ProductCard', () => {
  const mockProduct = {
    id: 1,
    name: 'Wireless Headphones',
    price: 99.99,
    rating: 4.5,
    reviewCount: 128,
    images: ['https://example.com/image.jpg'],
    stockQuantity: 50
  };

  it('renders product information correctly', () => {
    render(
      <Provider store={store}>
        <ProductCard product={mockProduct} />
      </Provider>
    );

    expect(screen.getByText('Wireless Headphones')).toBeInTheDocument();
    expect(screen.getByText('$99.99')).toBeInTheDocument();
    expect(screen.getByText('4.5')).toBeInTheDocument();
    expect(screen.getByText('(128 reviews)')).toBeInTheDocument();
  });

  it('calls addToCart when button clicked', () => {
    const mockAddToCart = jest.fn();
    
    render(
      <Provider store={store}>
        <ProductCard 
          product={mockProduct} 
          onAddToCart={mockAddToCart} 
        />
      </Provider>
    );

    const addButton = screen.getByRole('button', { name: /add to cart/i });
    fireEvent.click(addButton);

    expect(mockAddToCart).toHaveBeenCalledWith(mockProduct.id);
  });

  it('shows out of stock message when stockQuantity is 0', () => {
    const outOfStockProduct = { ...mockProduct, stockQuantity: 0 };

    render(
      <Provider store={store}>
        <ProductCard product={outOfStockProduct} />
      </Provider>
    );

    expect(screen.getByText(/out of stock/i)).toBeInTheDocument();
    expect(
      screen.getByRole('button', { name: /add to cart/i })
    ).toBeDisabled();
  });
});
```

**Example Test - Redux Slice:**
```javascript
// tests/redux/cartSlice.test.js
import cartReducer, { 
  addToCart, 
  updateQuantity, 
  removeFromCart 
} from '../../../src/redux/slices/cartSlice';

describe('cartSlice', () => {
  const initialState = {
    items: [],
    subtotal: 0,
    total: 0,
    loading: false,
    error: null
  };

  it('should handle addToCart', () => {
    const product = { id: 1, name: 'Product', price: 99.99, quantity: 2 };
    const state = cartReducer(initialState, addToCart(product));

    expect(state.items).toHaveLength(1);
    expect(state.items[0].id).toBe(1);
    expect(state.items[0].quantity).toBe(2);
  });

  it('should handle updateQuantity', () => {
    const stateWithItem = {
      ...initialState,
      items: [{ id: 1, quantity: 2, price: 99.99 }]
    };

    const state = cartReducer(
      stateWithItem, 
      updateQuantity({ id: 1, quantity: 5 })
    );

    expect(state.items[0].quantity).toBe(5);
  });

  it('should handle removeFromCart', () => {
    const stateWithItems = {
      ...initialState,
      items: [
        { id: 1, quantity: 2 },
        { id: 2, quantity: 1 }
      ]
    };

    const state = cartReducer(stateWithItems, removeFromCart(1));

    expect(state.items).toHaveLength(1);
    expect(state.items[0].id).toBe(2);
  });
});
```

---

## 2. Integration Testing

### Backend API Integration Tests

**Example Test - Auth Flow:**
```javascript
// tests/integration/auth.test.js
const request = require('supertest');
const app = require('../../../src/server');
const { User } = require('../../../src/models');

describe('Auth Integration Tests', () => {
  beforeAll(async () => {
    await sequelize.sync({ force: true });
  });

  afterAll(async () => {
    await sequelize.close();
  });

  describe('POST /auth/register', () => {
    it('should register a new user', async () => {
      const response = await request(app)
        .post('/api/v1/auth/register')
        .send({
          email: 'newuser@example.com',
          password: 'Password123!',
          firstName: 'John',
          lastName: 'Doe'
        });

      expect(response.status).toBe(201);
      expect(response.body.success).toBe(true);
      expect(response.body.data.user.email).toBe('newuser@example.com');

      const user = await User.findOne({ 
        where: { email: 'newuser@example.com' } 
      });
      expect(user).toBeTruthy();
    });

    it('should return error for duplicate email', async () => {
      await request(app)
        .post('/api/v1/auth/register')
        .send({
          email: 'duplicate@example.com',
          password: 'Password123!',
          firstName: 'John',
          lastName: 'Doe'
        });

      const response = await request(app)
        .post('/api/v1/auth/register')
        .send({
          email: 'duplicate@example.com',
          password: 'Password123!',
          firstName: 'Jane',
          lastName: 'Smith'
        });

      expect(response.status).toBe(409);
      expect(response.body.success).toBe(false);
    });
  });

  describe('POST /auth/login', () => {
    beforeEach(async () => {
      await request(app)
        .post('/api/v1/auth/register')
        .send({
          email: 'logintest@example.com',
          password: 'Password123!',
          firstName: 'John',
          lastName: 'Doe'
        });
    });

    it('should login with valid credentials', async () => {
      const response = await request(app)
        .post('/api/v1/auth/login')
        .send({
          email: 'logintest@example.com',
          password: 'Password123!'
        });

      expect(response.status).toBe(200);
      expect(response.body.data).toHaveProperty('tokens');
      expect(response.body.data.tokens).toHaveProperty('accessToken');
      expect(response.body.data.tokens).toHaveProperty('refreshToken');
    });

    it('should reject invalid password', async () => {
      const response = await request(app)
        .post('/api/v1/auth/login')
        .send({
          email: 'logintest@example.com',
          password: 'WrongPassword123!'
        });

      expect(response.status).toBe(401);
      expect(response.body.success).toBe(false);
    });
  });
});
```

**Example Test - Cart & Checkout Flow:**
```javascript
// tests/integration/checkout.test.js
describe('Checkout Flow Integration Test', () => {
  let authToken;
  let userId;
  let productId;

  beforeAll(async () => {
    // Setup: Register user
    const registerResponse = await request(app)
      .post('/api/v1/auth/register')
      .send({
        email: 'checkout@example.com',
        password: 'Password123!',
        firstName: 'Test',
        lastName: 'User'
      });

    // Login
    const loginResponse = await request(app)
      .post('/api/v1/auth/login')
      .send({
        email: 'checkout@example.com',
        password: 'Password123!'
      });

    authToken = loginResponse.body.data.tokens.accessToken;
    userId = loginResponse.body.data.user.id;

    // Create test product
    const product = await Product.create({
      sku: 'TEST-001',
      name: 'Test Product',
      price: 99.99,
      stockQuantity: 10
    });
    productId = product.id;
  });

  it('should complete full checkout flow', async () => {
    // 1. Add item to cart
    const addToCartResponse = await request(app)
      .post('/api/v1/cart/items')
      .set('Authorization', `Bearer ${authToken}`)
      .send({ productId, quantity: 2 });

    expect(addToCartResponse.status).toBe(200);

    // 2. Get cart
    const cartResponse = await request(app)
      .get('/api/v1/cart')
      .set('Authorization', `Bearer ${authToken}`);

    expect(cartResponse.body.data.cart.items).toHaveLength(1);
    expect(cartResponse.body.data.cart.total).toBe(199.98);

    // 3. Create address
    const addressResponse = await request(app)
      .post('/api/v1/addresses')
      .set('Authorization', `Bearer ${authToken}`)
      .send({
        type: 'both',
        firstName: 'Test',
        lastName: 'User',
        addressLine1: '123 Main St',
        city: 'New York',
        state: 'NY',
        postalCode: '10001',
        country: 'US'
      });

    const addressId = addressResponse.body.data.address.id;

    // 4. Create order
    const orderResponse = await request(app)
      .post('/api/v1/orders')
      .set('Authorization', `Bearer ${authToken}`)
      .send({
        shippingAddressId: addressId,
        billingAddressId: addressId,
        paymentMethodId: 'pm_test_123'
      });

    expect(orderResponse.status).toBe(201);
    expect(orderResponse.body.data.order.status).toBe('pending');

    // 5. Verify cart is cleared
    const finalCartResponse = await request(app)
      .get('/api/v1/cart')
      .set('Authorization', `Bearer ${authToken}`);

    expect(finalCartResponse.body.data.cart.items).toHaveLength(0);

    // 6. Verify inventory reduced
    const productAfter = await Product.findByPk(productId);
    expect(productAfter.stockQuantity).toBe(8);
  });
});
```

**Integration Testing Checklist:**
- [ ] Full authentication flow tested
- [ ] Product catalog operations tested
- [ ] Cart operations tested
- [ ] Checkout flow tested
- [ ] Payment integration tested (test mode)
- [ ] Order creation and tracking tested
- [ ] Admin operations tested
- [ ] Database transactions verified
- [ ] API error responses tested
- [ ] Rate limiting tested

---

## 3. End-to-End (E2E) Testing

### E2E Tests with Cypress

**Test Structure:**
```
cypress/
├── e2e/
│   ├── auth.cy.js
│   ├── shopping.cy.js
│   ├── checkout.cy.js
│   └── admin.cy.js
├── fixtures/
├── support/
└── cypress.config.js
```

**Example Test - Shopping Flow:**
```javascript
// cypress/e2e/shopping.cy.js
describe('Shopping Flow E2E', () => {
  beforeEach(() => {
    cy.visit('/');
  });

  it('should complete full shopping journey', () => {
    // 1. Browse products
    cy.contains('Products').click();
    cy.url().should('include', '/products');
    cy.get('[data-testid="product-card"]').should('have.length.at.least', 1);

    // 2. Search for product
    cy.get('[data-testid="search-input"]').type('headphones');
    cy.get('[data-testid="search-button"]').click();
    cy.contains('Wireless Headphones').should('be.visible');

    // 3. View product details
    cy.contains('Wireless Headphones').click();
    cy.url().should('include', '/products/');
    cy.contains('$99.99').should('be.visible');

    // 4. Add to cart
    cy.get('[data-testid="add-to-cart-button"]').click();
    cy.contains('Added to cart').should('be.visible');
    cy.get('[data-testid="cart-badge"]').should('contain', '1');

    // 5. View cart
    cy.get('[data-testid="cart-icon"]').click();
    cy.url().should('include', '/cart');
    cy.contains('Wireless Headphones').should('be.visible');
    cy.contains('$99.99').should('be.visible');

    // 6. Update quantity
    cy.get('[data-testid="quantity-input"]').clear().type('2');
    cy.contains('$199.98').should('be.visible');

    // 7. Proceed to checkout (requires login)
    cy.get('[data-testid="checkout-button"]').click();
    cy.url().should('include', '/login');

    // 8. Login
    cy.get('[data-testid="email-input"]').type('test@example.com');
    cy.get('[data-testid="password-input"]').type('Password123!');
    cy.get('[data-testid="login-button"]').click();

    // 9. Should redirect to checkout
    cy.url().should('include', '/checkout');

    // 10. Fill shipping information
    cy.get('[data-testid="first-name"]').type('John');
    cy.get('[data-testid="last-name"]').type('Doe');
    cy.get('[data-testid="address"]').type('123 Main St');
    cy.get('[data-testid="city"]').type('New York');
    cy.get('[data-testid="state"]').select('NY');
    cy.get('[data-testid="postal-code"]').type('10001');
    cy.get('[data-testid="continue-button"]').click();

    // 11. Enter payment (Stripe test mode)
    cy.get('[data-testid="card-number"]')
      .within(() => {
        cy.get('iframe').then($iframe => {
          const $body = $iframe.contents().find('body');
          cy.wrap($body).find('input').type('4242424242424242');
        });
      });
    
    cy.get('[data-testid="card-expiry"]')
      .within(() => {
        cy.get('iframe').then($iframe => {
          const $body = $iframe.contents().find('body');
          cy.wrap($body).find('input').type('1225');
        });
      });

    cy.get('[data-testid="card-cvc"]')
      .within(() => {
        cy.get('iframe').then($iframe => {
          const $body = $iframe.contents().find('body');
          cy.wrap($body).find('input').type('123');
        });
      });

    // 12. Place order
    cy.get('[data-testid="place-order-button"]').click();

    // 13. Verify order confirmation
    cy.url().should('include', '/order-confirmation');
    cy.contains('Order Placed Successfully').should('be.visible');
    cy.contains('Order Number:').should('be.visible');
    cy.contains('$199.98').should('be.visible');
  });
});
```

**E2E Testing Checklist:**
- [ ] User registration flow
- [ ] User login flow
- [ ] Product browsing and search
- [ ] Product filtering and sorting
- [ ] Add to cart flow
- [ ] Cart management
- [ ] Checkout flow
- [ ] Payment processing
- [ ] Order confirmation
- [ ] Order history viewing
- [ ] Admin login and operations
- [ ] Responsive design on mobile/tablet
- [ ] Error scenarios (network failures, validation errors)

---

## 4. Performance Testing

### Load Testing with Artillery

**Configuration:**
```yaml
# artillery-config.yml
config:
  target: 'https://api.example.com'
  phases:
    - duration: 60
      arrivalRate: 10
      name: "Warm up"
    - duration: 120
      arrivalRate: 50
      name: "Sustained load"
    - duration: 60
      arrivalRate: 100
      name: "Peak load"
  payload:
    path: "users.csv"
    fields:
      - "email"
      - "password"

scenarios:
  - name: "Product Browsing"
    flow:
      - get:
          url: "/api/v1/products?page=1&limit=20"
          capture:
            - json: "$.data.products[0].id"
              as: "productId"
      - get:
          url: "/api/v1/products/{{ productId }}"
      - think: 2

  - name: "Add to Cart Flow"
    flow:
      - post:
          url: "/api/v1/auth/login"
          json:
            email: "{{ email }}"
            password: "{{ password }}"
          capture:
            - json: "$.data.tokens.accessToken"
              as: "token"
      - post:
          url: "/api/v1/cart/items"
          headers:
            Authorization: "Bearer {{ token }}"
          json:
            productId: 1
            quantity: 2
      - think: 1
      - get:
          url: "/api/v1/cart"
          headers:
            Authorization: "Bearer {{ token }}"
```

**Run:**
```bash
artillery run artillery-config.yml --output report.json
artillery report report.json
```

**Performance Testing Checklist:**
- [ ] API response time < 500ms (95th percentile)
- [ ] Page load time < 2 seconds
- [ ] Support 1000 concurrent users
- [ ] Database query performance optimized
- [ ] CDN caching effectiveness
- [ ] Redis cache hit rate > 80%
- [ ] No memory leaks under sustained load

---

## 5. Security Testing

**Security Testing Checklist:**
- [ ] SQL injection testing
- [ ] XSS vulnerability testing
- [ ] CSRF protection verification
- [ ] Authentication bypass attempts
- [ ] Authorization testing
- [ ] Session management testing
- [ ] Rate limiting verification
- [ ] File upload vulnerability testing
- [ ] OWASP ZAP scan
- [ ] Dependency vulnerability scan (npm audit)

**Tools:**
- OWASP ZAP
- Burp Suite
- npm audit
- Snyk

---

## 6. Test Data Management

### Test Fixtures

```javascript
// tests/fixtures/users.js
module.exports = {
  validUser: {
    email: 'test@example.com',
    password: 'Password123!',
    firstName: 'John',
    lastName: 'Doe'
  },
  adminUser: {
    email: 'admin@example.com',
    password: 'AdminPass123!',
    firstName: 'Admin',
    lastName: 'User',
    role: 'admin'
  }
};

// tests/fixtures/products.js
module.exports = {
  sampleProducts: [
    {
      sku: 'PROD-001',
      name: 'Wireless Headphones',
      price: 99.99,
      stockQuantity: 50,
      categoryId: 1
    },
    {
      sku: 'PROD-002',
      name: 'Smart Watch',
      price: 199.99,
      stockQuantity: 30,
      categoryId: 1
    }
  ]
};
```

---

## 7. CI/CD Testing Integration

### GitHub Actions Workflow

```yaml
# .github/workflows/test.yml
name: Test Suite

on:
  push:
    branches: [ main, develop ]
  pull_request:
    branches: [ main, develop ]

jobs:
  test:
    runs-on: ubuntu-latest

    services:
      postgres:
        image: postgres:14
        env:
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
      - uses: actions/checkout@v3

      - name: Setup Node.js
        uses: actions/setup-node@v3
        with:
          node-version: '18'
          cache: 'npm'

      - name: Install dependencies
        run: npm ci

      - name: Run linter
        run: npm run lint

      - name: Run unit tests
        run: npm run test:unit
        env:
          NODE_ENV: test
          DATABASE_URL: postgresql://postgres:postgres@localhost:5432/ecommerce_test

      - name: Run integration tests
        run: npm run test:integration
        env:
          NODE_ENV: test
          DATABASE_URL: postgresql://postgres:postgres@localhost:5432/ecommerce_test
          REDIS_HOST: localhost
          REDIS_PORT: 6379

      - name: Generate coverage report
        run: npm run test:coverage

      - name: Upload coverage to Codecov
        uses: codecov/codecov-action@v3
        with:
          file: ./coverage/lcov.info
          fail_ci_if_error: true

      - name: Check coverage threshold
        run: |
          COVERAGE=$(cat coverage/coverage-summary.json | jq '.total.lines.pct')
          if (( $(echo "$COVERAGE < 80" | bc -l) )); then
            echo "Coverage $COVERAGE% is below 80% threshold"
            exit 1
          fi
```

---

## 8. Test Execution Strategy

### Development Phase
```bash
# Run all unit tests
npm run test:unit

# Run tests in watch mode
npm run test:watch

# Run tests with coverage
npm run test:coverage

# Run specific test file
npm test -- tests/unit/services/userService.test.js
```

### Pre-commit
```bash
# Run lint + unit tests
npm run pre-commit
```

### Pull Request
```bash
# Run full test suite
npm run test:all

# Run E2E tests
npm run test:e2e
```

### Pre-deployment
```bash
# Full test suite + performance tests
npm run test:all
npm run test:performance
```

---

## 9. Test Metrics & Reporting

### Coverage Requirements
- **Overall**: 80% minimum
- **Critical paths** (auth, payment, checkout): 95% minimum
- **Services**: 90% minimum
- **Controllers**: 80% minimum
- **Utils**: 85% minimum

### Test Reporting
- Jest coverage reports
- Codecov integration
- CI/CD test results dashboard
- Performance metrics dashboard

---

## Testing Best Practices

1. **Test Naming**: Use descriptive names (should/when pattern)
2. **Arrange-Act-Assert**: Follow AAA pattern
3. **Test Isolation**: Each test independent
4. **Mock External Services**: Don't call real APIs/payments
5. **Clean Test Data**: Setup and teardown properly
6. **Fast Tests**: Unit tests < 100ms
7. **Deterministic Tests**: No flaky tests
8. **Test Edge Cases**: Not just happy paths
9. **Document Complex Tests**: Add comments for clarity
10. **Review Test Coverage**: Regular coverage audits
