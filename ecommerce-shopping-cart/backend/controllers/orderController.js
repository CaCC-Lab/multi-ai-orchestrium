const stripe = require('stripe')(process.env.STRIPE_API_KEY);
const Order = require('../models/Order');
const Product = require('../models/Product');
const Cart = require('../models/Cart');
const User = require('../models/User');
const {
  sendOrderConfirmation,
  sendShippingNotification,
  sendDeliveryNotification,
  sendPaymentConfirmation
} = require('../utils/email');
const { convertPrice, getSupportedCurrencies } = require('../utils/currencies');

// @desc    Create new order
// @route   POST /api/orders
// @access  Private
exports.createOrder = async (req, res) => {
  try {
    const {
      orderItems,
      shippingAddress,
      paymentMethod,
      taxPrice,
      shippingPrice,
      totalPrice,
      currency = 'USD'  // Default to USD
    } = req.body;

    // Validate currency
    const supportedCurrencies = getSupportedCurrencies();
    if (!supportedCurrencies.includes(currency)) {
      return res.status(400).json({ message: 'Invalid currency' });
    }

    if (orderItems && orderItems.length === 0) {
      return res.status(400).json({ message: 'No order items' });
    }

    // Get user's cart to verify items
    const cart = await Cart.findOne({ where: { userId: req.user.id } });

    if (!cart || cart.items.length === 0) {
      return res.status(400).json({ message: 'Cart is empty' });
    }

    // For multi-currency orders, ensure all items are in the same currency
    for (const item of orderItems) {
      // Verify quantities and reduce stock
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
      orderItems,
      shippingAddress,
      paymentMethod,
      taxPrice,
      shippingPrice,
      totalPrice,
      currency,
      userId: req.user.id
    });

    // Clear user's cart after order creation
    cart.items = [];
    cart.totalItems = 0;
    cart.totalPrice = 0.00;
    cart.currency = currency;  // Maintain cart currency for future use
    await cart.save();

    // Get user to send confirmation email
    const user = await User.findByPk(req.user.id);

    // Send order confirmation email
    try {
      await sendOrderConfirmation(order, user);
    } catch (emailError) {
      console.error('Failed to send order confirmation email:', emailError);
      // Don't fail the order creation if email fails
    }

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

// @desc    Get order by ID
// @route   GET /api/orders/:id
// @access  Private
exports.getOrderById = async (req, res) => {
  try {
    const order = await Order.findByPk(req.params.id);

    if (order) {
      // Check if user owns this order or is admin
      if (order.userId.toString() !== req.user.id.toString() && !req.user.isAdmin) {
        return res.status(401).json({ message: 'Not authorized to access this order' });
      }
      
      res.json(order);
    } else {
      res.status(404).json({ message: 'Order not found' });
    }
  } catch (error) {
    console.error(error);
    res.status(500).json({ message: 'Server error' });
  }
};

// @desc    Update order to paid
// @route   PUT /api/orders/:id/pay
// @access  Private
exports.updateOrderToPaid = async (req, res) => {
  try {
    const order = await Order.findByPk(req.params.id);

    if (order) {
      order.isPaid = true;
      order.paidAt = Date.now();
      order.paymentResult = {
        id: req.body.id,
        status: req.body.status,
        update_time: req.body.update_time,
        email_address: req.body.payer.email_address,
      };

      const updatedOrder = await order.save();
      
      // Get user to send payment confirmation email
      const user = await User.findByPk(order.userId);

      // Send payment confirmation email
      try {
        await sendPaymentConfirmation(updatedOrder, user);
      } catch (emailError) {
        console.error('Failed to send payment confirmation email:', emailError);
        // Don't fail the payment update if email fails
      }
      
      res.json(updatedOrder);
    } else {
      res.status(404).json({ message: 'Order not found' });
    }
  } catch (error) {
    console.error(error);
    res.status(500).json({ message: 'Server error' });
  }
};

// @desc    Update order to delivered
// @route   PUT /api/orders/:id/deliver
// @access  Private/Admin
exports.updateOrderToDelivered = async (req, res) => {
  try {
    const order = await Order.findByPk(req.params.id);

    if (order) {
      order.isDelivered = true;
      order.deliveredAt = Date.now();

      const updatedOrder = await order.save();
      
      // Get user to send delivery notification
      const user = await User.findByPk(order.userId);

      // Send delivery notification email
      try {
        await sendDeliveryNotification(updatedOrder, user);
      } catch (emailError) {
        console.error('Failed to send delivery notification email:', emailError);
        // Don't fail the delivery update if email fails
      }
      
      res.json(updatedOrder);
    } else {
      res.status(404).json({ message: 'Order not found' });
    }
  } catch (error) {
    console.error(error);
    res.status(500).json({ message: 'Server error' });
  }
};

// @desc    Get logged in user orders
// @route   GET /api/orders/myorders
// @access  Private
exports.getMyOrders = async (req, res) => {
  try {
    const orders = await Order.findAll({
      where: { userId: req.user.id },
      order: [['createdAt', 'DESC']]
    });
    res.json(orders);
  } catch (error) {
    console.error(error);
    res.status(500).json({ message: 'Server error' });
  }
};

// @desc    Get all orders
// @route   GET /api/orders
// @access  Private/Admin
exports.getOrders = async (req, res) => {
  try {
    const orders = await Order.findAll({
      order: [['createdAt', 'DESC']]
    });
    res.json(orders);
  } catch (error) {
    console.error(error);
    res.status(500).json({ message: 'Server error' });
  }
};

// @desc    Process payment with Stripe
// @route   POST /api/orders/process-payment
// @access  Private
exports.processPayment = async (req, res) => {
  try {
    const { amount, currency = 'usd', source } = req.body;

    // Convert amount to smallest currency unit (e.g., cents for USD)
    const convertedAmount = Math.round(amount * 100);

    // Create a charge using the Stripe API
    const charge = await stripe.charges.create({
      amount: convertedAmount,
      currency: currency,
      source: source, // obtained with Stripe.js
      metadata: { 
        userId: req.user.id,
        orderDescription: 'E-commerce purchase'
      }
    });

    res.json({
      success: true,
      chargeId: charge.id,
      status: charge.status,
      payment_method: charge.payment_method_details
    });
  } catch (error) {
    console.error(error);
    res.status(500).json({ 
      success: false,
      message: error.message 
    });
  }
};

// @desc    Create a Stripe payment intent
// @route   POST /api/orders/create-payment-intent
// @access  Private
exports.createPaymentIntent = async (req, res) => {
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