// services/inventoryService.js
const Product = require('../models/Product');
const Order = require('../models/Order');
const OrderItem = require('../models/OrderItem');
const { Op } = require('sequelize');

// Check low stock products
const checkLowStock = async (threshold = 10) => {
  try {
    const lowStockProducts = await Product.findAll({
      where: {
        stockQuantity: {
          [Op.lte]: threshold,
          [Op.gt]: 0
        },
        isActive: true
      },
      order: [['stockQuantity', 'ASC']]
    });

    return lowStockProducts;
  } catch (error) {
    console.error('Check low stock error:', error);
    throw error;
  }
};

// Update product stock
const updateStock = async (productId, quantityChange) => {
  try {
    const product = await Product.findByPk(productId);
    if (!product) {
      throw new Error('Product not found');
    }

    const newStock = product.stockQuantity + quantityChange;
    if (newStock < 0) {
      throw new Error('Insufficient stock');
    }

    await product.update({ stockQuantity: newStock });

    return product;
  } catch (error) {
    console.error('Update stock error:', error);
    throw error;
  }
};

// Get inventory report
const getInventoryReport = async () => {
  try {
    const totalProducts = await Product.count();
    const totalStock = await Product.sum('stockQuantity');
    const outOfStockCount = await Product.count({
      where: { stockQuantity: 0 }
    });
    const lowStockCount = await Product.count({
      where: {
        stockQuantity: {
          [Op.gt]: 0,
          [Op.lte]: 10
        }
      }
    });

    const lowStockProducts = await Product.findAll({
      where: {
        stockQuantity: {
          [Op.gt]: 0,
          [Op.lte]: 10
        }
      },
      order: [['stockQuantity', 'ASC']],
      limit: 10
    });

    const outOfStockProducts = await Product.findAll({
      where: { stockQuantity: 0 },
      limit: 10
    });

    return {
      totalProducts,
      totalStock,
      outOfStockCount,
      lowStockCount,
      lowStockProducts,
      outOfStockProducts
    };
  } catch (error) {
    console.error('Get inventory report error:', error);
    throw error;
  }
};

module.exports = {
  checkLowStock,
  updateStock,
  getInventoryReport
};