const redis = require('redis');
const dotenv = require('dotenv');

dotenv.config();

// Create Redis client
const client = redis.createClient({
  socket: {
    host: process.env.REDIS_HOST || 'localhost',
    port: process.env.REDIS_PORT || 6379
  }
});

let isClientReady = false;

// Handle Redis connection errors
client.on('error', (err) => {
  console.error('Redis Client Error:', err);
});

// Connect to Redis
client.connect().then(() => {
  isClientReady = true;
  console.log('Connected to Redis');
}).catch((err) => {
  console.error('Failed to connect to Redis:', err);
});

// Cache middleware function
const cache = (duration) => {
  return async (req, res, next) => {
    try {
      // Generate cache key from URL and query parameters
      const key = `cache:${req.originalUrl}`;
      
      // Try to get data from cache
      if (!isClientReady) {
        return next();
      }

      const cachedData = await client.get(key);
      
      if (cachedData) {
        // Serve from cache
        console.log(`Serving from cache: ${key}`);
        return res.json(JSON.parse(cachedData));
      }
      
      // If not in cache, continue to route handler
      // Override res.json to cache the response
      const originalJson = res.json;
      res.json = function(data) {
        // Cache the response
        if (isClientReady) {
          client.setEx(key, duration, JSON.stringify(data));
          console.log(`Caching: ${key} for ${duration} seconds`);
        }
        originalJson.call(this, data);
      };
      
      next();
    } catch (error) {
      console.error('Cache error:', error);
      next();
    }
  };
};

// Cache a specific value
const setCache = async (key, value, duration = 3600) => {
  try {
    if (!isClientReady) {
      return;
    }

    await client.setEx(key, duration, JSON.stringify(value));
    console.log(`Cached key: ${key} for ${duration} seconds`);
  } catch (error) {
    console.error('Set cache error:', error);
  }
};

// Get cached value
const getCache = async (key) => {
  try {
    if (!isClientReady) {
      return null;
    }

    const data = await client.get(key);
    return data ? JSON.parse(data) : null;
  } catch (error) {
    console.error('Get cache error:', error);
    return null;
  }
};

// Delete cached value
const deleteCache = async (key) => {
  try {
    if (!isClientReady) {
      return;
    }

    await client.del(key);
    console.log(`Deleted cache key: ${key}`);
  } catch (error) {
    console.error('Delete cache error:', error);
  }
};

// Clear all cache
const clearCache = async () => {
  try {
    if (!isClientReady) {
      return;
    }

    await client.flushAll();
    console.log('Cleared all cache');
  } catch (error) {
    console.error('Clear cache error:', error);
  }
};

module.exports = {
  cache,
  setCache,
  getCache,
  deleteCache,
  clearCache
};