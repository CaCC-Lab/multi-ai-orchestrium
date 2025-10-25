const { Product } = require('../models');
const { Op } = require('sequelize');

// Get inventory report
const getInventoryReport = async (req, res) => {
  try {
    const {
      page = 1,
      limit = 10,
      lowStockOnly = false,
      category = '',
      sortBy = 'stockQuantity',
      sortOrder = 'ASC' // Low stock items first by default
    } = req.query;

    // Build query conditions
    let where = {};
    
    if (lowStockOnly === 'true') {
      // Consider low stock as less than 10 units
      where.stockQuantity = { [Op.lt]: 10 };
    }
    
    if (category) {
      where.category = category;
    }

    // Calculate offset for pagination
    const offset = (parseInt(page) - 1) * parseInt(limit);

    // Define order for sorting
    const order = [[sortBy, sortOrder.toUpperCase()]];

    // Fetch products with pagination and filters
    const products = await Product.findAndCountAll({
      where,
      limit: parseInt(limit),
      offset,
      order,
      attributes: { exclude: ['createdAt', 'updatedAt'] }
    });

    // Calculate pagination metadata
    const totalPages = Math.ceil(products.count / limit);
    const hasNextPage = page < totalPages;
    const hasPrevPage = page > 1;

    // Calculate inventory stats
    const totalProducts = await Product.count();
    const totalStock = (await Product.sum('stockQuantity')) || 0;
    const lowStockProducts = await Product.count({ 
      where: { 
        stockQuantity: { [Op.lt]: 10 },
        isActive: true
      } 
    });
    const outOfStockProducts = await Product.count({ 
      where: { 
        stockQuantity: 0,
        isActive: true
      } 
    });

    res.status(200).json({
      success: true,
      count: products.count,
      currentPage: parseInt(page),
      totalPages,
      hasNextPage,
      hasPrevPage,
      inventoryStats: {
        totalProducts,
        totalStock,
        lowStockProducts,
        outOfStockProducts
      },
      products: products.rows
    });
  } catch (error) {
    res.status(500).json({ message: 'Server error', error: error.message });
  }
};

// Update product stock
const updateProductStock = async (req, res) => {
  try {
    const { productId } = req.params;
    const { quantity, operation = 'set' } = req.body; // operation can be 'set', 'add', 'subtract'

    // Validate operation
    if (!['set', 'add', 'subtract'].includes(operation)) {
      return res.status(400).json({ message: 'Invalid operation. Use set, add, or subtract' });
    }

    // Get current product
    const product = await Product.findByPk(productId);
    if (!product) {
      return res.status(404).json({ message: 'Product not found' });
    }

    let newQuantity;
    switch (operation) {
      case 'set':
        newQuantity = quantity;
        break;
      case 'add':
        newQuantity = product.stockQuantity + quantity;
        break;
      case 'subtract':
        newQuantity = product.stockQuantity - quantity;
        break;
      default:
        return res.status(400).json({ message: 'Invalid operation' });
    }

    // Ensure stock quantity is not negative
    if (newQuantity < 0) {
      return res.status(400).json({ message: 'Stock quantity cannot be negative' });
    }

    // Update stock quantity
    await Product.update(
      { 
        stockQuantity: newQuantity,
        // Update product status if stock is 0
        isActive: newQuantity > 0 ? product.isActive : false
      },
      { where: { id: productId } }
    );

    // Fetch updated product
    const updatedProduct = await Product.findByPk(productId, {
      attributes: { exclude: ['createdAt', 'updatedAt'] }
    });

    res.status(200).json({
      success: true,
      message: 'Stock updated successfully',
      product: updatedProduct
    });
  } catch (error) {
    res.status(500).json({ message: 'Server error', error: error.message });
  }
};

// Bulk update stock from CSV/file (simplified implementation)
const bulkUpdateStock = async (req, res) => {
  try {
    // In a real application, this would process an uploaded file
    // For this example, we'll accept an array of updates
    const { updates } = req.body; // Array of { productId, quantity, operation }

    if (!Array.isArray(updates)) {
      return res.status(400).json({ message: 'Updates must be an array' });
    }

    const results = [];

    for (const update of updates) {
      const { productId, quantity, operation = 'set' } = update;

      // Validate operation
      if (!['set', 'add', 'subtract'].includes(operation)) {
        results.push({
          productId,
          success: false,
          message: 'Invalid operation. Use set, add, or subtract'
        });
        continue;
      }

      // Get current product
      const product = await Product.findByPk(productId);
      if (!product) {
        results.push({
          productId,
          success: false,
          message: 'Product not found'
        });
        continue;
      }

      let newQuantity;
      switch (operation) {
        case 'set':
          newQuantity = quantity;
          break;
        case 'add':
          newQuantity = product.stockQuantity + quantity;
          break;
        case 'subtract':
          newQuantity = product.stockQuantity - quantity;
          break;
        default:
          results.push({
            productId,
            success: false,
            message: 'Invalid operation'
          });
          continue;
      }

      // Ensure stock quantity is not negative
      if (newQuantity < 0) {
        results.push({
          productId,
          success: false,
          message: 'Stock quantity cannot be negative'
        });
        continue;
      }

      // Update stock quantity
      await Product.update(
        { 
          stockQuantity: newQuantity,
          // Update product status if stock is 0
          isActive: newQuantity > 0 ? product.isActive : false
        },
        { where: { id: productId } }
      );

      results.push({
        productId,
        success: true,
        newQuantity
      });
    }

    res.status(200).json({
      success: true,
      message: 'Bulk stock update completed',
      results
    });
  } catch (error) {
    res.status(500).json({ message: 'Server error', error: error.message });
  }
};

// Get low stock alerts
const getLowStockAlerts = async (req, res) => {
  try {
    const { threshold = 10 } = req.query;

    // Get products with stock below threshold
    const lowStockProducts = await Product.findAll({
      where: {
        stockQuantity: {
          [Op.lt]: parseInt(threshold),
          [Op.gt]: 0 // Greater than 0, so not out of stock
        },
        isActive: true
      },
      attributes: ['id', 'name', 'sku', 'stockQuantity', 'category'],
      order: [['stockQuantity', 'ASC']]
    });

    res.status(200).json({
      success: true,
      threshold: parseInt(threshold),
      count: lowStockProducts.length,
      lowStockProducts
    });
  } catch (error) {
    res.status(500).json({ message: 'Server error', error: error.message });
  }
};

// Get out of stock products
const getOutOfStockProducts = async (req, res) => {
  try {
    const {
      page = 1,
      limit = 10,
      category = '',
      sortBy = 'name',
      sortOrder = 'ASC'
    } = req.query;

    // Build query conditions
    let where = {
      stockQuantity: 0,
      isActive: true
    };
    
    if (category) {
      where.category = category;
    }

    // Calculate offset for pagination
    const offset = (parseInt(page) - 1) * parseInt(limit);

    // Define order for sorting
    const order = [[sortBy, sortOrder.toUpperCase()]];

    // Fetch out of stock products with pagination and filters
    const products = await Product.findAndCountAll({
      where,
      limit: parseInt(limit),
      offset,
      order,
      attributes: ['id', 'name', 'sku', 'category', 'brand', 'price']
    });

    // Calculate pagination metadata
    const totalPages = Math.ceil(products.count / limit);
    const hasNextPage = page < totalPages;
    const hasPrevPage = page > 1;

    res.status(200).json({
      success: true,
      count: products.count,
      currentPage: parseInt(page),
      totalPages,
      hasNextPage,
      hasPrevPage,
      products: products.rows
    });
  } catch (error) {
    res.status(500).json({ message: 'Server error', error: error.message });
  }
};

module.exports = {
  getInventoryReport,
  updateProductStock,
  bulkUpdateStock,
  getLowStockAlerts,
  getOutOfStockProducts
};