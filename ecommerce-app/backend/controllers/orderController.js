const { Order, User } = require('../models');
const { convertCurrency, SUPPORTED_CURRENCIES } = require('../utils/currency');

// Get user's order history
const getUserOrders = async (req, res) => {
  try {
    const userId = req.user.id;
    const { page = 1, limit = 10, status, currency } = req.query;

    // Validate currency if provided
    if (currency && !SUPPORTED_CURRENCIES.includes(currency)) {
      return res.status(400).json({ message: `Unsupported currency: ${currency}` });
    }

    // Build query conditions
    let where = { userId };
    
    if (status) {
      where.status = status;
    }

    // Calculate offset for pagination
    const offset = (parseInt(page) - 1) * parseInt(limit);

    // Fetch orders with pagination and filters
    const orders = await Order.findAndCountAll({
      where,
      limit: parseInt(limit),
      offset,
      order: [['createdAt', 'DESC']], // Most recent first
      attributes: { exclude: ['updatedAt'] } // Exclude updatedAt for now
    });

    // Convert order amounts to requested currency if specified
    let convertedOrders = orders.rows;
    if (currency && currency !== 'USD') {
      convertedOrders = orders.rows.map(order => {
        return {
          ...order.toJSON(),
          totalAmount: convertCurrency(parseFloat(order.totalAmount), order.currency, currency),
          currency: currency
        };
      });
    }

    // Calculate pagination metadata
    const totalPages = Math.ceil(orders.count / limit);
    const hasNextPage = page < totalPages;
    const hasPrevPage = page > 1;

    res.status(200).json({
      success: true,
      count: orders.count,
      currentPage: parseInt(page),
      totalPages,
      hasNextPage,
      hasPrevPage,
      currency: currency || 'USD',
      orders: convertedOrders
    });
  } catch (error) {
    res.status(500).json({ message: 'Server error', error: error.message });
  }
};

// Get a specific order by ID
const getOrderById = async (req, res) => {
  try {
    const { orderId } = req.params;
    const userId = req.user.id;
    const { currency } = req.query;

    // Validate currency if provided
    if (currency && !SUPPORTED_CURRENCIES.includes(currency)) {
      return res.status(400).json({ message: `Unsupported currency: ${currency}` });
    }

    // Find order by ID and ensure it belongs to the user
    const order = await Order.findOne({
      where: { 
        id: orderId, 
        userId 
      },
      attributes: { exclude: ['updatedAt'] }
    });

    if (!order) {
      return res.status(404).json({ message: 'Order not found or does not belong to user' });
    }

    // Convert order amounts to requested currency if specified
    let convertedOrder = order.toJSON();
    if (currency && currency !== order.currency) {
      convertedOrder = {
        ...convertedOrder,
        totalAmount: convertCurrency(parseFloat(order.totalAmount), order.currency, currency),
        shippingCost: convertCurrency(parseFloat(order.shippingCost), order.currency, currency),
        taxAmount: convertCurrency(parseFloat(order.taxAmount), order.currency, currency),
        currency: currency
      };
    }

    res.status(200).json({
      success: true,
      currency: currency || order.currency,
      order: convertedOrder
    });
  } catch (error) {
    res.status(500).json({ message: 'Server error', error: error.message });
  }
};

// Get order tracking information
const getOrderTracking = async (req, res) => {
  try {
    const { orderId } = req.params;
    const userId = req.user.id;

    // Find order by ID and ensure it belongs to the user
    const order = await Order.findOne({
      where: { 
        id: orderId, 
        userId 
      },
      attributes: ['id', 'orderNumber', 'trackingNumber', 'status', 'createdAt', 'updatedAt', 'estimatedDelivery', 'currency', 'totalAmount']
    });

    if (!order) {
      return res.status(404).json({ message: 'Order not found or does not belong to user' });
    }

    // In a real application, you would integrate with a shipping carrier API
    // For this example, we'll return mock tracking information
    const trackingInfo = {
      orderId: order.id,
      orderNumber: order.orderNumber,
      trackingNumber: order.trackingNumber,
      status: order.status,
      totalAmount: order.totalAmount,
      currency: order.currency,
      estimatedDelivery: order.estimatedDelivery || new Date(Date.now() + 5 * 24 * 60 * 60 * 1000), // 5 days from now
      trackingEvents: [
        {
          status: 'Order Placed',
          timestamp: order.createdAt,
          location: 'Processing Center',
          description: 'Your order has been received and is being processed'
        },
        {
          status: 'Processing',
          timestamp: new Date(order.createdAt.getTime() + 2 * 60 * 60 * 1000), // 2 hours after order
          location: 'Processing Center',
          description: 'Your order is being prepared for shipment'
        }
      ]
    };

    // Add shipped status event if order status is shipped or delivered
    if (order.status === 'shipped' || order.status === 'delivered') {
      trackingInfo.trackingEvents.push({
        status: 'Shipped',
        timestamp: new Date(order.createdAt.getTime() + 24 * 60 * 60 * 1000), // 1 day after order
        location: 'Shipping Facility',
        description: 'Your order has been shipped'
      });
    }

    // Add delivered status event if order status is delivered
    if (order.status === 'delivered') {
      trackingInfo.trackingEvents.push({
        status: 'Delivered',
        timestamp: new Date(order.createdAt.getTime() + 3 * 24 * 60 * 60 * 1000), // 3 days after order
        location: 'Delivery Address',
        description: 'Your order has been delivered'
      });
    }

    res.status(200).json({
      success: true,
      trackingInfo
    });
  } catch (error) {
    res.status(500).json({ message: 'Server error', error: error.message });
  }
};

// Cancel an order (if allowed)
const cancelOrder = async (req, res) => {
  try {
    const { orderId } = req.params;
    const userId = req.user.id;

    // Find order by ID and ensure it belongs to the user
    const order = await Order.findOne({
      where: { 
        id: orderId, 
        userId 
      }
    });

    if (!order) {
      return res.status(404).json({ message: 'Order not found or does not belong to user' });
    }

    // Check if order can be cancelled (not shipped or delivered already)
    if (order.status === 'shipped' || order.status === 'delivered') {
      return res.status(400).json({ message: 'Cannot cancel order that has already been shipped or delivered' });
    }

    // Update order status to cancelled
    await order.update({ 
      status: 'cancelled',
      paymentStatus: 'refunded' // In a real app, you would process the refund here
    });

    res.status(200).json({
      success: true,
      message: 'Order cancelled successfully',
      order: {
        id: order.id,
        orderNumber: order.orderNumber,
        status: order.status,
        paymentStatus: order.paymentStatus
      }
    });
  } catch (error) {
    res.status(500).json({ message: 'Server error', error: error.message });
  }
};

module.exports = {
  getUserOrders,
  getOrderById,
  getOrderTracking,
  cancelOrder
};