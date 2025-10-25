const { DataTypes } = require('sequelize');
const sequelize = require('../config/db');

const Order = sequelize.define('Order', {
  id: {
    type: DataTypes.INTEGER,
    primaryKey: true,
    autoIncrement: true
  },
  userId: {
    type: DataTypes.INTEGER,
    allowNull: false,
    references: {
      model: 'users',
      key: 'id'
    }
  },
  orderNumber: {
    type: DataTypes.STRING,
    allowNull: false,
    unique: true
  },
  status: {
    type: DataTypes.ENUM('pending', 'processing', 'shipped', 'delivered', 'cancelled'),
    defaultValue: 'pending'
  },
  items: {
    type: DataTypes.JSON, // Store order items as JSON
    allowNull: false,
    defaultValue: []
  },
  totalAmount: {
    type: DataTypes.DECIMAL(10, 2),
    allowNull: false
  },
  currency: {
    type: DataTypes.STRING,
    defaultValue: 'USD'
  },
  shippingAddress: {
    type: DataTypes.JSON,
    allowNull: false
  },
  billingAddress: {
    type: DataTypes.JSON,
    allowNull: false
  },
  paymentMethod: {
    type: DataTypes.STRING
  },
  paymentStatus: {
    type: DataTypes.ENUM('pending', 'paid', 'failed', 'refunded'),
    defaultValue: 'pending'
  },
  paymentIntentId: {
    type: DataTypes.STRING // Stripe payment intent ID
  },
  trackingNumber: {
    type: DataTypes.STRING
  },
  estimatedDelivery: {
    type: DataTypes.DATE
  },
  shippingCost: {
    type: DataTypes.DECIMAL(10, 2),
    defaultValue: 0.00
  },
  taxAmount: {
    type: DataTypes.DECIMAL(10, 2),
    defaultValue: 0.00
  }
}, {
  tableName: 'orders',
  timestamps: true,
  indexes: [
    {
      fields: ['userId'] // Index for faster user order lookups
    },
    {
      fields: ['orderNumber'] // Index for faster order number lookups (unique is already indexed)
    },
    {
      fields: ['status'] // Index for faster status-based queries
    },
    {
      fields: ['paymentStatus'] // Index for faster payment status queries
    },
    {
      fields: ['createdAt'] // Index for faster date-based queries
    },
    {
      fields: ['userId', 'status'] // Composite index for user-orders by status
    },
    {
      fields: ['userId', 'createdAt'] // Composite index for user's order history
    }
  ]
});

module.exports = Order;