const { Op } = require('sequelize');
const Product = require('../models/Product');
const User = require('../models/User');
const Order = require('../models/Order');
const { clearCachePattern } = require('../utils/redis');

// @desc    Get all products - Admin only
// @route   GET /api/admin/products
// @access  Private/Admin
exports.getProducts = async (req, res) => {
  try {
    const pageSize = 10;
    const page = Number(req.query.pageNumber) || 1;

    const count = await Product.count();
    const products = await Product.findAll({
      limit: pageSize,
      offset: pageSize * (page - 1),
      order: [['createdAt', 'DESC']]
    });

    res.json({
      products,
      page,
      pages: Math.ceil(count / pageSize),
      count,
    });
  } catch (error) {
    console.error(error);
    res.status(500).json({ message: 'Server error' });
  }
};

// @desc    Create product - Admin only
// @route   POST /api/admin/products
// @access  Private/Admin
exports.createProduct = async (req, res) => {
  try {
    const product = await Product.create({
      user: req.user.id,
      name: 'Sample Name',
      price: 0,
      brand: 'Sample Brand',
      image: '/images/sample.jpg',
      category: 'Sample Category',
      countInStock: 0,
      numReviews: 0,
      description: 'Sample Description',
    });

    // Clear related cache entries
    await clearCachePattern(`products:*`); // Clear product list cache
    
    res.status(201).json(product);
  } catch (error) {
    console.error(error);
    res.status(500).json({ message: 'Server error' });
  }
};

// @desc    Update product - Admin only
// @route   PUT /api/admin/products/:id
// @access  Private/Admin
exports.updateProduct = async (req, res) => {
  try {
    const {
      name,
      price,
      description,
      image,
      images,
      brand,
      category,
      countInStock,
    } = req.body;

    const product = await Product.findByPk(req.params.id);

    if (product) {
      product.name = name || product.name;
      product.price = price || product.price;
      product.description = description || product.description;
      product.image = image || product.image;
      product.images = images || product.images;
      product.brand = brand || product.brand;
      product.category = category || product.category;
      product.countInStock = countInStock || product.countInStock;

      const updatedProduct = await product.save();
      
      // Clear related cache entries
      await clearCachePattern(`product:${req.params.id}:*`); // Clear specific product cache
      await clearCachePattern(`products:*`); // Clear product list cache

      res.json(updatedProduct);
    } else {
      res.status(404).json({ message: 'Product not found' });
    }
  } catch (error) {
    console.error(error);
    res.status(500).json({ message: 'Server error' });
  }
};

// @desc    Delete product - Admin only
// @route   DELETE /api/admin/products/:id
// @access  Private/Admin
exports.deleteProduct = async (req, res) => {
  try {
    const product = await Product.findByPk(req.params.id);

    if (product) {
      await product.destroy();
      
      // Clear related cache entries
      await clearCachePattern(`product:${req.params.id}:*`); // Clear specific product cache
      await clearCachePattern(`products:*`); // Clear product list cache
      
      res.json({ message: 'Product removed' });
    } else {
      res.status(404).json({ message: 'Product not found' });
    }
  } catch (error) {
    console.error(error);
    res.status(500).json({ message: 'Server error' });
  }
};

// @desc    Get all users - Admin only
// @route   GET /api/admin/users
// @access  Private/Admin
exports.getUsers = async (req, res) => {
  try {
    const pageSize = 10;
    const page = Number(req.query.pageNumber) || 1;

    const count = await User.count();
    const users = await User.findAll({
      attributes: { exclude: ['password'] },
      limit: pageSize,
      offset: pageSize * (page - 1),
      order: [['createdAt', 'DESC']]
    });

    res.json({
      users,
      page,
      pages: Math.ceil(count / pageSize),
      count,
    });
  } catch (error) {
    console.error(error);
    res.status(500).json({ message: 'Server error' });
  }
};

// @desc    Delete user - Admin only
// @route   DELETE /api/admin/users/:id
// @access  Private/Admin
exports.deleteUser = async (req, res) => {
  try {
    const user = await User.findByPk(req.params.id);

    if (user && user.id !== req.user.id) {
      await user.destroy();
      res.json({ message: 'User removed' });
    } else if (user && user.id === req.user.id) {
      res.status(400).json({ message: 'Cannot delete your own account' });
    } else {
      res.status(404).json({ message: 'User not found' });
    }
  } catch (error) {
    console.error(error);
    res.status(500).json({ message: 'Server error' });
  }
};

// @desc    Get user by ID - Admin only
// @route   GET /api/admin/users/:id
// @access  Private/Admin
exports.getUser = async (req, res) => {
  try {
    const user = await User.findByPk(req.params.id, {
      attributes: { exclude: ['password'] }
    });

    if (user) {
      res.json(user);
    } else {
      res.status(404).json({ message: 'User not found' });
    }
  } catch (error) {
    console.error(error);
    res.status(500).json({ message: 'Server error' });
  }
};

// @desc    Update user - Admin only
// @route   PUT /api/admin/users/:id
// @access  Private/Admin
exports.updateUser = async (req, res) => {
  try {
    const user = await User.findByPk(req.params.id);

    if (user) {
      user.name = req.body.name || user.name;
      user.email = req.body.email || user.email;
      user.isAdmin = req.body.isAdmin;

      await user.save();

      res.json({
        id: user.id,
        name: user.name,
        email: user.email,
        isAdmin: user.isAdmin
      });
    } else {
      res.status(404).json({ message: 'User not found' });
    }
  } catch (error) {
    console.error(error);
    res.status(500).json({ message: 'Server error' });
  }
};

// @desc    Get all orders - Admin only
// @route   GET /api/admin/orders
// @access  Private/Admin
exports.getOrders = async (req, res) => {
  try {
    const pageSize = 10;
    const page = Number(req.query.pageNumber) || 1;

    const count = await Order.count();
    const orders = await Order.findAll({
      limit: pageSize,
      offset: pageSize * (page - 1),
      order: [['createdAt', 'DESC']],
      include: [{
        model: User,
        attributes: ['id', 'name', 'email']
      }]
    });

    res.json({
      orders,
      page,
      pages: Math.ceil(count / pageSize),
      count,
    });
  } catch (error) {
    console.error(error);
    res.status(500).json({ message: 'Server error' });
  }
};

// @desc    Get order by ID - Admin only
// @route   GET /api/admin/orders/:id
// @access  Private/Admin
exports.getOrder = async (req, res) => {
  try {
    const order = await Order.findByPk(req.params.id, {
      include: [{
        model: User,
        attributes: ['id', 'name', 'email']
      }]
    });

    if (order) {
      res.json(order);
    } else {
      res.status(404).json({ message: 'Order not found' });
    }
  } catch (error) {
    console.error(error);
    res.status(500).json({ message: 'Server error' });
  }
};

// @desc    Update order - Admin only
// @route   PUT /api/admin/orders/:id
// @access  Private/Admin
exports.updateOrder = async (req, res) => {
  try {
    const order = await Order.findByPk(req.params.id);

    if (order) {
      if (req.body.isPaid !== undefined) {
        order.isPaid = req.body.isPaid;
        if (req.body.isPaid) {
          order.paidAt = Date.now();
        }
      }
      
      if (req.body.isDelivered !== undefined) {
        order.isDelivered = req.body.isDelivered;
        if (req.body.isDelivered) {
          order.deliveredAt = Date.now();
        }
      }

      if (req.body.paymentResult) {
        order.paymentResult = req.body.paymentResult;
      }

      const updatedOrder = await order.save();
      res.json(updatedOrder);
    } else {
      res.status(404).json({ message: 'Order not found' });
    }
  } catch (error) {
    console.error(error);
    res.status(500).json({ message: 'Server error' });
  }
};

// @desc    Delete order - Admin only
// @route   DELETE /api/admin/orders/:id
// @access  Private/Admin
exports.deleteOrder = async (req, res) => {
  try {
    const order = await Order.findByPk(req.params.id);

    if (order) {
      await order.destroy();
      res.json({ message: 'Order removed' });
    } else {
      res.status(404).json({ message: 'Order not found' });
    }
  } catch (error) {
    console.error(error);
    res.status(500).json({ message: 'Server error' });
  }
};

// @desc    Update inventory - Admin only
// @route   PUT /api/admin/products/:id/inventory
// @access  Private/Admin
exports.updateInventory = async (req, res) => {
  try {
    const { countInStock } = req.body;
    const product = await Product.findByPk(req.params.id);

    if (product) {
      product.countInStock = countInStock;
      await product.save();

      res.json({
        id: product.id,
        name: product.name,
        countInStock: product.countInStock
      });
    } else {
      res.status(404).json({ message: 'Product not found' });
    }
  } catch (error) {
    console.error(error);
    res.status(500).json({ message: 'Server error' });
  }
};

// @desc    Get inventory levels - Admin only
// @route   GET /api/admin/inventory
// @access  Private/Admin
exports.getInventoryLevels = async (req, res) => {
  try {
    const lowStockThreshold = req.query.threshold || 5;
    const products = await Product.findAll({
      where: {
        countInStock: {
          [Op.lte]: lowStockThreshold
        }
      },
      order: [['countInStock', 'ASC']]
    });

    res.json(products);
  } catch (error) {
    console.error(error);
    res.status(500).json({ message: 'Server error' });
  }
};

// @desc    Get admin dashboard stats - Admin only
// @route   GET /api/admin/dashboard
// @access  Private/Admin
exports.getDashboardStats = async (req, res) => {
  try {
    const totalProducts = await Product.count();
    const totalUsers = await User.count();
    const totalOrders = await Order.count();
    const deliveredOrders = await Order.count({
      where: { isDelivered: true }
    });
    
    // Calculate total revenue (only for paid orders)
    const paidOrders = await Order.findAll({
      where: { isPaid: true },
      attributes: ['totalPrice']
    });
    
    const totalRevenue = paidOrders.reduce((sum, order) => sum + parseFloat(order.totalPrice), 0);

    res.json({
      totalProducts,
      totalUsers,
      totalOrders,
      deliveredOrders,
      totalRevenue: totalRevenue.toFixed(2)
    });
  } catch (error) {
    console.error(error);
    res.status(500).json({ message: 'Server error' });
  }
};