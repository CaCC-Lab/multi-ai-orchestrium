const rateLimit = require('express-rate-limit');
const xss = require('xss-clean');
const helmet = require('helmet');
const { body, validationResult } = require('express-validator');
const validator = require('validator');

// Rate limiting middleware
const limiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 100, // limit each IP to 100 requests per windowMs
  message: 'Too many requests from this IP, please try again later.',
  standardHeaders: true, // Return rate limit info in the `RateLimit-*` headers
  legacyHeaders: false, // Disable the `X-RateLimit-*` headers
  skip: () => process.env.NODE_ENV === 'test'
});

// Security headers middleware
const securityHeaders = helmet({
  contentSecurityPolicy: {
    directives: {
      defaultSrc: ["'self'"],
      styleSrc: ["'self'", "'unsafe-inline'"],
      scriptSrc: ["'self'"],
      imgSrc: ["'self'", "data:", "https:"],
      connectSrc: ["'self'", "https://api.stripe.com"],
    },
  },
  hsts: {
    maxAge: 31536000, // 1 year in seconds
    includeSubDomains: true,
    preload: true
  },
  referrerPolicy: {
    policy: 'no-referrer'
  },
  frameguard: {
    action: 'deny'
  }
});

// NoSQL injection protection
const sanitizeObject = (value) => {
  if (!value || typeof value !== 'object') {
    return;
  }

  if (Array.isArray(value)) {
    value.forEach(sanitizeObject);
    return;
  }

  Object.keys(value).forEach((key) => {
    if (key.startsWith('$') || key.includes('.$')) {
      delete value[key];
    } else {
      sanitizeObject(value[key]);
    }
  });
};

const noSqlSanitize = (req, res, next) => {
  ['body', 'query', 'params'].forEach((segment) => {
    if (req[segment]) {
      sanitizeObject(req[segment]);
    }
  });

  next();
};

// XSS protection
const xssSanitize = xss();

// Input validation middleware
const validateRegister = [
  body('firstName')
    .trim()
    .isLength({ min: 2, max: 30 })
    .withMessage('First name must be between 2 and 30 characters')
    .matches(/^[a-zA-Z\s]+$/)
    .withMessage('First name can only contain letters and spaces'),
  body('lastName')
    .trim()
    .isLength({ min: 2, max: 30 })
    .withMessage('Last name must be between 2 and 30 characters')
    .matches(/^[a-zA-Z\s]+$/)
    .withMessage('Last name can only contain letters and spaces'),
  body('email')
    .normalizeEmail()
    .isEmail()
    .withMessage('Please enter a valid email'),
  body('password')
    .isLength({ min: 6, max: 100 })
    .withMessage('Password must be at least 6 characters long'),
  body('phone')
    .optional()
    .isMobilePhone()
    .withMessage('Please enter a valid phone number')
];

const validateLogin = [
  body('email')
    .normalizeEmail()
    .isEmail()
    .withMessage('Please enter a valid email'),
  body('password')
    .exists()
    .withMessage('Password is required')
];

const validateProduct = [
  body('name')
    .trim()
    .isLength({ min: 2, max: 100 })
    .withMessage('Product name must be between 2 and 100 characters'),
  body('description')
    .optional()
    .trim()
    .isLength({ max: 1000 })
    .withMessage('Description must be less than 1000 characters'),
  body('price')
    .isFloat({ min: 0 })
    .withMessage('Price must be a positive number'),
  body('category')
    .trim()
    .isLength({ min: 1, max: 50 })
    .withMessage('Category is required and must be between 1 and 50 characters'),
  body('sku')
    .trim()
    .isLength({ min: 1, max: 50 })
    .withMessage('SKU is required and must be between 1 and 50 characters'),
  body('stockQuantity')
    .isInt({ min: 0 })
    .withMessage('Stock quantity must be a non-negative integer')
];

const validateAddress = [
  body('street')
    .trim()
    .isLength({ max: 100 })
    .withMessage('Street address is too long'),
  body('city')
    .trim()
    .isLength({ max: 50 })
    .withMessage('City name is too long'),
  body('state')
    .trim()
    .isLength({ max: 50 })
    .withMessage('State name is too long'),
  body('zip')
    .trim()
    .isLength({ max: 20 })
    .withMessage('ZIP code is too long'),
  body('country')
    .trim()
    .isLength({ max: 50 })
    .withMessage('Country name is too long')
];

// Validation result handler
const handleValidationErrors = (req, res, next) => {
  const errors = validationResult(req);
  if (!errors.isEmpty()) {
    return res.status(400).json({
      success: false,
      message: 'Validation error',
      errors: errors.array()
    });
  }
  next();
};

// Sanitize user input to prevent XSS
const sanitizeInput = (req, res, next) => {
  if (req.body) {
    // Sanitize each field in the body
    for (let key in req.body) {
      if (typeof req.body[key] === 'string') {
        req.body[key] = req.body[key].trim();
      }
    }
  }
  next();
};

module.exports = {
  limiter,
  securityHeaders,
  noSqlSanitize,
  xssSanitize,
  validateRegister,
  validateLogin,
  validateProduct,
  validateAddress,
  handleValidationErrors,
  sanitizeInput
};