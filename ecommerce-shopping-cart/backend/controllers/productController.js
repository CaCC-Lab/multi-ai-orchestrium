const { Op } = require('sequelize');
const Product = require('../models/Product');
const { convertPrice, getSupportedCurrencies } = require('../utils/currencies');
const { cacheData, getCachedData, clearCachePattern } = require('../utils/redis');

/**
 * @swagger
 * components:
 *   schemas:
 *     Product:
 *       type: object
 *       required:
 *         - name
 *         - price
 *         - description
 *       properties:
 *         id:
 *           type: integer
 *           description: The auto-generated id of the product
 *           example: 1
 *         name:
 *           type: string
 *           description: Product name
 *           example: Wireless Headphones
 *         description:
 *           type: string
 *           description: Product description
 *           example: High-quality wireless headphones with noise cancellation
 *         price:
 *           type: number
 *           description: Product price
 *           example: 199.99
 *         category:
 *           type: string
 *           description: Product category
 *           example: Electronics
 *         brand:
 *           type: string
 *           description: Product brand
 *           example: SoundTech
 *         image:
 *           type: string
 *           description: Product image URL
 *           example: https://example.com/image.jpg
 *         countInStock:
 *           type: integer
 *           description: Number in stock
 *           example: 10
 *         rating:
 *           type: number
 *           description: Product rating
 *           example: 4.5
 *         numReviews:
 *           type: integer
 *           description: Number of reviews
 *           example: 15
 *         isFeatured:
 *           type: boolean
 *           description: Whether product is featured
 *           example: true
 *         currency:
 *           type: string
 *           description: Currency for the price
 *           example: USD
 *       example:
 *         id: 1
 *         name: Wireless Headphones
 *         description: High-quality wireless headphones with noise cancellation
 *         price: 199.99
 *         category: Electronics
 *         brand: SoundTech
 *         image: https://example.com/image.jpg
 *         countInStock: 10
 *         rating: 4.5
 *         numReviews: 15
 *         isFeatured: true
 *         currency: USD
 */

/**
 * @swagger
 * tags:
 *   name: Products
 *   description: Product management
 */

/**
 * @swagger
 * components:
 *   securitySchemes:
 *     bearerAuth:
 *       type: http
 *       scheme: bearer
 *       bearerFormat: JWT
 */

/**
 * @swagger
 * /products:
 *   get:
 *     summary: Get all products
 *     tags: [Products]
 *     parameters:
 *       - in: query
 *         name: keyword
 *         schema:
 *           type: string
 *         description: Product keyword for search
 *       - in: query
 *         name: pageNumber
 *         schema:
 *           type: integer
 *         description: Page number for pagination
 *       - in: query
 *         name: currency
 *         schema:
 *           type: string
 *           default: USD
 *         description: Currency for pricing
 *     responses:
 *       200:
 *         description: List of products
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 products:
 *                   type: array
 *                   items:
 *                     $ref: '#/components/schemas/Product'
 *                 page:
 *                   type: integer
 *                   example: 1
 *                 pages:
 *                   type: integer
 *                   example: 5
 *                 count:
 *                   type: integer
 *                   example: 50
 *       400:
 *         description: Invalid currency
 */
exports.getProducts = async (req, res) => {
  try {
    const pageSize = 10;
    const page = Number(req.query.pageNumber) || 1;
    const currency = req.query.currency || 'USD';
    const keyword = req.query.keyword || '';
    
    // Validate currency
    const supportedCurrencies = getSupportedCurrencies();
    if (!supportedCurrencies.includes(currency)) {
      return res.status(400).json({ message: 'Invalid currency' });
    }

    // Generate cache key
    const cacheKey = `products:${keyword}:${page}:${pageSize}:${currency}`;
    
    // Try to get from cache first
    let result = await getCachedData(cacheKey);
    if (result) {
      return res.json(result);
    }

    const whereClause = keyword 
      ? { name: { [Op.iLike]: `%${keyword}%` } } 
      : {};

    const count = await Product.count({ where: whereClause });
    let products = await Product.findAll({
      where: whereClause,
      limit: pageSize,
      offset: pageSize * (page - 1),
      order: [['createdAt', 'DESC']]
    });

    // Convert prices to requested currency
    if (currency !== 'USD') {
      products = products.map(product => {
        const convertedProduct = product.toJSON();
        convertedProduct.price = convertPrice(parseFloat(convertedProduct.price), 'USD', currency);
        convertedProduct.currency = currency;
        return convertedProduct;
      });
    }

    result = {
      products,
      page,
      pages: Math.ceil(count / pageSize),
      count,
      currency
    };

    // Cache the result (cache for 10 minutes)
    await cacheData(cacheKey, result, 600);

    res.json(result);
  } catch (error) {
    console.error(error);
    res.status(500).json({ message: 'Server error' });
  }
};

/**
 * @swagger
 * /products/{id}:
 *   get:
 *     summary: Get product by ID
 *     tags: [Products]
 *     parameters:
 *       - in: path
 *         name: id
 *         schema:
 *           type: integer
 *         required: true
 *         description: Product ID
 *       - in: query
 *         name: currency
 *         schema:
 *           type: string
 *           default: USD
 *         description: Currency for pricing
 *     responses:
 *       200:
 *         description: Product retrieved successfully
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/Product'
 *       400:
 *         description: Invalid currency
 *       404:
 *         description: Product not found
 */
exports.getProductById = async (req, res) => {
  try {
    const currency = req.query.currency || 'USD';
    
    // Validate currency
    const supportedCurrencies = getSupportedCurrencies();
    if (!supportedCurrencies.includes(currency)) {
      return res.status(400).json({ message: 'Invalid currency' });
    }

    // Generate cache key
    const cacheKey = `product:${req.params.id}:${currency}`;
    
    // Try to get from cache first
    let product = await getCachedData(cacheKey);
    if (product) {
      return res.json(product);
    }

    let dbProduct = await Product.findByPk(req.params.id);

    if (dbProduct) {
      product = dbProduct.toJSON();
      
      // Convert price to requested currency
      if (currency !== 'USD') {
        product.price = convertPrice(parseFloat(product.price), 'USD', currency);
        product.currency = currency;
      }
      
      // Cache the result (cache for 30 minutes)
      await cacheData(cacheKey, product, 1800);
      
      res.json(product);
    } else {
      res.status(404).json({ message: 'Product not found' });
    }
  } catch (error) {
    console.error(error);
    res.status(500).json({ message: 'Server error' });
  }
};

// @desc    Delete a product
// @route   DELETE /api/products/:id
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

// @desc    Create a product
// @route   POST /api/products
// @access  Private/Admin
exports.createProduct = async (req, res) => {
  try {
    const product = await Product.create({
      name: 'Sample name',
      price: 0,
      user: req.user.id,
      image: '/images/sample.jpg',
      brand: 'Sample brand',
      category: 'Sample category',
      countInStock: 0,
      numReviews: 0,
      description: 'Sample description',
    });

    // Clear related cache entries
    await clearCachePattern(`products:*`); // Clear product list cache
    
    res.status(201).json(product);
  } catch (error) {
    console.error(error);
    res.status(500).json({ message: 'Server error' });
  }
};

// @desc    Update a product
// @route   PUT /api/products/:id
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

// @desc    Create new review
// @route   POST /api/products/:id/reviews
// @access  Private
exports.createProductReview = async (req, res) => {
  try {
    const { rating, comment } = req.body;

    const product = await Product.findByPk(req.params.id);

    if (product) {
      const alreadyReviewed = product.reviews.find(
        (r) => r.user.toString() === req.user.id.toString()
      );

      if (alreadyReviewed) {
        res.status(400).json({ message: 'Product already reviewed' });
        return;
      }

      const review = {
        name: req.user.name,
        rating: Number(rating),
        comment,
        user: req.user.id,
      };

      product.reviews.push(review);

      product.numReviews = product.reviews.length;

      product.rating =
        product.reviews.reduce((acc, item) => item.rating + acc, 0) /
        product.reviews.length;

      await product.save();

      res.status(201).json({ message: 'Review added' });
    } else {
      res.status(404).json({ message: 'Product not found' });
    }
  } catch (error) {
    console.error(error);
    res.status(500).json({ message: 'Server error' });
  }
};

// @desc    Get top rated products
// @route   GET /api/products/top
// @access  Public
exports.getTopProducts = async (req, res) => {
  try {
    const products = await Product.findAll({
      order: [['rating', 'DESC']],
      limit: 3,
    });

    res.json(products);
  } catch (error) {
    console.error(error);
    res.status(500).json({ message: 'Server error' });
  }
};

// @desc    Get all categories
// @route   GET /api/products/categories
// @access  Public
exports.getCategories = async (req, res) => {
  try {
    const categories = await Product.findAll({
      attributes: ['category'],
      group: ['category']
    });

    const categoryList = categories.map(cat => cat.category);
    res.json(categoryList);
  } catch (error) {
    console.error(error);
    res.status(500).json({ message: 'Server error' });
  }
};

// @desc    Get products by category
// @route   GET /api/products/category/:category
// @access  Public
exports.getProductsByCategory = async (req, res) => {
  try {
    const pageSize = 10;
    const page = Number(req.query.pageNumber) || 1;
    const category = req.params.category;

    const count = await Product.count({ 
      where: { 
        category: { 
          [Op.iLike]: category 
        } 
      } 
    });
    const products = await Product.findAll({
      where: { 
        category: { 
          [Op.iLike]: category 
        } 
      },
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

// @desc    Search products with advanced filters
// @route   GET /api/products/search
// @access  Public
exports.searchProducts = async (req, res) => {
  try {
    const {
      keyword = '',
      category = '',
      brand = '',
      minPrice = 0,
      maxPrice = 0,
      minRating = 0,
      page = 1,
      limit = 10,
      sortBy = 'createdAt',
      sortOrder = 'DESC',
      currency = 'USD'  // Add currency parameter
    } = req.query;

    // Validate currency
    const supportedCurrencies = getSupportedCurrencies();
    if (!supportedCurrencies.includes(currency)) {
      return res.status(400).json({ message: 'Invalid currency' });
    }

    // Build where clause
    let whereClause = {};
    
    if (keyword) {
      whereClause.name = { [Op.iLike]: `%${keyword}%` };
    }
    
    if (category && category !== 'all') {
      whereClause.category = { [Op.iLike]: category };
    }
    
    if (brand && brand !== 'all') {
      whereClause.brand = { [Op.iLike]: brand };
    }
    
    if (minPrice > 0 || maxPrice > 0) {
      // Convert prices to USD for database query
      const minPriceUSD = convertPrice(parseFloat(minPrice), currency, 'USD');
      const maxPriceUSD = convertPrice(parseFloat(maxPrice), currency, 'USD');
      
      whereClause.price = {};
      if (minPrice > 0) whereClause.price[Op.gte] = minPriceUSD;
      if (maxPrice > 0) whereClause.price[Op.lte] = maxPriceUSD;
    }
    
    if (minRating > 0) {
      whereClause.rating = { [Op.gte]: minRating };
    }

    // Build order clause
    const orderClause = [[sortBy, sortOrder]];
    
    // Count total for pagination
    const count = await Product.count({ where: whereClause });
    
    // Fetch products
    let products = await Product.findAll({
      where: whereClause,
      limit: parseInt(limit),
      offset: parseInt(limit) * (parseInt(page) - 1),
      order: orderClause
    });

    // Convert prices to requested currency
    if (currency !== 'USD') {
      products = products.map(product => {
        const convertedProduct = product.toJSON();
        convertedProduct.price = convertPrice(parseFloat(convertedProduct.price), 'USD', currency);
        convertedProduct.currency = currency;
        return convertedProduct;
      });
    }

    res.json({
      products,
      page: parseInt(page),
      pages: Math.ceil(count / parseInt(limit)),
      count,
      currency
    });
  } catch (error) {
    console.error(error);
    res.status(500).json({ message: 'Server error' });
  }
};