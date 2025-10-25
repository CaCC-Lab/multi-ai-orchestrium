const { DataTypes } = require('sequelize');
const { sequelize } = require('../config/db');

const Product = sequelize.define('Product', {
  id: {
    type: DataTypes.INTEGER,
    primaryKey: true,
    autoIncrement: true
  },
  name: {
    type: DataTypes.STRING,
    allowNull: false,
    index: true // Add index for searching
  },
  description: {
    type: DataTypes.TEXT
  },
  price: {
    type: DataTypes.DECIMAL(10, 2),
    allowNull: false,
    index: true, // Add index for price filtering
    validate: {
      min: 0
    }
  },
  category: {
    type: DataTypes.STRING,
    allowNull: false,
    index: true // Add index for category filtering
  },
  brand: {
    type: DataTypes.STRING,
    index: true // Add index for brand filtering
  },
  sku: {
    type: DataTypes.STRING,
    unique: true,
    index: true
  },
  inventory: {
    type: DataTypes.INTEGER,
    defaultValue: 0,
    index: true // Add index for inventory filtering
  },
  images: {
    type: DataTypes.ARRAY(DataTypes.STRING)
  },
  specifications: {
    type: DataTypes.JSONB
  },
  rating: {
    type: DataTypes.DECIMAL(3, 2),
    defaultValue: 0.00,
    index: true // Add index for rating sorting/filtering
  },
  numReviews: {
    type: DataTypes.INTEGER,
    defaultValue: 0
  },
  isActive: {
    type: DataTypes.BOOLEAN,
    defaultValue: true,
    index: true // Add index for active product filtering
  },
  discountPercentage: {
    type: DataTypes.DECIMAL(5, 2),
    defaultValue: 0.00
  }
}, {
  tableName: 'products',
  timestamps: true,
  indexes: [
    {
      unique: true,
      fields: ['sku']
    },
    {
      fields: ['category', 'isActive'] // Composite index for category filtering
    },
    {
      fields: ['brand', 'isActive'] // Composite index for brand filtering
    },
    {
      fields: ['isActive', 'price'] // Composite index for active products with price
    },
    {
      fields: ['isActive', 'rating'] // Composite index for active products with rating
    }
  ]
});

module.exports = Product;