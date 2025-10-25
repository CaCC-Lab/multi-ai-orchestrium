const { DataTypes } = require('sequelize');
const { sequelize } = require('../config/db');

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
    },
    index: true // Add index for user-based queries
  },
  orderNumber: {
    type: DataTypes.STRING,
    allowNull: false,
    unique: true,
    index: true
  },
  status: {
    type: DataTypes.ENUM('pending', 'processing', 'shipped', 'delivered', 'cancelled'),
    defaultValue: 'pending',
    index: true // Add index for status-based queries
  },
  items: {
    type: DataTypes.JSONB
  },
  totalAmount: {
    type: DataTypes.DECIMAL(10, 2),
    allowNull: false,
    index: true // Add index for amount-based queries
  },
  currency: {
    type: DataTypes.STRING,
    defaultValue: 'USD'
  },
  shippingAddress: {
    type: DataTypes.JSONB,
    allowNull: false
  },
  billingAddress: {
    type: DataTypes.JSONB
  },
  paymentMethod: {
    type: DataTypes.STRING,
    index: true // Add index for payment method queries
  },
  paymentStatus: {
    type: DataTypes.ENUM('pending', 'paid', 'failed', 'refunded'),
    defaultValue: 'pending',
    index: true // Add index for payment status queries
  },
  paymentIntentId: {
    type: DataTypes.STRING,
    index: true // Add index for payment intent queries
  },
  trackingNumber: {
    type: DataTypes.STRING,
    index: true // Add index for tracking number queries
  },
  notes: {
    type: DataTypes.TEXT
  }
}, {
  tableName: 'orders',
  timestamps: true,
  indexes: [
    {
      unique: true,
      fields: ['orderNumber']
    },
    {
      fields: ['userId', 'createdAt'] // Composite index for user orders with date
    },
    {
      fields: ['status', 'createdAt'] // Composite index for status with date
    },
    {
      fields: ['paymentStatus', 'createdAt'] // Composite index for payment status with date
    }
  ]
});

module.exports = Order;