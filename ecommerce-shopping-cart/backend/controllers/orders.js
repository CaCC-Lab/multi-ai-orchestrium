const Order = require('../models/Order');
const Cart = require('../models/Cart');
const Product = require('../models/Product');
const stripe = require('stripe')(process.env.STRIPE_SECRET_KEY);
const { sendOrderConfirmation } = require('../utils/sendEmail');
const { v4: uuidv4 } = require('uuid');
const { clearProductCache } = require('../middleware/cache');

// @desc      Get all orders
// @route     GET /api/v1/orders
// @access    Private/Admin
exports.getOrders = async (req, res) => {
  try {
    const orders = await Order.findAll();

    res.status(200).json({
      success: true,
      count: orders.length,
      data: orders
    });
  } catch (error) {
    res.status(500).json({ success: false, error: error.message });
  }
};

// @desc      Get single order
// @route     GET /api/v1/orders/:id
// @access    Private
exports.getOrder = async (req, res) => {
  try {
    const order = await Order.findByPk(req.params.id);

    if (!order) {
      return res.status(404).json({ success: false, error: 'Order not found' });
    }

    // Check if user is owner or admin
    if (req.user.role !== 'admin' && order.userId !== req.user.id) {
      return res.status(401).json({ success: false, error: 'Not authorized' });
    }

    res.status(200).json({
      success: true,
      data: order
    });
  } catch (error) {
    res.status(500).json({ success: false, error: error.message });
  }
};

// @desc      Create new order
// @route     POST /api/v1/orders
// @access    Private
exports.createOrder = async (req, res) => {
  try {
    const cartItems = await Cart.findAll({
      where: { userId: req.user.id },
      include: [{ model: Product }]
    });

    if (cartItems.length === 0) {
      return res.status(400).json({ success: false, error: 'Cart is empty' });
    }

    // Calculate total amount
    let totalAmount = 0;
    const orderItems = [];

    for (const item of cartItems) {
      // Check inventory
      if (item.Product.inventory < item.quantity) {
        return res.status(400).json({ 
          success: false, 
          error: `Not enough inventory for ${item.Product.name}` 
        });
      }

      // Update inventory
      await Product.update(
        { inventory: item.Product.inventory - item.quantity },
        { where: { id: item.Product.id } }
      );
      
      // Clear cache for this product
      await clearProductCache(item.Product.id);

      totalAmount += parseFloat(item.priceAtTime) * item.quantity;
      orderItems.push({
        productId: item.Product.id,
        name: item.Product.name,
        price: parseFloat(item.priceAtTime),
        quantity: item.quantity,
        image: item.Product.images && item.Product.images.length > 0 ? item.Product.images[0] : null
      });
    }

    // Create Stripe payment intent
    const paymentIntent = await stripe.paymentIntents.create({
      amount: Math.round(totalAmount * 100), // Convert to cents
      currency: req.body.currency || 'usd',
      metadata: {
        userId: req.user.id,
        orderId: uuidv4()
      }
    });

    // Create order
    const order = await Order.create({
      userId: req.user.id,
      orderNumber: `ORD-${Date.now()}`,
      items: orderItems,
      totalAmount: totalAmount,
      currency: req.body.currency || 'USD',
      shippingAddress: req.body.shippingAddress,
      billingAddress: req.body.billingAddress || req.body.shippingAddress,
      paymentMethod: req.body.paymentMethod || 'card',
      paymentStatus: 'pending',
      paymentIntentId: paymentIntent.id
    });

    // Clear user's cart
    await Cart.destroy({
      where: { userId: req.user.id }
    });

    // Send order confirmation email
    try {
      await sendOrderConfirmation(order, req.user);
    } catch (err) {
      console.error('Error sending order confirmation email:', err);
      // Don't fail the order if email fails
    }

    res.status(201).json({
      success: true,
      data: {
        order,
        clientSecret: paymentIntent.client_secret
      }
    });
  } catch (error) {
    res.status(400).json({ success: false, error: error.message });
  }
};

// @desc      Update order
// @route     PUT /api/v1/orders/:id
// @access    Private/Admin
exports.updateOrder = async (req, res) => {
  try {
    const order = await Order.findByPk(req.params.id);

    if (!order) {
      return res.status(404).json({ success: false, error: 'Order not found' });
    }

    await order.update(req.body);

    res.status(200).json({
      success: true,
      data: order
    });
  } catch (error) {
    res.status(400).json({ success: false, error: error.message });
  }
};

// @desc      Delete order
// @route     DELETE /api/v1/orders/:id
// @access    Private/Admin
exports.deleteOrder = async (req, res) => {
  try {
    const order = await Order.findByPk(req.params.id);

    if (!order) {
      return res.status(404).json({ success: false, error: 'Order not found' });
    }

    await order.destroy();

    res.status(200).json({
      success: true,
      data: {}
    });
  } catch (error) {
    res.status(500).json({ success: false, error: error.message });
  }
};

// @desc      Get logged in user orders
// @route     GET /api/v1/orders/myorders
// @access    Private
exports.getUserOrders = async (req, res) => {
  try {
    const orders = await Order.findAll({
      where: { userId: req.user.id },
      order: [['createdAt', 'DESC']]
    });

    res.status(200).json({
      success: true,
      count: orders.length,
      data: orders
    });
  } catch (error) {
    res.status(500).json({ success: false, error: error.message });
  }
};