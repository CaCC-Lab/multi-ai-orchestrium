const { Product, Order, User } = require('../models');
const { Op } = require('sequelize');

// Get all products (admin only)
const getAllProducts = async (req, res) => {
  try {
    const {
      page = 1,
      limit = 10,
      search = '',
      category = '',
      brand = '',
      status = '', // 'active', 'inactive', 'all'
      sortBy = 'createdAt',
      sortOrder = 'DESC'
    } = req.query;

    // Build query conditions
    let where = {};
    
    if (search) {
      where.name = { [Op.iLike]: `%${search}%` };
    }
    
    if (category) {
      where.category = category;
    }
    
    if (brand) {
      where.brand = brand;
    }
    
    if (status === 'active') {
      where.isActive = true;
    } else if (status === 'inactive') {
      where.isActive = false;
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

// Get a single product by ID (admin only)
const getProductById = async (req, res) => {
  try {
    const { id } = req.params;

    const product = await Product.findByPk(id, {
      attributes: { exclude: ['createdAt', 'updatedAt'] }
    });

    if (!product) {
      return res.status(404).json({ message: 'Product not found' });
    }

    res.status(200).json({
      success: true,
      product
    });
  } catch (error) {
    res.status(500).json({ message: 'Server error', error: error.message });
  }
};

// Create a new product (admin only)
const createProduct = async (req, res) => {
  try {
    const {
      name,
      description,
      price,
      category,
      brand,
      stockQuantity,
      sku,
      imageUrls = [],
      isActive = true
    } = req.body;

    // Check if product with SKU already exists
    const existingProduct = await Product.findOne({ where: { sku } });
    if (existingProduct) {
      return res.status(400).json({ message: 'Product with this SKU already exists' });
    }

    // Create new product
    const product = await Product.create({
      name,
      description,
      price,
      category,
      brand,
      stockQuantity,
      sku,
      imageUrls,
      isActive
    });

    res.status(201).json({
      success: true,
      message: 'Product created successfully',
      product
    });
  } catch (error) {
    res.status(500).json({ message: 'Server error', error: error.message });
  }
};

// Update a product by ID (admin only)
const updateProduct = async (req, res) => {
  try {
    const { id } = req.params;
    const updateData = req.body;

    // Check if product exists
    const product = await Product.findByPk(id);
    if (!product) {
      return res.status(404).json({ message: 'Product not found' });
    }

    // Update product
    await Product.update(updateData, { where: { id } });

    // Fetch updated product
    const updatedProduct = await Product.findByPk(id, {
      attributes: { exclude: ['createdAt', 'updatedAt'] }
    });

    res.status(200).json({
      success: true,
      message: 'Product updated successfully',
      product: updatedProduct
    });
  } catch (error) {
    res.status(500).json({ message: 'Server error', error: error.message });
  }
};

// Delete a product by ID (admin only)
const deleteProduct = async (req, res) => {
  try {
    const { id } = req.params;

    // Check if product exists
    const product = await Product.findByPk(id);
    if (!product) {
      return res.status(404).json({ message: 'Product not found' });
    }

    // Soft delete by setting isActive to false (in a real app you might want hard delete)
    await Product.update({ isActive: false }, { where: { id } });

    res.status(200).json({
      success: true,
      message: 'Product deactivated successfully'
    });
  } catch (error) {
    res.status(500).json({ message: 'Server error', error: error.message });
  }
};

// Get admin dashboard stats
const getAdminStats = async (req, res) => {
  try {
    // Get counts
    const totalProducts = await Product.count();
    const activeProducts = await Product.count({ where: { isActive: true } });
    const inactiveProducts = await Product.count({ where: { isActive: false } });
    const totalOrders = await Order.count();
    const pendingOrders = await Order.count({ where: { status: 'pending' } });
    const totalUsers = await User.count();
    const activeUsers = await User.count({ where: { isActive: true } });

    // Get recent orders
    const recentOrders = await Order.findAll({
      limit: 5,
      order: [['createdAt', 'DESC']],
      include: [{
        model: User,
        attributes: ['id', 'firstName', 'lastName', 'email']
      }]
    });

    // Get top selling products (in a real app, this would be based on order data)
    const topProducts = await Product.findAll({
      where: { isActive: true },
      limit: 5,
      order: [['numReviews', 'DESC']] // Just using reviews as a proxy for now
    });

    res.status(200).json({
      success: true,
      stats: {
        totalProducts,
        activeProducts,
        inactiveProducts,
        totalOrders,
        pendingOrders,
        totalUsers,
        activeUsers
      },
      recentOrders,
      topProducts
    });
  } catch (error) {
    res.status(500).json({ message: 'Server error', error: error.message });
  }
};

module.exports = {
  getAllProducts,
  getProductById,
  createProduct,
  updateProduct,
  deleteProduct,
  getAdminStats
};