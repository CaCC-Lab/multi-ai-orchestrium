const express = require('express');
const { addToCart, getUserCart, updateCartItem, removeCartItem, clearCart } = require('../controllers/cartController');
const { auth } = require('../middleware/auth');

const router = express.Router();

// @route   POST api/cart/add
// @desc    Add item to cart
// @access  Private
router.post('/add', auth, addToCart);

// @route   GET api/cart
// @desc    Get user's cart
// @access  Private
router.get('/', auth, getUserCart);

// @route   PUT api/cart/:cartItemId
// @desc    Update cart item quantity
// @access  Private
router.put('/:cartItemId', auth, updateCartItem);

// @route   DELETE api/cart/:cartItemId
// @desc    Remove item from cart
// @access  Private
router.delete('/:cartItemId', auth, removeCartItem);

// @route   DELETE api/cart/clear
// @desc    Clear user's cart
// @access  Private
router.delete('/clear', auth, clearCart);

module.exports = router;