const { DataTypes } = require('sequelize');
const { sequelize } = require('../config/db');

const Cart = sequelize.define('Cart', {
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
  productId: {
    type: DataTypes.INTEGER,
    allowNull: false,
    references: {
      model: 'products',
      key: 'id'
    },
    index: true // Add index for product-based queries
  },
  quantity: {
    type: DataTypes.INTEGER,
    allowNull: false,
    defaultValue: 1,
    validate: {
      min: 1
    }
  },
  priceAtTime: {
    type: DataTypes.DECIMAL(10, 2),
    allowNull: false
  }
}, {
  tableName: 'cart',
  timestamps: true,
  indexes: [
    {
      fields: ['userId'] // Index for user's cart queries
    },
    {
      fields: ['productId'] // Index for product-based queries
    },
    {
      unique: true,
      fields: ['userId', 'productId'] // Composite unique index
    }
  ]
});

module.exports = Cart;