const { Op } = require('sequelize');
const Product = require('../models/Product');

// @desc      Update product inventory
// @route     PUT /api/v1/products/:id/inventory
// @access    Private/Admin
exports.updateInventory = async (req, res) => {
  try {
    const { quantity } = req.body;
    
    const product = await Product.findByPk(req.params.id);

    if (!product) {
      return res.status(404).json({ success: false, error: 'Product not found' });
    }

    // Update inventory
    product.inventory = quantity;
    await product.save();

    res.status(200).json({
      success: true,
      data: product
    });
  } catch (error) {
    res.status(400).json({ success: false, error: error.message });
  }
};

// @desc      Adjust product inventory (add/remove stock)
// @route     PATCH /api/v1/products/:id/inventory
// @access    Private/Admin
exports.adjustInventory = async (req, res) => {
  try {
    const { quantity, action } = req.body; // action: 'add' or 'remove'
    
    const product = await Product.findByPk(req.params.id);

    if (!product) {
      return res.status(404).json({ success: false, error: 'Product not found' });
    }

    let newQuantity;
    if (action === 'add') {
      newQuantity = product.inventory + quantity;
    } else if (action === 'remove') {
      newQuantity = product.inventory - quantity;
      if (newQuantity < 0) {
        newQuantity = 0; // Prevent negative inventory
      }
    } else {
      return res.status(400).json({ success: false, error: 'Invalid action. Use "add" or "remove"' });
    }

    // Update inventory
    product.inventory = newQuantity;
    await product.save();

    res.status(200).json({
      success: true,
      data: product
    });
  } catch (error) {
    res.status(400).json({ success: false, error: error.message });
  }
};

// @desc      Get low inventory products
// @route     GET /api/v1/products/low-stock
// @access    Private/Admin
exports.getLowStockProducts = async (req, res) => {
  try {
    // Get products with inventory below a threshold (default 10)
    const threshold = parseInt(req.query.threshold) || 10;
    
    const products = await Product.findAll({
      where: {
        inventory: {
          [Op.lt]: threshold
        },
        isActive: true
      }
    });

    res.status(200).json({
      success: true,
      count: products.length,
      data: products
    });
  } catch (error) {
    res.status(500).json({ success: false, error: error.message });
  }
};