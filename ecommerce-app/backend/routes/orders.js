const express = require('express');
const { getUserOrders, getOrderById, getOrderTracking, cancelOrder } = require('../controllers/orderController');
const { auth } = require('../middleware/auth');

const router = express.Router();

// @route   GET api/orders
// @desc    Get user's order history
// @access  Private
router.get('/', auth, getUserOrders);

// @route   GET api/orders/:orderId
// @desc    Get a specific order by ID
// @access  Private
router.get('/:orderId', auth, getOrderById);

// @route   GET api/orders/:orderId/tracking
// @desc    Get order tracking information
// @access  Private
router.get('/:orderId/tracking', auth, getOrderTracking);

// @route   PUT api/orders/:orderId/cancel
// @desc    Cancel an order
// @access  Private
router.put('/:orderId/cancel', auth, cancelOrder);

module.exports = router;