const { Cart, Product, User } = require('../models');
const { Op } = require('sequelize');
const { convertCurrency, SUPPORTED_CURRENCIES } = require('../utils/currency');

// Add item to cart
const addToCart = async (req, res) => {
  try {
    const { productId, quantity = 1, currency = 'USD' } = req.body;
    const userId = req.user.id;

    // Validate currency
    if (currency && !SUPPORTED_CURRENCIES.includes(currency)) {
      return res.status(400).json({ message: `Unsupported currency: ${currency}` });
    }

    // Validate product exists and is active
    const product = await Product.findByPk(productId);
    if (!product || !product.isActive) {
      return res.status(404).json({ message: 'Product not found or inactive' });
    }

    // Check if product is in stock
    if (product.stockQuantity < quantity) {
      return res.status(400).json({ message: 'Insufficient stock for this product' });
    }

    // Convert price to the requested currency if needed
    let priceAtTime = parseFloat(product.price);
    if (currency && currency !== 'USD') {
      priceAtTime = convertCurrency(priceAtTime, 'USD', currency);
    }

    // Check if item already exists in cart
    let cartItem = await Cart.findOne({
      where: {
        userId,
        productId
      }
    });

    if (cartItem) {
      // Update quantity if item already exists
      const newQuantity = cartItem.quantity + parseInt(quantity);
      
      // Check if new quantity exceeds stock
      if (product.stockQuantity < newQuantity) {
        return res.status(400).json({ message: 'Insufficient stock for requested quantity' });
      }
      
      cartItem = await cartItem.update({ 
        quantity: newQuantity,
        currency // Update currency if different
      });
    } else {
      // Create new cart item
      cartItem = await Cart.create({
        userId,
        productId,
        quantity: parseInt(quantity),
        priceAtTime, // Store the price at the time of adding to cart in requested currency
        currency
      });
    }

    res.status(200).json({
      success: true,
      message: 'Item added to cart successfully',
      cartItem
    });
  } catch (error) {
    res.status(500).json({ message: 'Server error', error: error.message });
  }
};

// Get user's cart
const getUserCart = async (req, res) => {
  try {
    const userId = req.user.id;
    const { currency = 'USD' } = req.query;

    // Validate currency
    if (currency && !SUPPORTED_CURRENCIES.includes(currency)) {
      return res.status(400).json({ message: `Unsupported currency: ${currency}` });
    }

    // Get cart items with product details
    const cartItems = await Cart.findAll({
      where: { userId },
      include: [{
        model: Product,
        attributes: ['id', 'name', 'price', 'imageUrls', 'category', 'currency']
      }]
    });

    // Calculate totals
    let totalItems = 0;
    let totalPrice = 0;

    const cartWithDetails = cartItems.map(item => {
      // Convert price to requested currency if needed
      let itemPriceAtTime = parseFloat(item.priceAtTime);
      if (currency !== item.currency) {
        // Convert from stored currency to requested currency
        itemPriceAtTime = convertCurrency(parseFloat(item.priceAtTime), item.currency, currency);
      }
      
      const itemTotal = itemPriceAtTime * item.quantity;
      totalItems += item.quantity;
      totalPrice += itemTotal;

      return {
        id: item.id,
        productId: item.productId,
        product: item.Product,
        quantity: item.quantity,
        priceAtTime: parseFloat(itemPriceAtTime.toFixed(2)),
        currency,
        itemTotal: parseFloat(itemTotal.toFixed(2))
      };
    });

    res.status(200).json({
      success: true,
      totalItems,
      totalPrice: parseFloat(totalPrice.toFixed(2)),
      currency,
      cartItems: cartWithDetails
    });
  } catch (error) {
    res.status(500).json({ message: 'Server error', error: error.message });
  }
};

// Update cart item quantity
const updateCartItem = async (req, res) => {
  try {
    const { cartItemId } = req.params;
    const { quantity } = req.body;
    const userId = req.user.id;

    // Validate quantity
    if (quantity < 1) {
      return res.status(400).json({ message: 'Quantity must be at least 1' });
    }

    // Get cart item
    const cartItem = await Cart.findByPk(cartItemId);
    if (!cartItem || cartItem.userId !== userId) {
      return res.status(404).json({ message: 'Cart item not found or does not belong to user' });
    }

    // Get product to check stock
    const product = await Product.findByPk(cartItem.productId);
    if (!product) {
      return res.status(404).json({ message: 'Product associated with cart item not found' });
    }

    // Check if requested quantity is available in stock
    if (product.stockQuantity < quantity) {
      return res.status(400).json({ message: 'Insufficient stock for requested quantity' });
    }

    // Update quantity
    await cartItem.update({ quantity });

    res.status(200).json({
      success: true,
      message: 'Cart item updated successfully',
      cartItem: {
        ...cartItem.toJSON(),
        quantity
      }
    });
  } catch (error) {
    res.status(500).json({ message: 'Server error', error: error.message });
  }
};

// Remove item from cart
const removeCartItem = async (req, res) => {
  try {
    const { cartItemId } = req.params;
    const userId = req.user.id;

    // Get cart item to check ownership
    const cartItem = await Cart.findByPk(cartItemId);
    if (!cartItem || cartItem.userId !== userId) {
      return res.status(404).json({ message: 'Cart item not found or does not belong to user' });
    }

    // Delete cart item
    await cartItem.destroy();

    res.status(200).json({
      success: true,
      message: 'Item removed from cart successfully'
    });
  } catch (error) {
    res.status(500).json({ message: 'Server error', error: error.message });
  }
};

// Clear user's cart
const clearCart = async (req, res) => {
  try {
    const userId = req.user.id;

    // Remove all items from user's cart
    await Cart.destroy({
      where: { userId }
    });

    res.status(200).json({
      success: true,
      message: 'Cart cleared successfully'
    });
  } catch (error) {
    res.status(500).json({ message: 'Server error', error: error.message });
  }
};

module.exports = {
  addToCart,
  getUserCart,
  updateCartItem,
  removeCartItem,
  clearCart
};