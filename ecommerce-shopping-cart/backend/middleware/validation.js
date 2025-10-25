const { body, validationResult } = require('express-validator');

// Validation middleware for registration
const registerValidationRules = () => {
  return [
    body('name')
      .trim()
      .not()
      .isEmpty()
      .withMessage('Name is required')
      .isLength({ min: 2, max: 50 })
      .withMessage('Name must be between 2 and 50 characters long')
      .matches(/^[a-zA-Z\s]+$/)
      .withMessage('Name must contain only letters and spaces'),
    body('email')
      .trim()
      .isEmail()
      .withMessage('Please provide a valid email')
      .normalizeEmail()
      .isLength({ max: 100 })
      .withMessage('Email must be less than 100 characters'),
    body('password')
      .isLength({ min: 6, max: 128 })
      .withMessage('Password must be at least 6 characters long')
      .matches(/^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[@$!%*?&])[A-Za-z\d@$!%*?&]/)
      .withMessage('Password must contain at least one uppercase letter, one lowercase letter, one number, and one special character'),
  ];
};

// Validation middleware for login
const loginValidationRules = () => {
  return [
    body('email')
      .trim()
      .isEmail()
      .withMessage('Please provide a valid email')
      .normalizeEmail(),
    body('password')
      .exists()
      .withMessage('Password is required')
      .isLength({ min: 6 })
      .withMessage('Password must be at least 6 characters long'),
  ];
};

// Validation middleware for product creation/update
const productValidationRules = () => {
  return [
    body('name')
      .trim()
      .not()
      .isEmpty()
      .withMessage('Product name is required')
      .isLength({ max: 200 })
      .withMessage('Product name must be less than 200 characters'),
    body('description')
      .trim()
      .not()
      .isEmpty()
      .withMessage('Product description is required')
      .isLength({ max: 2000 })
      .withMessage('Product description must be less than 2000 characters'),
    body('price')
      .isFloat({ min: 0 })
      .withMessage('Price must be a positive number'),
    body('category')
      .trim()
      .not()
      .isEmpty()
      .withMessage('Category is required'),
    body('countInStock')
      .isInt({ min: 0 })
      .withMessage('Count in stock must be a non-negative integer')
  ];
};

// Validation middleware for order creation
const orderValidationRules = () => {
  return [
    body('orderItems')
      .isArray({ min: 1 })
      .withMessage('Order must contain at least one item'),
    body('shippingAddress')
      .isObject()
      .withMessage('Shipping address must be an object'),
    body('paymentMethod')
      .trim()
      .not()
      .isEmpty()
      .withMessage('Payment method is required')
  ];
};

// Validation middleware for cart operations
const cartValidationRules = () => {
  return [
    body('productId')
      .isInt({ min: 1 })
      .withMessage('Valid product ID is required'),
    body('qty')
      .isInt({ min: 1 })
      .withMessage('Quantity must be at least 1')
  ];
};

module.exports = {
  registerValidationRules,
  loginValidationRules,
  productValidationRules,
  orderValidationRules,
  cartValidationRules,
  validationResult
};