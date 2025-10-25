const redis = require('redis');
require('dotenv').config();

// Initialize Redis client
const redisClient = redis.createClient({
  url: process.env.REDIS_URL || 'redis://localhost:6379'
});

redisClient.on('error', (err) => {
  console.error('Redis Client Error', err);
});

redisClient.connect().catch(console.error);

// Cache middleware
const cache = async (req, res, next) => {
  try {
    const { query, params } = req;
    const cacheKey = `${req.path}:${JSON.stringify(query)}:${JSON.stringify(params)}`;
    
    const cachedData = await redisClient.get(cacheKey);
    
    if (cachedData) {
      console.log(`Cache hit for key: ${cacheKey}`);
      return res.json(JSON.parse(cachedData));
    }
    
    console.log(`Cache miss for key: ${cacheKey}`);
    
    // Override res.json to cache the response
    const originalJson = res.json;
    res.json = function (data) {
      // Cache for 10 minutes for most data, 1 hour for products
      const expiry = req.path.includes('/products') ? 3600 : 600;
      
      redisClient.setEx(cacheKey, expiry, JSON.stringify(data)).catch(console.error);
      originalJson.call(this, data);
    };
    
    next();
  } catch (error) {
    console.error('Cache error:', error);
    next();
  }
};

// Cache for specific routes
const cacheForProducts = async (req, res, next) => {
  try {
    const cacheKey = `products:${req.originalUrl}`;
    
    const cachedData = await redisClient.get(cacheKey);
    
    if (cachedData) {
      console.log(`Cache hit for products: ${cacheKey}`);
      return res.json(JSON.parse(cachedData));
    }
    
    console.log(`Cache miss for products: ${cacheKey}`);
    
    // Override res.json to cache the response
    const originalJson = res.json;
    res.json = function (data) {
      redisClient.setEx(cacheKey, 3600, JSON.stringify(data)).catch(console.error); // 1 hour
      originalJson.call(this, data);
    };
    
    next();
  } catch (error) {
    console.error('Product cache error:', error);
    next();
  }
};

// Cache for specific product
const cacheForProduct = async (req, res, next) => {
  try {
    const productId = req.params.id;
    const cacheKey = `product:${productId}`;
    
    const cachedData = await redisClient.get(cacheKey);
    
    if (cachedData) {
      console.log(`Cache hit for product: ${cacheKey}`);
      return res.json(JSON.parse(cachedData));
    }
    
    console.log(`Cache miss for product: ${cacheKey}`);
    
    // Override res.json to cache the response
    const originalJson = res.json;
    res.json = function (data) {
      redisClient.setEx(cacheKey, 3600, JSON.stringify(data)).catch(console.error); // 1 hour
      originalJson.call(this, data);
    };
    
    next();
  } catch (error) {
    console.error('Product cache error:', error);
    next();
  }
};

// Clear cache for specific key
const clearCache = async (pattern) => {
  try {
    const keys = await redisClient.keys(pattern);
    if (keys.length > 0) {
      await redisClient.del(keys);
    }
  } catch (error) {
    console.error('Error clearing cache:', error);
  }
};

// Clear product cache when product is updated
const clearProductCache = async (productId) => {
  await clearCache(`product:${productId}`);
  await clearCache('products:*');
};

module.exports = {
  cache,
  cacheForProducts,
  cacheForProduct,
  clearProductCache,
  redisClient
};