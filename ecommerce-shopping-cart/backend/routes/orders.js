const express = require('express');
const { getOrders, getOrder, createOrder, updateOrder, deleteOrder, getUserOrders } = require('../controllers/orders');
const { protect, authorize } = require('../middleware/auth');

const router = express.Router();

router.route('/')
  .get(protect, authorize('admin'), getOrders)
  .post(protect, createOrder);

router.route('/myorders').get(protect, getUserOrders);

router.route('/:id')
  .get(protect, getOrder)
  .put(protect, authorize('admin'), updateOrder)
  .delete(protect, authorize('admin'), deleteOrder);

module.exports = router;