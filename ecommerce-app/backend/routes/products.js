const express = require('express');
const { 
  getProducts, 
  getProductById, 
  getSupportedCurrencies, 
  getCategories, 
  getBrands 
} = require('../controllers/productController');
const { adminAuth } = require('../middleware/auth');
const { 
  validateProduct,
  handleValidationErrors 
} = require('../middleware/security');

const router = express.Router();

// @route   GET api/products/currencies
// @desc    Get supported currencies
// @access  Public
router.get('/currencies', getSupportedCurrencies);

// @route   GET api/products/categories
// @desc    Get all product categories
// @access  Public
router.get('/categories', getCategories);

// @route   GET api/products/brands
// @desc    Get all product brands
// @access  Public
router.get('/brands', getBrands);

// @route   GET api/products
// @desc    Get all products with search and filters
// @access  Public
router.get('/', getProducts);

// @route   GET api/products/:id
// @desc    Get a single product by ID
// @access  Public
router.get('/:id', getProductById);

module.exports = router;