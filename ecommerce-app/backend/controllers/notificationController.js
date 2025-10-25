const { Order, User, Product } = require('../models');
const {
  sendOrderConfirmation,
  sendOrderStatusUpdate,
  sendLowStockNotification,
  sendOutOfStockNotification
} = require('../utils/email');

// Send order confirmation email
const sendOrderConfirmationEmail = async (req, res) => {
  try {
    const { orderId } = req.params;
    const userId = req.user.id;

    // Get order and user
    const order = await Order.findByPk(orderId);
    const user = await User.findByPk(userId);

    if (!order || !user) {
      return res.status(404).json({ message: 'Order or user not found' });
    }

    // Make sure the user owns the order
    if (order.userId !== userId) {
      return res.status(403).json({ message: 'Unauthorized to access this order' });
    }

    // Send the email
    await sendOrderConfirmation(user, order);

    res.status(200).json({
      success: true,
      message: 'Order confirmation email sent successfully'
    });
  } catch (error) {
    res.status(500).json({ message: 'Server error', error: error.message });
  }
};

// Send order status update email
const sendOrderStatusUpdateEmail = async (req, res) => {
  try {
    const { orderId } = req.params;
    const userId = req.user.id;

    // Get order and user
    const order = await Order.findByPk(orderId);
    const user = await User.findByPk(userId);

    if (!order || !user) {
      return res.status(404).json({ message: 'Order or user not found' });
    }

    // Make sure the user owns the order
    if (order.userId !== userId) {
      return res.status(403).json({ message: 'Unauthorized to access this order' });
    }

    // Send the email
    await sendOrderStatusUpdate(user, order);

    res.status(200).json({
      success: true,
      message: 'Order status update email sent successfully'
    });
  } catch (error) {
    res.status(500).json({ message: 'Server error', error: error.message });
  }
};

// Trigger low stock notification for admin (admin only)
const triggerLowStockNotification = async (req, res) => {
  try {
    const { productId } = req.params;

    // Get product
    const product = await Product.findByPk(productId);

    if (!product) {
      return res.status(404).json({ message: 'Product not found' });
    }

    // Get admin user (assuming first admin user for example)
    const adminUser = await User.findOne({ where: { role: 'admin', isActive: true } });

    if (!adminUser) {
      return res.status(404).json({ message: 'No admin user found' });
    }

    // Send the notification
    await sendLowStockNotification(adminUser.email, product);

    res.status(200).json({
      success: true,
      message: 'Low stock notification sent successfully'
    });
  } catch (error) {
    res.status(500).json({ message: 'Server error', error: error.message });
  }
};

// Trigger out of stock notification for admin (admin only)
const triggerOutOfStockNotification = async (req, res) => {
  try {
    const { productId } = req.params;

    // Get product
    const product = await Product.findByPk(productId);

    if (!product) {
      return res.status(404).json({ message: 'Product not found' });
    }

    // Get admin user (assuming first admin user for example)
    const adminUser = await User.findOne({ where: { role: 'admin', isActive: true } });

    if (!adminUser) {
      return res.status(404).json({ message: 'No admin user found' });
    }

    // Send the notification
    await sendOutOfStockNotification(adminUser.email, product);

    res.status(200).json({
      success: true,
      message: 'Out of stock notification sent successfully'
    });
  } catch (error) {
    res.status(500).json({ message: 'Server error', error: error.message });
  }
};

module.exports = {
  sendOrderConfirmationEmail,
  sendOrderStatusUpdateEmail,
  triggerLowStockNotification,
  triggerOutOfStockNotification
};