const express = require('express');
const { 
  getProducts,
  createProduct,
  updateProduct,
  deleteProduct,
  getUsers,
  deleteUser,
  getUser,
  updateUser,
  getOrders,
  getOrder,
  updateOrder,
  deleteOrder,
  updateInventory,
  getInventoryLevels,
  getDashboardStats
} = require('../controllers/adminController');
const { protect, admin } = require('../middleware/authMiddleware');

const router = express.Router();

// Product routes
router.route('/products')
  .get(protect, admin, getProducts)
  .post(protect, admin, createProduct);

router.route('/products/:id')
  .put(protect, admin, updateProduct)
  .delete(protect, admin, deleteProduct);

router.route('/products/:id/inventory')
  .put(protect, admin, updateInventory);

// User routes
router.route('/users')
  .get(protect, admin, getUsers);

router.route('/users/:id')
  .get(protect, admin, getUser)
  .put(protect, admin, updateUser)
  .delete(protect, admin, deleteUser);

// Order routes
router.route('/orders')
  .get(protect, admin, getOrders);

router.route('/orders/:id')
  .get(protect, admin, getOrder)
  .put(protect, admin, updateOrder)
  .delete(protect, admin, deleteOrder);

// Inventory routes
router.route('/inventory')
  .get(protect, admin, getInventoryLevels);

// Dashboard routes
router.route('/dashboard')
  .get(protect, admin, getDashboardStats);

module.exports = router;