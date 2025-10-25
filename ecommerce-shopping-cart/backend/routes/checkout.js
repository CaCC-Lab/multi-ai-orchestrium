const express = require('express');
const { 
  createOrderFromCart,
  processCheckoutPayment,
  createCheckoutPaymentIntent,
  getCheckoutSummary
} = require('../controllers/checkoutController');
const { protect } = require('../middleware/authMiddleware');

const router = express.Router();

router.route('/create-order').post(protect, createOrderFromCart);
router.route('/process-payment').post(protect, processCheckoutPayment);
router.route('/create-payment-intent').post(protect, createCheckoutPaymentIntent);
router.route('/summary').get(protect, getCheckoutSummary);

module.exports = router;