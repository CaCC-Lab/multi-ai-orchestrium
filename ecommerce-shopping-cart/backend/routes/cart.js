const express = require('express');
const { getCart, addToCart, updateCart, removeFromCart, clearCart } = require('../controllers/cart');
const { protect } = require('../middleware/auth');

const router = express.Router();

router.route('/')
  .get(protect, getCart)
  .post(protect, addToCart)
  .put(protect, updateCart)
  .delete(protect, clearCart);

router.route('/:id')
  .put(protect, updateCart)
  .delete(protect, removeFromCart);

module.exports = router;