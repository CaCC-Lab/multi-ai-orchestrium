const { Product } = require('../models');
const { Op } = require('sequelize');
const { convertCurrency, SUPPORTED_CURRENCIES } = require('../utils/currency');
const { getCache, setCache } = require('../utils/cache');

// Get all products with search and filters
const getProducts = async (req, res) => {
  try {
    const {
      page = 1,
      limit = 10,
      search = '',
      category = '',
      minPrice = 0,
      maxPrice = 0,
      brand = '',
      sortBy = 'createdAt',
      sortOrder = 'DESC',
      inStock = false,
      currency = 'USD'
    } = req.query;

    // Validate currency
    if (currency && !SUPPORTED_CURRENCIES.includes(currency)) {
      return res.status(400).json({ message: `Unsupported currency: ${currency}` });
    }

    // Create cache key based on query parameters
    const cacheKey = `products:${page}:${limit}:${search}:${category}:${minPrice}:${maxPrice}:${brand}:${sortBy}:${sortOrder}:${inStock}:${currency}`;
    
    // Try to get from cache first
    const cachedData = await getCache(cacheKey);
    if (cachedData) {
      console.log(`Serving from cache: ${cacheKey}`);
      return res.status(200).json(cachedData);
    }

    // Build query conditions
    let where = { isActive: true };
    
    if (search) {
      where.name = { [Op.iLike]: `%${search}%` };
    }
    
    if (category) {
      where.category = category;
    }
    
    if (brand) {
      where.brand = brand;
    }
    
    if (parseFloat(minPrice) > 0) {
      where.price = { ...where.price, [Op.gte]: parseFloat(minPrice) };
    }
    
    if (parseFloat(maxPrice) > 0) {
      where.price = { ...where.price, [Op.lte]: parseFloat(maxPrice) };
    }
    
    if (inStock === 'true') {
      where.stockQuantity = { [Op.gt]: 0 };
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
      attributes: { exclude: ['createdAt', 'updatedAt'] } // Exclude timestamps for now
    });

    // Convert prices to requested currency if different from USD
    let convertedProducts = products.rows;
    if (currency && currency !== 'USD') {
      convertedProducts = products.rows.map(product => ({
        ...product.toJSON(),
        price: convertCurrency(parseFloat(product.price), 'USD', currency)
      }));
    }

    // Calculate pagination metadata
    const totalPages = Math.ceil(products.count / limit);
    const hasNextPage = page < totalPages;
    const hasPrevPage = page > 1;

    const response = {
      success: true,
      count: products.count,
      currentPage: parseInt(page),
      totalPages,
      hasNextPage,
      hasPrevPage,
      currency,
      products: convertedProducts
    };

    // Cache the result for 10 minutes
    await setCache(cacheKey, response, 600);

    res.status(200).json(response);
  } catch (error) {
    res.status(500).json({ message: 'Server error', error: error.message });
  }
};

// Get a single product by ID
const getProductById = async (req, res) => {
  try {
    const { id } = req.params;
    const { currency = 'USD' } = req.query;

    // Validate currency
    if (currency && !SUPPORTED_CURRENCIES.includes(currency)) {
      return res.status(400).json({ message: `Unsupported currency: ${currency}` });
    }

    // Create cache key
    const cacheKey = `product:${id}:${currency}`;
    
    // Try to get from cache first
    const cachedData = await getCache(cacheKey);
    if (cachedData) {
      console.log(`Serving from cache: ${cacheKey}`);
      return res.status(200).json(cachedData);
    }

    const product = await Product.findByPk(id, {
      attributes: { exclude: ['createdAt', 'updatedAt'] }
    });

    if (!product || !product.isActive) {
      return res.status(404).json({ message: 'Product not found' });
    }

    // Convert price to requested currency if different from USD
    let convertedProduct = product.toJSON();
    if (currency && currency !== 'USD') {
      convertedProduct = {
        ...convertedProduct,
        price: convertCurrency(parseFloat(product.price), 'USD', currency)
      };
    }

    const response = {
      success: true,
      currency,
      product: convertedProduct
    };

    // Cache the result for 30 minutes
    await setCache(cacheKey, response, 1800);

    res.status(200).json(response);
  } catch (error) {
    res.status(500).json({ message: 'Server error', error: error.message });
  }
};

// Get supported currencies
const getSupportedCurrencies = async (req, res) => {
  res.status(200).json({
    success: true,
    currencies: SUPPORTED_CURRENCIES
  });
};

// Get product categories (with caching)
const getCategories = async (req, res) => {
  try {
    // Create cache key
    const cacheKey = 'product:categories';
    
    // Try to get from cache first
    const cachedData = await getCache(cacheKey);
    if (cachedData) {
      console.log(`Serving from cache: ${cacheKey}`);
      return res.status(200).json(cachedData);
    }

    const categories = await Product.findAll({
      attributes: ['category'],
      group: ['category'],
      where: { isActive: true }
    });

    const categoryList = categories.map(cat => cat.category).filter(cat => cat);

    const response = {
      success: true,
      categories: categoryList
    };

    // Cache the result for 1 hour
    await setCache(cacheKey, response, 3600);

    res.status(200).json(response);
  } catch (error) {
    res.status(500).json({ message: 'Server error', error: error.message });
  }
};

// Get product brands (with caching)
const getBrands = async (req, res) => {
  try {
    // Create cache key
    const cacheKey = 'product:brands';
    
    // Try to get from cache first
    const cachedData = await getCache(cacheKey);
    if (cachedData) {
      console.log(`Serving from cache: ${cacheKey}`);
      return res.status(200).json(cachedData);
    }

    const brands = await Product.findAll({
      attributes: ['brand'],
      group: ['brand'],
      where: { isActive: true }
    });

    const brandList = brands.map(brand => brand.brand).filter(brand => brand);

    const response = {
      success: true,
      brands: brandList
    };

    // Cache the result for 1 hour
    await setCache(cacheKey, response, 3600);

    res.status(200).json(response);
  } catch (error) {
    res.status(500).json({ message: 'Server error', error: error.message });
  }
};

module.exports = {
  getProducts,
  getProductById,
  getSupportedCurrencies,
  getCategories,
  getBrands
};