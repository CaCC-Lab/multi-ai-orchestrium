# E-Commerce Shopping Cart System - Security Checklist & Implementation Guide

## Security Overview

This document provides a comprehensive security checklist and implementation guide for the E-Commerce Shopping Cart System.

---

## 1. Authentication & Authorization

### ✅ Password Security

**Implementation:**
```javascript
const bcrypt = require('bcrypt');
const SALT_ROUNDS = 12;

// Hash password during registration
async function hashPassword(plainPassword) {
  return await bcrypt.hash(plainPassword, SALT_ROUNDS);
}

// Verify password during login
async function verifyPassword(plainPassword, hashedPassword) {
  return await bcrypt.compare(plainPassword, hashedPassword);
}
```

**Checklist:**
- [ ] Passwords hashed with bcrypt (min 12 rounds)
- [ ] Minimum password requirements enforced (8 chars, uppercase, lowercase, number, special char)
- [ ] Password strength indicator on frontend
- [ ] No password storage in plain text anywhere
- [ ] Password reset tokens expire after 1 hour
- [ ] Old passwords not reusable (last 5 passwords)

---

### ✅ JWT Token Security

**Implementation:**
```javascript
const jwt = require('jsonwebtoken');

// Generate access token (short-lived)
function generateAccessToken(user) {
  return jwt.sign(
    { userId: user.id, email: user.email, role: user.role },
    process.env.JWT_ACCESS_SECRET,
    { expiresIn: '15m' }
  );
}

// Generate refresh token (long-lived)
function generateRefreshToken(user) {
  return jwt.sign(
    { userId: user.id, type: 'refresh' },
    process.env.JWT_REFRESH_SECRET,
    { expiresIn: '7d' }
  );
}

// Verify token middleware
function authenticateToken(req, res, next) {
  const authHeader = req.headers['authorization'];
  const token = authHeader && authHeader.split(' ')[1];

  if (!token) {
    return res.status(401).json({ error: 'Access token required' });
  }

  jwt.verify(token, process.env.JWT_ACCESS_SECRET, (err, user) => {
    if (err) {
      return res.status(403).json({ error: 'Invalid or expired token' });
    }
    req.user = user;
    next();
  });
}
```

**Checklist:**
- [ ] Access tokens short-lived (15 minutes)
- [ ] Refresh tokens long-lived (7 days)
- [ ] Tokens signed with strong secrets (min 256 bits)
- [ ] Refresh token rotation implemented
- [ ] Token blacklist for logout
- [ ] Tokens stored securely in httpOnly cookies (not localStorage)
- [ ] Token refresh mechanism implemented
- [ ] JWT secrets stored in environment variables

---

### ✅ Role-Based Access Control (RBAC)

**Implementation:**
```javascript
// Authorization middleware
function requireRole(...allowedRoles) {
  return (req, res, next) => {
    if (!req.user) {
      return res.status(401).json({ error: 'Authentication required' });
    }

    if (!allowedRoles.includes(req.user.role)) {
      return res.status(403).json({ error: 'Insufficient permissions' });
    }

    next();
  };
}

// Usage
app.get('/admin/products', 
  authenticateToken, 
  requireRole('admin', 'super_admin'), 
  productController.adminGetProducts
);
```

**Checklist:**
- [ ] User roles defined (customer, admin, super_admin)
- [ ] Role-based middleware implemented
- [ ] Admin routes protected with role checks
- [ ] Principle of least privilege enforced
- [ ] Role changes logged and audited

---

## 2. Input Validation & Sanitization

### ✅ Request Validation

**Implementation:**
```javascript
const Joi = require('joi');

// Validation schema
const registerSchema = Joi.object({
  email: Joi.string().email().required(),
  password: Joi.string().min(8).pattern(/^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[@$!%*?&])[A-Za-z\d@$!%*?&]/).required(),
  firstName: Joi.string().min(2).max(100).required(),
  lastName: Joi.string().min(2).max(100).required(),
  phone: Joi.string().pattern(/^\+?[1-9]\d{1,14}$/).optional()
});

// Validation middleware
function validateRequest(schema) {
  return (req, res, next) => {
    const { error, value } = schema.validate(req.body, { abortEarly: false });
    
    if (error) {
      const errors = error.details.map(detail => ({
        field: detail.path.join('.'),
        message: detail.message
      }));
      return res.status(400).json({ 
        success: false, 
        error: { code: 'VALIDATION_ERROR', details: errors } 
      });
    }
    
    req.validatedBody = value;
    next();
  };
}

// Usage
app.post('/auth/register', validateRequest(registerSchema), authController.register);
```

**Checklist:**
- [ ] All user inputs validated (server-side)
- [ ] Validation library used (Joi/Express-validator)
- [ ] Email format validation
- [ ] Phone number format validation
- [ ] Numeric ranges validated
- [ ] String length limits enforced
- [ ] File upload type and size restrictions
- [ ] Frontend validation as UX enhancement (not security)

---

### ✅ SQL Injection Prevention

**Implementation:**
```javascript
// ✅ CORRECT: Using Sequelize ORM (parameterized queries)
const products = await Product.findAll({
  where: {
    name: { [Op.like]: `%${searchTerm}%` },
    price: { [Op.between]: [minPrice, maxPrice] }
  }
});

// ❌ WRONG: String concatenation
const query = `SELECT * FROM products WHERE name LIKE '%${searchTerm}%'`;
```

**Checklist:**
- [ ] ORM (Sequelize) used for all database queries
- [ ] No raw SQL queries with user input concatenation
- [ ] Parameterized queries for any raw SQL
- [ ] Database user has minimum required privileges
- [ ] Input validation before database operations

---

### ✅ XSS (Cross-Site Scripting) Prevention

**Implementation:**
```javascript
const xss = require('xss');
const helmet = require('helmet');

// Content Security Policy
app.use(helmet.contentSecurityPolicy({
  directives: {
    defaultSrc: ["'self'"],
    scriptSrc: ["'self'", "'unsafe-inline'", "https://js.stripe.com"],
    styleSrc: ["'self'", "'unsafe-inline'"],
    imgSrc: ["'self'", "data:", "https://cdn.example.com"],
    connectSrc: ["'self'", "https://api.stripe.com"]
  }
}));

// Sanitize user input
function sanitizeInput(input) {
  return xss(input, {
    whiteList: {}, // No HTML tags allowed
    stripIgnoreTag: true
  });
}

// Sanitize middleware for text fields
function sanitizeRequestBody(req, res, next) {
  if (req.body) {
    Object.keys(req.body).forEach(key => {
      if (typeof req.body[key] === 'string') {
        req.body[key] = sanitizeInput(req.body[key]);
      }
    });
  }
  next();
}
```

**Checklist:**
- [ ] Helmet.js configured with CSP
- [ ] User-generated content sanitized (xss library)
- [ ] HTML entities escaped in templates
- [ ] Output encoding for different contexts
- [ ] No inline JavaScript in HTML
- [ ] No eval() or Function() constructor usage
- [ ] DOM manipulation using safe methods

---

### ✅ CSRF (Cross-Site Request Forgery) Prevention

**Implementation:**
```javascript
const csrf = require('csurf');
const cookieParser = require('cookie-parser');

app.use(cookieParser());

// CSRF protection middleware
const csrfProtection = csrf({ 
  cookie: { 
    httpOnly: true, 
    secure: process.env.NODE_ENV === 'production',
    sameSite: 'strict'
  } 
});

// Apply to state-changing routes
app.post('/cart/items', csrfProtection, cartController.addItem);
app.post('/orders', csrfProtection, orderController.createOrder);

// Send CSRF token to frontend
app.get('/csrf-token', csrfProtection, (req, res) => {
  res.json({ csrfToken: req.csrfToken() });
});
```

**Frontend:**
```javascript
// Fetch CSRF token
const response = await fetch('/csrf-token');
const { csrfToken } = await response.json();

// Include in requests
fetch('/cart/items', {
  method: 'POST',
  headers: {
    'Content-Type': 'application/json',
    'CSRF-Token': csrfToken
  },
  body: JSON.stringify({ productId: 1, quantity: 2 })
});
```

**Checklist:**
- [ ] CSRF tokens for state-changing operations (POST/PUT/DELETE)
- [ ] Tokens validated on server-side
- [ ] Tokens rotated after authentication
- [ ] SameSite cookie attribute set
- [ ] GET requests idempotent (no state changes)

---

## 3. Session & Cookie Security

**Implementation:**
```javascript
const session = require('express-session');
const RedisStore = require('connect-redis')(session);
const redis = require('redis');

const redisClient = redis.createClient({
  host: process.env.REDIS_HOST,
  port: process.env.REDIS_PORT
});

app.use(session({
  store: new RedisStore({ client: redisClient }),
  secret: process.env.SESSION_SECRET,
  resave: false,
  saveUninitialized: false,
  name: 'sessionId', // Custom name (not 'connect.sid')
  cookie: {
    httpOnly: true,
    secure: process.env.NODE_ENV === 'production',
    sameSite: 'strict',
    maxAge: 1000 * 60 * 60 * 24 * 7 // 7 days
  }
}));
```

**Checklist:**
- [ ] Sessions stored in Redis (not in-memory)
- [ ] httpOnly flag set on cookies
- [ ] secure flag set in production
- [ ] sameSite attribute configured
- [ ] Session timeout implemented
- [ ] Session regeneration after login
- [ ] Session destruction on logout
- [ ] Custom session name (not default)

---

## 4. Rate Limiting & DDoS Protection

**Implementation:**
```javascript
const rateLimit = require('express-rate-limit');
const RedisStore = require('rate-limit-redis');
const redis = require('redis');

const redisClient = redis.createClient({
  host: process.env.REDIS_HOST,
  port: process.env.REDIS_PORT
});

// General API rate limiter
const apiLimiter = rateLimit({
  store: new RedisStore({ client: redisClient }),
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 100, // 100 requests per window
  message: 'Too many requests, please try again later',
  standardHeaders: true,
  legacyHeaders: false
});

// Strict limiter for auth endpoints
const authLimiter = rateLimit({
  store: new RedisStore({ client: redisClient }),
  windowMs: 15 * 60 * 1000,
  max: 5, // 5 attempts per 15 minutes
  skipSuccessfulRequests: true
});

// Payment limiter
const paymentLimiter = rateLimit({
  windowMs: 60 * 60 * 1000, // 1 hour
  max: 10
});

app.use('/api/', apiLimiter);
app.use('/auth/login', authLimiter);
app.use('/auth/register', authLimiter);
app.use('/payments/', paymentLimiter);
```

**Checklist:**
- [ ] Rate limiting implemented (express-rate-limit)
- [ ] Redis store for distributed rate limiting
- [ ] Different limits for different endpoints
- [ ] Stricter limits for sensitive endpoints (auth, payment)
- [ ] Rate limit headers returned
- [ ] Account lockout after failed login attempts (5 attempts)
- [ ] IP-based and user-based rate limiting

---

## 5. Data Protection & Privacy

### ✅ Encryption

**Implementation:**
```javascript
const crypto = require('crypto');

const ALGORITHM = 'aes-256-gcm';
const KEY = Buffer.from(process.env.ENCRYPTION_KEY, 'hex'); // 32 bytes

function encrypt(text) {
  const iv = crypto.randomBytes(16);
  const cipher = crypto.createCipheriv(ALGORITHM, KEY, iv);
  
  let encrypted = cipher.update(text, 'utf8', 'hex');
  encrypted += cipher.final('hex');
  
  const authTag = cipher.getAuthTag();
  
  return {
    encrypted,
    iv: iv.toString('hex'),
    authTag: authTag.toString('hex')
  };
}

function decrypt(encrypted, iv, authTag) {
  const decipher = crypto.createDecipheriv(
    ALGORITHM, 
    KEY, 
    Buffer.from(iv, 'hex')
  );
  
  decipher.setAuthTag(Buffer.from(authTag, 'hex'));
  
  let decrypted = decipher.update(encrypted, 'hex', 'utf8');
  decrypted += decipher.final('utf8');
  
  return decrypted;
}
```

**Checklist:**
- [ ] Sensitive data encrypted at rest (credit cards, SSN)
- [ ] TLS/HTTPS enforced for all connections
- [ ] Strong encryption algorithms (AES-256)
- [ ] Encryption keys stored securely (AWS KMS, Vault)
- [ ] Database encryption enabled (RDS encryption)
- [ ] Backup encryption enabled
- [ ] No sensitive data in logs

---

### ✅ PII (Personally Identifiable Information) Protection

**Checklist:**
- [ ] PII minimization (collect only necessary data)
- [ ] PII encrypted in database
- [ ] PII masked in logs
- [ ] Right to deletion implemented (GDPR)
- [ ] Data export functionality (GDPR)
- [ ] Privacy policy published
- [ ] Cookie consent implemented
- [ ] Data retention policy enforced

---

## 6. Payment Security

### ✅ Stripe Integration Security

**Implementation:**
```javascript
const stripe = require('stripe')(process.env.STRIPE_SECRET_KEY);

// Create payment intent
async function createPaymentIntent(amount, currency, customerId) {
  try {
    const paymentIntent = await stripe.paymentIntents.create({
      amount: Math.round(amount * 100), // Convert to cents
      currency: currency.toLowerCase(),
      customer: customerId,
      metadata: { integration_check: 'accept_a_payment' }
    });
    
    return {
      clientSecret: paymentIntent.client_secret,
      paymentIntentId: paymentIntent.id
    };
  } catch (error) {
    throw new Error('Payment intent creation failed');
  }
}

// Webhook handler
app.post('/webhooks/stripe', 
  express.raw({ type: 'application/json' }),
  async (req, res) => {
    const sig = req.headers['stripe-signature'];
    
    try {
      const event = stripe.webhooks.constructEvent(
        req.body,
        sig,
        process.env.STRIPE_WEBHOOK_SECRET
      );
      
      switch (event.type) {
        case 'payment_intent.succeeded':
          await handlePaymentSuccess(event.data.object);
          break;
        case 'payment_intent.payment_failed':
          await handlePaymentFailure(event.data.object);
          break;
      }
      
      res.json({ received: true });
    } catch (err) {
      return res.status(400).send(`Webhook Error: ${err.message}`);
    }
  }
);
```

**Checklist:**
- [ ] Never store credit card details
- [ ] Stripe.js for PCI compliance
- [ ] Payment processing server-side only
- [ ] Webhook signature verification
- [ ] Idempotency keys for payment requests
- [ ] Amount validation before charge
- [ ] Refund functionality implemented
- [ ] Payment logging and audit trail
- [ ] Test mode keys never in production

---

## 7. API Security

**Checklist:**
- [ ] HTTPS only (redirect HTTP to HTTPS)
- [ ] API versioning implemented
- [ ] CORS properly configured
- [ ] Request size limits enforced
- [ ] JSON parsing limits set
- [ ] URL encoding validated
- [ ] API keys rotated regularly
- [ ] No sensitive data in URLs
- [ ] Proper HTTP methods used (GET, POST, PUT, DELETE)
- [ ] Error messages don't leak sensitive info

---

## 8. File Upload Security

**Implementation:**
```javascript
const multer = require('multer');
const path = require('path');

const storage = multer.diskStorage({
  destination: '/tmp/uploads',
  filename: (req, file, cb) => {
    const uniqueSuffix = Date.now() + '-' + Math.round(Math.random() * 1E9);
    cb(null, uniqueSuffix + path.extname(file.originalname));
  }
});

const upload = multer({
  storage,
  limits: {
    fileSize: 5 * 1024 * 1024, // 5MB
    files: 5
  },
  fileFilter: (req, file, cb) => {
    const allowedTypes = ['image/jpeg', 'image/png', 'image/gif'];
    
    if (!allowedTypes.includes(file.mimetype)) {
      return cb(new Error('Invalid file type'), false);
    }
    
    cb(null, true);
  }
});
```

**Checklist:**
- [ ] File type validation (whitelist)
- [ ] File size limits enforced
- [ ] Filename sanitization
- [ ] Files stored outside webroot
- [ ] Virus scanning integration
- [ ] Image processing to strip metadata
- [ ] CDN for file delivery
- [ ] Access control on uploaded files

---

## 9. Error Handling & Logging

**Implementation:**
```javascript
const winston = require('winston');

// Logger configuration
const logger = winston.createLogger({
  level: 'info',
  format: winston.format.combine(
    winston.format.timestamp(),
    winston.format.errors({ stack: true }),
    winston.format.json()
  ),
  transports: [
    new winston.transports.File({ filename: 'error.log', level: 'error' }),
    new winston.transports.File({ filename: 'combined.log' })
  ]
});

// Global error handler
app.use((err, req, res, next) => {
  // Log error
  logger.error({
    message: err.message,
    stack: err.stack,
    url: req.url,
    method: req.method,
    ip: req.ip,
    userId: req.user?.id
  });
  
  // Send generic error to client (no stack traces)
  if (process.env.NODE_ENV === 'production') {
    res.status(err.statusCode || 500).json({
      success: false,
      error: {
        message: 'An error occurred',
        code: err.code || 'INTERNAL_ERROR'
      }
    });
  } else {
    res.status(err.statusCode || 500).json({
      success: false,
      error: {
        message: err.message,
        stack: err.stack
      }
    });
  }
});
```

**Checklist:**
- [ ] Structured logging (Winston/Bunyan)
- [ ] No sensitive data in logs (passwords, tokens)
- [ ] Error stack traces only in development
- [ ] Generic error messages to users
- [ ] Detailed errors logged server-side
- [ ] Log rotation configured
- [ ] Centralized logging (CloudWatch, DataDog)
- [ ] Security event logging (failed logins, permission denials)
- [ ] Log monitoring and alerting

---

## 10. Dependency Security

**Checklist:**
- [ ] Regular dependency updates
- [ ] npm audit run regularly
- [ ] Snyk or Dependabot integration
- [ ] No known vulnerabilities in dependencies
- [ ] Package-lock.json committed
- [ ] Minimal dependency footprint
- [ ] Dependencies from trusted sources only

**Commands:**
```bash
# Check for vulnerabilities
npm audit

# Fix vulnerabilities
npm audit fix

# Check with Snyk
npx snyk test
```

---

## 11. Infrastructure Security

**Checklist:**
- [ ] Firewall configured (security groups)
- [ ] SSH access restricted (key-based only)
- [ ] Database not publicly accessible
- [ ] Least privilege IAM policies
- [ ] Regular security patches applied
- [ ] Separate environments (dev, staging, prod)
- [ ] VPC properly configured
- [ ] Secrets in AWS Secrets Manager/Parameter Store
- [ ] Regular backups configured
- [ ] Disaster recovery plan documented

---

## 12. Monitoring & Incident Response

**Checklist:**
- [ ] Security monitoring dashboard
- [ ] Failed login attempt alerts
- [ ] Unusual traffic pattern detection
- [ ] Payment failure alerts
- [ ] Error rate monitoring
- [ ] Incident response plan documented
- [ ] Security contact email published
- [ ] Bug bounty program (optional)

---

## Security Testing Checklist

- [ ] OWASP ZAP security scan
- [ ] Penetration testing conducted
- [ ] SQL injection testing
- [ ] XSS testing
- [ ] CSRF testing
- [ ] Authentication bypass testing
- [ ] Authorization testing
- [ ] Session management testing
- [ ] Rate limiting testing
- [ ] File upload vulnerabilities testing

---

## Pre-Production Security Audit

Before going live, verify:
- [ ] All environment variables set
- [ ] Secrets rotated from dev/staging
- [ ] HTTPS enforced
- [ ] Security headers configured
- [ ] Rate limiting enabled
- [ ] Logging enabled
- [ ] Monitoring alerts configured
- [ ] Backup strategy tested
- [ ] Disaster recovery plan ready
- [ ] Security documentation updated
