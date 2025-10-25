const express = require('express');
const { 
  sendOrderConfirmationEmail, 
  sendOrderStatusUpdateEmail,
  triggerLowStockNotification,
  triggerOutOfStockNotification
} = require('../controllers/notificationController');
const { auth, adminAuth } = require('../middleware/auth');

const router = express.Router();

// @route   POST api/notifications/order/:orderId/confirmation
// @desc    Send order confirmation email
// @access  Private
router.post('/order/:orderId/confirmation', auth, sendOrderConfirmationEmail);

// @route   POST api/notifications/order/:orderId/status-update
// @desc    Send order status update email
// @access  Private
router.post('/order/:orderId/status-update', auth, sendOrderStatusUpdateEmail);

// @route   POST api/notifications/product/:productId/low-stock
// @desc    Trigger low stock notification for admin
// @access  Private/Admin
router.post('/product/:productId/low-stock', adminAuth, triggerLowStockNotification);

// @route   POST api/notifications/product/:productId/out-of-stock
// @desc    Trigger out of stock notification for admin
// @access  Private/Admin
router.post('/product/:productId/out-of-stock', adminAuth, triggerOutOfStockNotification);

module.exports = router;