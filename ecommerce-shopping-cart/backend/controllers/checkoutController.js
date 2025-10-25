const Order = require('../models/Order');
const Product = require('../models/Product');
const Cart = require('../models/Cart');
const stripe = require('stripe')(process.env.STRIPE_API_KEY);
const { convertPrice, getSupportedCurrencies } = require('../utils/currencies');

// @desc    Create new order from cart
// @route   POST /api/checkout/create-order
// @access  Private
exports.createOrderFromCart = async (req, res) => {
  try {
    const { shippingAddress, paymentMethod, currency = 'USD' } = req.body;

    // Validate currency
    const supportedCurrencies = getSupportedCurrencies();
    if (!supportedCurrencies.includes(currency)) {
      return res.status(400).json({ message: 'Invalid currency' });
    }

    // Get user's cart
    const cart = await Cart.findOne({ where: { userId: req.user.id } });

    if (!cart || cart.items.length === 0) {
      return res.status(400).json({ message: 'Cart is empty' });
    }

    // If cart currency is different from requested currency, convert prices
    let orderItems = cart.items;
    let itemsPrice = cart.totalPrice;
    
    if (cart.currency !== currency) {
      // This would require converting all prices in cart items to requested currency
      // For now, we'll use the cart's currency and update it for consistency
      orderItems = cart.items.map(item => {
        // Convert if needed, but for now we'll maintain cart values
        return item;
      });
      
      // Update cart currency for consistency
      cart.currency = currency;
      await cart.save();
    }

    // Calculate prices in cart currency
    itemsPrice = cart.totalPrice;
    const shippingPrice = 15.00; // Fixed shipping for now
    const taxPrice = Number((0.15 * itemsPrice).toFixed(2)); // 15% tax
    const totalPrice = itemsPrice + shippingPrice + taxPrice;

    // Verify quantities and reduce stock
    for (const item of cart.items) {
      const product = await Product.findByPk(item.product.id);
      if (!product) {
        return res.status(404).json({ message: `Product not found: ${item.product.id}` });
      }
      if (product.countInStock < item.qty) {
        return res.status(400).json({ message: `Not enough stock for ${product.name}` });
      }
      // Update product stock
      product.countInStock -= item.qty;
      await product.save();
    }

    // Create order
    const order = await Order.create({
      orderItems: cart.items,
      shippingAddress,
      paymentMethod,
      taxPrice,
      shippingPrice,
      totalPrice,
      currency: currency,
      userId: req.user.id
    });

    // Clear user's cart after order creation
    cart.items = [];
    cart.totalItems = 0;
    cart.totalPrice = 0.00;
    cart.currency = currency;  // Maintain currency for future cart use
    await cart.save();

    res.status(201).json({
      id: order.id,
      orderItems: order.orderItems,
      shippingAddress: order.shippingAddress,
      paymentMethod: order.paymentMethod,
      taxPrice: order.taxPrice,
      shippingPrice: order.shippingPrice,
      totalPrice: order.totalPrice,
      currency: order.currency,
      isPaid: order.isPaid,
      paidAt: order.paidAt,
      isDelivered: order.isDelivered,
      deliveredAt: order.deliveredAt,
      createdAt: order.createdAt,
      user: req.user.id
    });
  } catch (error) {
    console.error(error);
    res.status(500).json({ message: 'Server error' });
  }
};

// @desc    Process checkout payment
// @route   POST /api/checkout/process-payment
// @access  Private
exports.processCheckoutPayment = async (req, res) => {
  try {
    const { orderAmount, currency = 'usd', paymentMethodId } = req.body;

    // Convert amount to smallest currency unit (e.g., cents for USD)
    const convertedAmount = Math.round(orderAmount * 100);

    // Create a PaymentIntent with the order amount and currency
    const paymentIntent = await stripe.paymentIntents.create({
      amount: convertedAmount,
      currency: currency,
      payment_method: paymentMethodId,
      confirmation_method: 'manual',
      confirm: true,
      metadata: {
        userId: req.user.id,
        orderDescription: 'E-commerce purchase'
      }
    });

    if (paymentIntent.status === 'succeeded') {
      // Update the order as paid
      const order = await Order.findOne({
        where: {
          userId: req.user.id,
          totalPrice: orderAmount,
          isPaid: false
        },
        order: [['createdAt', 'DESC']], // Get the most recent unpaid order
        limit: 1
      });

      if (order) {
        order.isPaid = true;
        order.paidAt = new Date();
        order.paymentResult = {
          id: paymentIntent.id,
          status: paymentIntent.status,
          update_time: new Date().toISOString(),
          email_address: req.user.email,
        };
        await order.save();
      }

      res.json({
        success: true,
        paymentIntentId: paymentIntent.id,
        status: paymentIntent.status,
        order: order ? order.id : null
      });
    } else {
      res.status(400).json({
        success: false,
        message: 'Payment failed',
        status: paymentIntent.status
      });
    }
  } catch (error) {
    console.error(error);
    res.status(500).json({ 
      success: false,
      message: error.message 
    });
  }
};

// @desc    Create payment intent for checkout
// @route   POST /api/checkout/create-payment-intent
// @access  Private
exports.createCheckoutPaymentIntent = async (req, res) => {
  try {
    const { amount, currency = 'usd' } = req.body;

    // Convert amount to smallest currency unit (e.g., cents for USD)
    const convertedAmount = Math.round(amount * 100);

    const paymentIntent = await stripe.paymentIntents.create({
      amount: convertedAmount,
      currency: currency,
      metadata: {
        userId: req.user.id
      }
    });

    res.json({
      client_secret: paymentIntent.client_secret,
      id: paymentIntent.id
    });
  } catch (error) {
    console.error(error);
    res.status(500).json({ 
      success: false,
      message: error.message 
    });
  }
};

// @desc    Get checkout summary
// @route   GET /api/checkout/summary
// @access  Private
exports.getCheckoutSummary = async (req, res) => {
  try {
    const cart = await Cart.findOne({ where: { userId: req.user.id } });

    if (!cart) {
      return res.status(404).json({ message: 'Cart not found' });
    }

    const itemsPrice = cart.totalPrice;
    const shippingPrice = 15.00; // Fixed shipping for now
    const taxPrice = Number((0.15 * itemsPrice).toFixed(2)); // 15% tax
    const totalPrice = itemsPrice + shippingPrice + taxPrice;

    res.json({
      itemsPrice,
      shippingPrice,
      taxPrice,
      totalPrice,
      items: cart.items,
      currency: cart.currency
    });
  } catch (error) {
    console.error(error);
    res.status(500).json({ message: 'Server error' });
  }
};