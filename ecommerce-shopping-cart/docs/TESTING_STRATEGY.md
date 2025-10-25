# Testing Strategy

## Overview

Comprehensive testing strategy for E-Commerce Shopping Cart System with 80%+ coverage target.

---

## 🎯 Testing Objectives

1. **Quality Assurance:** Ensure code reliability and correctness
2. **Regression Prevention:** Catch bugs before production
3. **Documentation:** Tests serve as living documentation
4. **Confidence:** Safe refactoring and feature additions
5. **Coverage Target:** Minimum 80% code coverage

---

## 🧪 Testing Pyramid

```
           /\
          /  \  E2E Tests (10%)
         /____\
        /      \
       / Integ. \ Integration Tests (30%)
      /__________\
     /            \
    /  Unit Tests  \ Unit Tests (60%)
   /________________\
```

---

## 1. Unit Testing

### Backend Unit Tests (Node.js)

**Framework:** Jest + Supertest  
**Coverage Target:** 85%

#### What to Test
- **Models:** Sequelize model methods, validations, associations
- **Services:** Business logic functions
- **Utils:** Helper functions, formatters, validators
- **Middleware:** Authentication, authorization, error handling

#### Example: User Model Test
```javascript
describe('User Model', () => {
  test('should hash password before saving', async () => {
    const user = await User.create({
      email: 'test@example.com',
      password: 'password123'
    });
    expect(user.password).not.toBe('password123');
    expect(user.password.length).toBeGreaterThan(20);
  });

  test('should validate password correctly', async () => {
    const user = await User.create({
      email: 'test@example.com',
      password: 'password123'
    });
    const isValid = await user.validatePassword('password123');
    expect(isValid).toBe(true);
  });

  test('should not create user with duplicate email', async () => {
    await User.create({ email: 'test@example.com', password: 'pass123' });
    await expect(
      User.create({ email: 'test@example.com', password: 'pass456' })
    ).rejects.toThrow();
  });
});
```

#### Example: Service Test
```javascript
describe('Product Service', () => {
  test('should calculate discounted price correctly', () => {
    const result = ProductService.calculateDiscount(100, 20);
    expect(result).toBe(80);
  });

  test('should check product availability', async () => {
    const product = await Product.create({ id: 1, sku: 'TEST-001' });
    await Inventory.create({ productId: 1, quantity: 5 });
    
    const isAvailable = await ProductService.isAvailable(1, 3);
    expect(isAvailable).toBe(true);
  });
});
```

### Frontend Unit Tests (React)

**Framework:** Jest + React Testing Library  
**Coverage Target:** 80%

#### What to Test
- **Components:** Props, rendering, user interactions
- **Redux:** Reducers, actions, selectors
- **Utils:** Helper functions, formatters
- **Hooks:** Custom hooks behavior

#### Example: Component Test
```javascript
import { render, screen, fireEvent } from '@testing-library/react';
import ProductCard from './ProductCard';

describe('ProductCard', () => {
  const mockProduct = {
    id: 1,
    name: 'Test Product',
    price: 99.99,
    image: 'test.jpg'
  };

  test('renders product information', () => {
    render(<ProductCard product={mockProduct} />);
    expect(screen.getByText('Test Product')).toBeInTheDocument();
    expect(screen.getByText('$99.99')).toBeInTheDocument();
  });

  test('calls onAddToCart when button clicked', () => {
    const mockAddToCart = jest.fn();
    render(<ProductCard product={mockProduct} onAddToCart={mockAddToCart} />);
    
    fireEvent.click(screen.getByText('Add to Cart'));
    expect(mockAddToCart).toHaveBeenCalledWith(mockProduct);
  });
});
```

#### Example: Redux Test
```javascript
import cartReducer, { addToCart, removeFromCart } from './cartSlice';

describe('Cart Reducer', () => {
  test('should add item to cart', () => {
    const initialState = { items: [] };
    const action = addToCart({ id: 1, name: 'Product', quantity: 1 });
    const newState = cartReducer(initialState, action);
    
    expect(newState.items).toHaveLength(1);
    expect(newState.items[0].id).toBe(1);
  });

  test('should increase quantity for existing item', () => {
    const initialState = { items: [{ id: 1, quantity: 1 }] };
    const action = addToCart({ id: 1, quantity: 2 });
    const newState = cartReducer(initialState, action);
    
    expect(newState.items[0].quantity).toBe(3);
  });
});
```

---

## 2. Integration Testing

### API Integration Tests (Backend)

**Framework:** Jest + Supertest  
**Coverage Target:** Key API flows

#### What to Test
- **API Endpoints:** Request/response validation
- **Database Operations:** CRUD operations with real DB
- **Authentication Flow:** Token generation, validation
- **Business Logic:** Multi-step workflows

#### Example: Authentication Integration Test
```javascript
describe('Authentication API', () => {
  let server;
  
  beforeAll(async () => {
    server = await createServer();
    await setupTestDatabase();
  });

  afterAll(async () => {
    await teardownTestDatabase();
    await server.close();
  });

  test('POST /auth/register creates new user', async () => {
    const response = await request(server)
      .post('/api/v1/auth/register')
      .send({
        email: 'test@example.com',
        password: 'SecurePass123!',
        firstName: 'John',
        lastName: 'Doe'
      });

    expect(response.status).toBe(201);
    expect(response.body.data.user.email).toBe('test@example.com');
    expect(response.body.data.tokens.accessToken).toBeDefined();
  });

  test('POST /auth/login with valid credentials', async () => {
    // Create user first
    await User.create({
      email: 'test@example.com',
      password: await bcrypt.hash('password123', 12)
    });

    const response = await request(server)
      .post('/api/v1/auth/login')
      .send({
        email: 'test@example.com',
        password: 'password123'
      });

    expect(response.status).toBe(200);
    expect(response.body.data.tokens.accessToken).toBeDefined();
  });
});
```

#### Example: Order Flow Integration Test
```javascript
describe('Order Creation Flow', () => {
  let authToken, userId;

  beforeEach(async () => {
    // Setup: Create user, add products to cart
    const user = await User.create({ email: 'test@example.com', password: 'pass' });
    userId = user.id;
    authToken = generateToken(user);
    
    const product = await Product.create({ id: 1, price: 100 });
    await Inventory.create({ productId: 1, quantity: 10 });
    await CartItem.create({ userId, productId: 1, quantity: 2 });
  });

  test('should create order from cart', async () => {
    const response = await request(server)
      .post('/api/v1/orders')
      .set('Authorization', `Bearer ${authToken}`)
      .send({
        shippingAddressId: 1,
        billingAddressId: 1,
        paymentIntentId: 'pi_test_123'
      });

    expect(response.status).toBe(201);
    expect(response.body.data.order.total).toBe(200);
    
    // Verify cart is cleared
    const cart = await CartItem.findAll({ where: { userId } });
    expect(cart).toHaveLength(0);
    
    // Verify inventory is reserved
    const inventory = await Inventory.findOne({ where: { productId: 1 } });
    expect(inventory.reservedQuantity).toBe(2);
  });
});
```

### Frontend Integration Tests

**Framework:** Jest + React Testing Library  
**Coverage Target:** Key user flows

#### Example: Cart Integration Test
```javascript
import { render, screen, fireEvent, waitFor } from '@testing-library/react';
import { Provider } from 'react-redux';
import { store } from './store';
import App from './App';

describe('Shopping Cart Flow', () => {
  test('add product to cart and checkout', async () => {
    render(
      <Provider store={store}>
        <App />
      </Provider>
    );

    // Navigate to product page
    fireEvent.click(screen.getByText('Browse Products'));
    
    // Add to cart
    await waitFor(() => {
      fireEvent.click(screen.getByText('Add to Cart'));
    });
    
    // Verify cart icon updates
    expect(screen.getByText('1')).toBeInTheDocument(); // Cart count
    
    // Go to cart
    fireEvent.click(screen.getByLabelText('Cart'));
    
    // Verify product in cart
    expect(screen.getByText('Product Name')).toBeInTheDocument();
    
    // Proceed to checkout
    fireEvent.click(screen.getByText('Checkout'));
    expect(screen.getByText('Shipping Address')).toBeInTheDocument();
  });
});
```

---

## 3. End-to-End (E2E) Testing

**Framework:** Cypress  
**Coverage Target:** Critical user journeys

### Critical User Flows

#### 1. Complete Purchase Flow
```javascript
describe('Complete Purchase Flow', () => {
  it('should complete purchase from registration to order confirmation', () => {
    // 1. Register
    cy.visit('/register');
    cy.get('[data-testid="email"]').type('newuser@example.com');
    cy.get('[data-testid="password"]').type('SecurePass123!');
    cy.get('[data-testid="register-btn"]').click();
    
    // 2. Browse products
    cy.contains('Browse Products').click();
    cy.get('[data-testid="product-card"]').first().click();
    
    // 3. Add to cart
    cy.get('[data-testid="add-to-cart"]').click();
    cy.contains('Added to cart').should('be.visible');
    
    // 4. Go to cart
    cy.get('[data-testid="cart-icon"]').click();
    cy.contains('Proceed to Checkout').click();
    
    // 5. Add shipping address
    cy.get('[data-testid="add-address"]').click();
    cy.get('[data-testid="street"]').type('123 Main St');
    cy.get('[data-testid="city"]').type('New York');
    cy.get('[data-testid="state"]').type('NY');
    cy.get('[data-testid="postal-code"]').type('10001');
    cy.get('[data-testid="save-address"]').click();
    
    // 6. Payment (using Stripe test card)
    cy.get('[data-testid="next-step"]').click();
    cy.get('iframe[name^="__privateStripeFrame"]').then($iframe => {
      const $body = $iframe.contents().find('body');
      cy.wrap($body)
        .find('input[name="cardnumber"]')
        .type('4242424242424242');
      cy.wrap($body)
        .find('input[name="exp-date"]')
        .type('1225');
      cy.wrap($body)
        .find('input[name="cvc"]')
        .type('123');
    });
    
    // 7. Place order
    cy.get('[data-testid="place-order"]').click();
    
    // 8. Verify order confirmation
    cy.contains('Order Confirmed').should('be.visible');
    cy.get('[data-testid="order-number"]').should('exist');
  });
});
```

#### 2. Admin Product Management
```javascript
describe('Admin Product Management', () => {
  beforeEach(() => {
    cy.loginAsAdmin();
  });

  it('should create, edit, and delete product', () => {
    // Create product
    cy.visit('/admin/products');
    cy.get('[data-testid="add-product"]').click();
    cy.get('[data-testid="product-name"]').type('New Product');
    cy.get('[data-testid="product-sku"]').type('NP-001');
    cy.get('[data-testid="product-price"]').type('99.99');
    cy.get('[data-testid="save-product"]').click();
    cy.contains('Product created successfully').should('be.visible');
    
    // Edit product
    cy.contains('New Product').click();
    cy.get('[data-testid="edit-product"]').click();
    cy.get('[data-testid="product-price"]').clear().type('89.99');
    cy.get('[data-testid="save-product"]').click();
    cy.contains('$89.99').should('be.visible');
    
    // Delete product
    cy.get('[data-testid="delete-product"]').click();
    cy.get('[data-testid="confirm-delete"]').click();
    cy.contains('Product deleted').should('be.visible');
  });
});
```

---

## 4. Performance Testing

**Tools:** Artillery, k6, Lighthouse

### Load Testing Script (Artillery)

```yaml
config:
  target: 'https://api.example.com'
  phases:
    - duration: 60
      arrivalRate: 10
      name: "Warm up"
    - duration: 300
      arrivalRate: 50
      name: "Sustained load"
    - duration: 120
      arrivalRate: 100
      name: "Peak load"
  
scenarios:
  - name: "Browse and purchase"
    flow:
      - post:
          url: "/api/v1/auth/login"
          json:
            email: "{{ $randomEmail() }}"
            password: "password123"
          capture:
            - json: "$.data.tokens.accessToken"
              as: "token"
      - get:
          url: "/api/v1/products"
          headers:
            Authorization: "Bearer {{ token }}"
      - post:
          url: "/api/v1/cart/items"
          headers:
            Authorization: "Bearer {{ token }}"
          json:
            productId: 1
            quantity: 2
      - post:
          url: "/api/v1/orders"
          headers:
            Authorization: "Bearer {{ token }}"
          json:
            shippingAddressId: 1
            paymentIntentId: "pi_test_{{ $randomString() }}"
```

### Performance Benchmarks

| Metric | Target | Critical |
|--------|--------|----------|
| API Response Time (p95) | < 500ms | < 1000ms |
| API Response Time (p99) | < 1000ms | < 2000ms |
| Page Load Time (desktop) | < 2s | < 3s |
| Page Load Time (mobile) | < 3s | < 5s |
| Time to Interactive | < 3s | < 5s |
| Concurrent Users | 1000 | 500 |
| Requests per Second | 500 | 250 |

---

## 5. Security Testing

### Automated Security Scans

#### npm audit
```bash
npm audit --production
npm audit fix
```

#### OWASP ZAP
```bash
# Run ZAP in daemon mode
zap.sh -daemon -port 8080 -config api.disablekey=true

# Run baseline scan
zap-baseline.py -t https://example.com -r zap-report.html
```

#### Snyk
```bash
snyk test
snyk monitor
```

### Manual Security Tests

#### 1. Authentication Tests
- [ ] SQL injection in login form
- [ ] Brute force protection
- [ ] Password reset token expiration
- [ ] JWT token tampering
- [ ] Session fixation

#### 2. Authorization Tests
- [ ] Horizontal privilege escalation (access other users' data)
- [ ] Vertical privilege escalation (regular user accessing admin endpoints)
- [ ] IDOR (Insecure Direct Object Reference)

#### 3. Input Validation Tests
- [ ] XSS in product descriptions
- [ ] Command injection
- [ ] Path traversal in file uploads
- [ ] CSRF token validation

#### 4. Payment Security Tests
- [ ] Price manipulation
- [ ] Webhook signature validation
- [ ] Payment intent verification

---

## 6. Test Data Management

### Test Database Setup

```javascript
// test-setup.js
const { sequelize } = require('./models');

async function setupTestDatabase() {
  await sequelize.sync({ force: true });
  await seedTestData();
}

async function seedTestData() {
  await User.bulkCreate([
    { email: 'admin@example.com', role: 'admin', password: hashedPass },
    { email: 'user@example.com', role: 'customer', password: hashedPass }
  ]);
  
  await Product.bulkCreate([
    { id: 1, name: 'Test Product 1', price: 100, sku: 'TEST-001' },
    { id: 2, name: 'Test Product 2', price: 200, sku: 'TEST-002' }
  ]);
}

module.exports = { setupTestDatabase };
```

### Fixtures for Frontend Tests

```javascript
// fixtures/products.js
export const mockProducts = [
  {
    id: 1,
    name: 'Premium Headphones',
    price: 199.99,
    image: 'https://via.placeholder.com/300',
    rating: 4.5
  },
  // ... more products
];
```

---

## 7. CI/CD Testing Pipeline

### GitHub Actions Workflow

```yaml
name: Test Suite

on: [push, pull_request]

jobs:
  backend-tests:
    runs-on: ubuntu-latest
    services:
      postgres:
        image: postgres:14
        env:
          POSTGRES_PASSWORD: test
        options: >-
          --health-cmd pg_isready
          --health-interval 10s
    steps:
      - uses: actions/checkout@v2
      - uses: actions/setup-node@v2
        with:
          node-version: '18'
      - run: cd backend && npm ci
      - run: cd backend && npm run test:coverage
      - uses: codecov/codecov-action@v2
        with:
          files: ./backend/coverage/lcov.info

  frontend-tests:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - uses: actions/setup-node@v2
      - run: cd frontend && npm ci
      - run: cd frontend && npm run test:coverage
      - uses: codecov/codecov-action@v2
        with:
          files: ./frontend/coverage/lcov.info

  e2e-tests:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - uses: cypress-io/github-action@v4
        with:
          start: npm start
          wait-on: 'http://localhost:3000'
          record: true
        env:
          CYPRESS_RECORD_KEY: ${{ secrets.CYPRESS_RECORD_KEY }}

  security-scan:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - run: npm audit --production
      - uses: snyk/actions/node@master
        env:
          SNYK_TOKEN: ${{ secrets.SNYK_TOKEN }}
```

---

## 8. Test Reporting

### Coverage Reports
- **Tool:** Istanbul/nyc
- **Format:** HTML, LCOV, JSON
- **Minimum:** 80% coverage
- **Publish:** Codecov or Coveralls

### Test Results
- **Tool:** Jest, Cypress
- **Format:** JUnit XML, JSON
- **Publish:** GitHub Actions artifacts

---

## 9. Testing Checklist

### Pre-Commit
- [ ] Run unit tests locally
- [ ] Run linter (ESLint)
- [ ] Run formatter (Prettier)

### Pre-PR
- [ ] All tests passing
- [ ] Coverage threshold met
- [ ] No new security vulnerabilities
- [ ] Manual testing of changed features

### Pre-Deployment
- [ ] All CI/CD tests passing
- [ ] E2E tests passing
- [ ] Performance tests acceptable
- [ ] Security scan passed
- [ ] Manual UAT completed

---

**Document Version:** 1.0  
**Last Updated:** October 24, 2025
