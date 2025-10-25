const express = require('express');
const { 
  getAllProducts, 
  getProductById, 
  createProduct, 
  updateProduct, 
  deleteProduct, 
  getAdminStats 
} = require('../controllers/adminController');
const { adminAuth } = require('../middleware/auth');
const { 
  validateProduct,
  handleValidationErrors 
} = require('../middleware/security');

const router = express.Router();

// @route   GET api/admin/products
// @desc    Get all products (admin only)
// @access  Private/Admin
router.get('/products', adminAuth, getAllProducts);

// @route   GET api/admin/products/:id
// @desc    Get a single product by ID (admin only)
// @access  Private/Admin
router.get('/products/:id', adminAuth, getProductById);

// @route   POST api/admin/products
// @desc    Create a new product (admin only)
// @access  Private/Admin
router.post('/products', adminAuth, validateProduct, handleValidationErrors, createProduct);

// @route   PUT api/admin/products/:id
// @desc    Update a product by ID (admin only)
// @access  Private/Admin
router.put('/products/:id', adminAuth, validateProduct, handleValidationErrors, updateProduct);

// @route   DELETE api/admin/products/:id
// @desc    Delete a product by ID (admin only)
// @access  Private/Admin
router.delete('/products/:id', adminAuth, deleteProduct);

// @route   GET api/admin/stats
// @desc    Get admin dashboard stats
// @access  Private/Admin
router.get('/stats', adminAuth, getAdminStats);

module.exports = router;