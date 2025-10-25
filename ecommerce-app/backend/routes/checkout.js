const express = require('express');
const { processCheckout, confirmPayment, handleWebhook } = require('../controllers/checkoutController');
const { auth } = require('../middleware/auth');

const router = express.Router();

// @route   POST api/checkout/process
// @desc    Process checkout and create order
// @access  Private
router.post('/process', auth, processCheckout);

// @route   POST api/checkout/confirm
// @desc    Confirm payment
// @access  Private
router.post('/confirm', auth, confirmPayment);

// @route   POST api/checkout/webhook
// @desc    Handle Stripe webhook
// @access  Public (but secured via webhook signature)
router.post('/webhook', express.raw({type: 'application/json'}), handleWebhook);

module.exports = router;