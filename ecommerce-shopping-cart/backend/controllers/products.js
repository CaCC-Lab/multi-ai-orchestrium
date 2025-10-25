const Product = require('../models/Product');
const { Op } = require('sequelize');
const { clearProductCache } = require('../middleware/cache');

// @desc      Get all products
// @route     GET /api/v1/products
// @access    Public
exports.getProducts = async (req, res) => {
  try {
    const products = await Product.findAll({
      where: { 
        isActive: true 
      },
      order: [['createdAt', 'DESC']]
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

// @desc      Get single product
// @route     GET /api/v1/products/:id
// @access    Public
exports.getProduct = async (req, res) => {
  try {
    const product = await Product.findByPk(req.params.id);

    if (!product || !product.isActive) {
      return res.status(404).json({ success: false, error: 'Product not found' });
    }

    res.status(200).json({
      success: true,
      data: product
    });
  } catch (error) {
    res.status(500).json({ success: false, error: error.message });
  }
};

// @desc      Create new product
// @route     POST /api/v1/products
// @access    Private/Admin
exports.createProduct = async (req, res) => {
  try {
    const product = await Product.create(req.body);

    res.status(201).json({
      success: true,
      data: product
    });
  } catch (error) {
    res.status(400).json({ success: false, error: error.message });
  }
};

// @desc      Update product
// @route     PUT /api/v1/products/:id
// @access    Private/Admin
exports.updateProduct = async (req, res) => {
  try {
    const product = await Product.findByPk(req.params.id);

    if (!product) {
      return res.status(404).json({ success: false, error: 'Product not found' });
    }

    await product.update(req.body);
    
    // Clear cache for this product
    await clearProductCache(req.params.id);

    res.status(200).json({
      success: true,
      data: product
    });
  } catch (error) {
    res.status(400).json({ success: false, error: error.message });
  }
};

// @desc      Delete product
// @route     DELETE /api/v1/products/:id
// @access    Private/Admin
exports.deleteProduct = async (req, res) => {
  try {
    const product = await Product.findByPk(req.params.id);

    if (!product) {
      return res.status(404).json({ success: false, error: 'Product not found' });
    }

    await product.update({ isActive: false });
    
    // Clear cache for this product
    await clearProductCache(req.params.id);

    res.status(200).json({
      success: true,
      data: {}
    });
  } catch (error) {
    res.status(400).json({ success: false, error: error.message });
  }
};

// @desc      Search products
// @route     GET /api/v1/products/search
// @access    Public
exports.searchProducts = async (req, res) => {
  try {
    const { query, category, minPrice, maxPrice, brand, sortBy, sortOrder } = req.query;
    
    let whereClause = { isActive: true };
    
    if (query) {
      whereClause[Op.or] = [
        { name: { [Op.iLike]: `%${query}%` } },
        { description: { [Op.iLike]: `%${query}%` } }
      ];
    }
    
    if (category) {
      whereClause.category = { [Op.iLike]: category };
    }
    
    if (brand) {
      whereClause.brand = { [Op.iLike]: brand };
    }
    
    if (minPrice || maxPrice) {
      whereClause.price = {};
      if (minPrice) whereClause.price[Op.gte] = minPrice;
      if (maxPrice) whereClause.price[Op.lte] = maxPrice;
    }

    const orderClause = [];
    if (sortBy) {
      const direction = (sortOrder === 'desc' || sortOrder === 'DESC') ? 'DESC' : 'ASC';
      orderClause.push([sortBy, direction]);
    } else {
      orderClause.push(['createdAt', 'DESC']);
    }

    const products = await Product.findAll({
      where: whereClause,
      order: orderClause
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