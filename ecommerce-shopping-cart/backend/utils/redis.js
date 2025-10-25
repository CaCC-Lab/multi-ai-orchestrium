const redis = require('redis');

// Create Redis client
const client = redis.createClient({
  url: process.env.REDIS_URL || 'redis://localhost:6379'
});

// Handle Redis connection errors
client.on('error', (err) => {
  console.error('Redis Client Error', err);
});

// Connect to Redis
client.connect()
  .then(() => {
    console.log('Connected to Redis');
  })
  .catch(err => {
    console.error('Failed to connect to Redis', err);
  });

// Cache middleware
const cache = async (req, res, next) => {
  // Only cache GET requests
  if (req.method !== 'GET') {
    return next();
  }

  // Generate cache key
  const key = req.originalUrl || req.url;
  
  try {
    // Try to get from cache
    const cachedData = await client.get(key);
    
    if (cachedData) {
      // Send cached data
      return res.json(JSON.parse(cachedData));
    }
    
    // If not in cache, continue to route handler
    // Then cache the result before sending
    const originalJson = res.json;
    res.json = function(data) {
      // Cache for 300 seconds (5 minutes)
      client.setEx(key, 300, JSON.stringify(data));
      originalJson.call(this, data);
    };
    
    next();
  } catch (error) {
    console.error('Cache error:', error);
    next();
  }
};

// Cache specific data with custom TTL
const cacheData = async (key, data, ttl = 300) => {
  try {
    await client.setEx(key, ttl, JSON.stringify(data));
  } catch (error) {
    console.error('Error caching data:', error);
  }
};

// Get cached data
const getCachedData = async (key) => {
  try {
    const data = await client.get(key);
    return data ? JSON.parse(data) : null;
  } catch (error) {
    console.error('Error getting cached data:', error);
    return null;
  }
};

// Clear specific cache
const clearCache = async (key) => {
  try {
    await client.del(key);
  } catch (error) {
    console.error('Error clearing cache:', error);
  }
};

// Clear pattern (Redis doesn't support pattern deletion by default, so we use a workaround)
const clearCachePattern = async (pattern) => {
  try {
    const keys = await client.keys(pattern);
    if (keys.length > 0) {
      await client.del(keys);
    }
  } catch (error) {
    console.error('Error clearing cache pattern:', error);
  }
};

module.exports = {
  client,
  cache,
  cacheData,
  getCachedData,
  clearCache,
  clearCachePattern
};