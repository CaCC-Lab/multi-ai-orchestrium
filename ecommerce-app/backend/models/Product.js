const { DataTypes } = require('sequelize');
const sequelize = require('../config/db');

const Product = sequelize.define('Product', {
  id: {
    type: DataTypes.INTEGER,
    primaryKey: true,
    autoIncrement: true
  },
  name: {
    type: DataTypes.STRING,
    allowNull: false,
    // Add index for name for faster searching
    set(val) {
      this.setDataValue('name', val);
    }
  },
  description: {
    type: DataTypes.TEXT
  },
  price: {
    type: DataTypes.DECIMAL(10, 2),
    allowNull: false,
    validate: {
      min: 0
    }
  },
  currency: {
    type: DataTypes.STRING,
    defaultValue: 'USD'
  },
  category: {
    type: DataTypes.STRING,
    allowNull: false
  },
  brand: {
    type: DataTypes.STRING
  },
  stockQuantity: {
    type: DataTypes.INTEGER,
    defaultValue: 0,
    validate: {
      min: 0
    }
  },
  sku: {
    type: DataTypes.STRING,
    allowNull: false,
    unique: true
  },
  imageUrls: {
    type: DataTypes.JSON,
    defaultValue: []
  },
  rating: {
    type: DataTypes.DECIMAL(3, 2), // e.g., 4.50
    defaultValue: 0.00,
    validate: {
      min: 0,
      max: 5
    }
  },
  numReviews: {
    type: DataTypes.INTEGER,
    defaultValue: 0
  },
  isActive: {
    type: DataTypes.BOOLEAN,
    defaultValue: true
  }
}, {
  tableName: 'products',
  timestamps: true,
  indexes: [
    {
      fields: ['name'] // Index for faster name searches
    },
    {
      fields: ['category'] // Index for faster category filtering
    },
    {
      fields: ['brand'] // Index for faster brand filtering
    },
    {
      fields: ['price'] // Index for faster price filtering
    },
    {
      fields: ['isActive'] // Index for faster active product filtering
    },
    {
      fields: ['category', 'isActive'] // Composite index for common filter combination
    },
    {
      fields: ['brand', 'isActive'] // Composite index for brand + active filter
    },
    {
      fields: ['price', 'isActive'] // Composite index for price + active filter
    }
  ]
});

module.exports = Product;