const { DataTypes } = require('sequelize');
const sequelize = require('../config/db');

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
    }
  },
  productId: {
    type: DataTypes.INTEGER,
    allowNull: false,
    references: {
      model: 'products',
      key: 'id'
    }
  },
  quantity: {
    type: DataTypes.INTEGER,
    allowNull: false,
    validate: {
      min: 1
    }
  },
  priceAtTime: {
    type: DataTypes.DECIMAL(10, 2), // Store price at the time item was added to cart
    allowNull: false
  },
  currency: {
    type: DataTypes.STRING,
    defaultValue: 'USD'
  }
}, {
  tableName: 'carts',
  timestamps: true,
  indexes: [
    {
      fields: ['userId'] // Index for faster user cart lookups
    },
    {
      fields: ['productId'] // Index for faster product lookups in cart
    },
    {
      unique: true,
      fields: ['userId', 'productId'] // Composite index for user-product combinations (unique cart items)
    }
  ]
});

module.exports = Cart;