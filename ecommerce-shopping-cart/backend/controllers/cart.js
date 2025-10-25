const Cart = require('../models/Cart');
const Product = require('../models/Product');
const { Op } = require('sequelize');

// @desc      Get cart items for a user
// @route     GET /api/v1/cart
// @access    Private
exports.getCart = async (req, res) => {
  try {
    const cartItems = await Cart.findAll({
      where: { userId: req.user.id },
      include: [{ model: Product }]
    });

    // Calculate total
    let total = 0;
    cartItems.forEach(item => {
      total += parseFloat(item.priceAtTime) * item.quantity;
    });

    res.status(200).json({
      success: true,
      count: cartItems.length,
      total: total.toFixed(2),
      data: cartItems
    });
  } catch (error) {
    res.status(500).json({ success: false, error: error.message });
  }
};

// @desc      Add item to cart
// @route     POST /api/v1/cart
// @access    Private
exports.addToCart = async (req, res) => {
  try {
    const { productId, quantity } = req.body;
    
    // Check if product exists and is in stock
    const product = await Product.findByPk(productId);
    
    if (!product) {
      return res.status(404).json({ success: false, error: 'Product not found' });
    }
    
    if (product.inventory < quantity) {
      return res.status(400).json({ success: false, error: 'Not enough inventory available' });
    }
    
    // Check if item already exists in cart
    let cartItem = await Cart.findOne({
      where: {
        userId: req.user.id,
        productId: productId
      }
    });
    
    if (cartItem) {
      // Update quantity
      cartItem.quantity += quantity;
      await cartItem.save();
    } else {
      // Create new cart item
      cartItem = await Cart.create({
        userId: req.user.id,
        productId: productId,
        quantity: quantity,
        priceAtTime: product.price
      });
    }

    res.status(200).json({
      success: true,
      data: cartItem
    });
  } catch (error) {
    res.status(400).json({ success: false, error: error.message });
  }
};

// @desc      Update cart item quantity
// @route     PUT /api/v1/cart/:id
// @access    Private
exports.updateCart = async (req, res) => {
  try {
    const { quantity } = req.body;
    
    if (quantity <= 0) {
      return res.status(400).json({ success: false, error: 'Quantity must be greater than 0' });
    }
    
    const cartItem = await Cart.findOne({
      where: {
        id: req.params.id,
        userId: req.user.id
      }
    });
    
    if (!cartItem) {
      return res.status(404).json({ success: false, error: 'Cart item not found' });
    }
    
    // Check product inventory
    const product = await Product.findByPk(cartItem.productId);
    if (product.inventory < quantity) {
      return res.status(400).json({ success: false, error: 'Not enough inventory available' });
    }
    
    cartItem.quantity = quantity;
    await cartItem.save();

    res.status(200).json({
      success: true,
      data: cartItem
    });
  } catch (error) {
    res.status(400).json({ success: false, error: error.message });
  }
};

// @desc      Remove item from cart
// @route     DELETE /api/v1/cart/:id
// @access    Private
exports.removeFromCart = async (req, res) => {
  try {
    const cartItem = await Cart.findOne({
      where: {
        id: req.params.id,
        userId: req.user.id
      }
    });
    
    if (!cartItem) {
      return res.status(404).json({ success: false, error: 'Cart item not found' });
    }
    
    await cartItem.destroy();

    res.status(200).json({
      success: true,
      data: {}
    });
  } catch (error) {
    res.status(500).json({ success: false, error: error.message });
  }
};

// @desc      Clear user's cart
// @route     DELETE /api/v1/cart
// @access    Private
exports.clearCart = async (req, res) => {
  try {
    await Cart.destroy({
      where: { userId: req.user.id }
    });

    res.status(200).json({
      success: true,
      data: {}
    });
  } catch (error) {
    res.status(500).json({ success: false, error: error.message });
  }
};