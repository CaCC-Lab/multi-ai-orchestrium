// backend/utils/cache.js
const redis = require('redis');
require('dotenv').config();

// Only connect to Redis in non-test environments
let client;

if (process.env.NODE_ENV !== 'test') {
  client = redis.createClient({
    host: process.env.REDIS_HOST || 'localhost',
    port: process.env.REDIS_PORT || 6379,
  });

  client.on('error', (err) => {
    console.error('Redis Client Error', err);
  });

  client.connect();
} else {
  // Mock Redis client for testing
  client = {
    get: jest.fn(),
    setEx: jest.fn(),
    del: jest.fn(),
    flushAll: jest.fn(),
    connect: jest.fn()
  };
}

// Cache middleware
const cacheMiddleware = async (req, res, next) => {
  try {
    // Generate cache key based on URL and query parameters
    const key = req.originalUrl;
    const cachedData = await client.get(key);
    
    if (cachedData) {
      console.log(`Cache hit for: ${key}`);
      return res.json(JSON.parse(cachedData));
    }
    
    console.log(`Cache miss for: ${key}`);
    
    // Override res.json to capture response data
    const originalJson = res.json;
    res.json = function (data) {
      // Cache the response data
      client.setEx(key, 300, JSON.stringify(data)); // Cache for 5 minutes
      originalJson.call(this, data);
    };
    
    next();
  } catch (error) {
    console.error('Cache middleware error:', error);
    next();
  }
};

// Cache specific data
const setCache = async (key, data, expiration = 300) => {
  try {
    if (process.env.NODE_ENV !== 'test') {
      await client.setEx(key, expiration, JSON.stringify(data));
    } else {
      // Mock the cache operation in test environments
      await client.setEx(key, expiration, JSON.stringify(data));
    }
  } catch (error) {
    console.error('Set cache error:', error);
  }
};

// Get cached data
const getCache = async (key) => {
  try {
    const data = await client.get(key);
    return data ? JSON.parse(data) : null;
  } catch (error) {
    console.error('Get cache error:', error);
    return null;
  }
};

// Delete cached data
const deleteCache = async (key) => {
  try {
    await client.del(key);
  } catch (error) {
    console.error('Delete cache error:', error);
  }
};

// Clear all cache
const clearCache = async () => {
  try {
    await client.flushAll();
  } catch (error) {
    console.error('Clear cache error:', error);
  }
};

module.exports = {
  cacheMiddleware,
  setCache,
  getCache,
  deleteCache,
  clearCache,
  client
};