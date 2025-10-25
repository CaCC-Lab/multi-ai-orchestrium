const express = require('express');
const cors = require('cors');
const compression = require('compression');
const swaggerUi = require('swagger-ui-express');
const dotenv = require('dotenv');
const swaggerSpecs = require('./utils/swagger');
const {
  limiter,
  securityHeaders,
  noSqlSanitize,
  xssSanitize,
  sanitizeInput
} = require('./middleware/security');

// Load environment variables
dotenv.config();

const app = express();

// Performance optimization middleware
app.use(compression()); // Compress all responses

// Security middleware (in order of importance)
app.use(limiter); // Rate limiting should be first
app.use(securityHeaders); // Security headers
app.use(cors({
  origin: process.env.FRONTEND_URL || 'http://localhost:3000',
  credentials: true
}));

// Data sanitization
app.use(noSqlSanitize); // NoSQL injection protection
app.use(xssSanitize); // XSS protection

// Body parsing middleware (skip Stripe webhook to preserve raw body)
const jsonParser = express.json({ limit: '10mb' });
const urlencodedParser = express.urlencoded({ extended: true });

app.use((req, res, next) => {
  if (req.originalUrl === '/api/checkout/webhook') {
    return next();
  }
  return jsonParser(req, res, next);
});

app.use((req, res, next) => {
  if (req.originalUrl === '/api/checkout/webhook') {
    return next();
  }
  return urlencodedParser(req, res, next);
});

app.use((req, res, next) => {
  if (req.originalUrl === '/api/checkout/webhook') {
    return next();
  }
  return sanitizeInput(req, res, next);
}); // Custom input sanitization

// Swagger UI
app.use('/api-docs', swaggerUi.serve, swaggerUi.setup(swaggerSpecs));

// Import routes
const authRoutes = require('./routes/auth');
const productRoutes = require('./routes/products');
const cartRoutes = require('./routes/cart');
const checkoutRoutes = require('./routes/checkout');
const orderRoutes = require('./routes/orders');
const adminRoutes = require('./routes/admin');
const inventoryRoutes = require('./routes/inventory');
const notificationRoutes = require('./routes/notifications');

// API routes
app.use('/api/auth', authRoutes);
app.use('/api/products', productRoutes);
app.use('/api/cart', cartRoutes);
app.use('/api/checkout', checkoutRoutes);
app.use('/api/orders', orderRoutes);
app.use('/api/admin', adminRoutes);
app.use('/api/inventory', inventoryRoutes);
app.use('/api/notifications', notificationRoutes);

// Health check route
app.get('/api/health', (req, res) => {
  res.status(200).json({ message: 'Server is running', timestamp: new Date() });
});

// Handle 404
app.use((req, res) => {
  res.status(404).json({ message: 'Route not found' });
});

// Error handling middleware
app.use((err, req, res, next) => {
  console.error(err.stack);
  res.status(500).json({ message: 'Something went wrong!' });
});

module.exports = app;