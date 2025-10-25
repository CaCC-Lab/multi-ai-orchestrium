const { createClient } = require('redis');
const { getEnv } = require('./env');
const { logger } = require('./logger');

let client;

const getRedisClient = () => {
  if (client) {
    return client;
  }

  const url = getEnv('REDIS_URL', 'redis://localhost:6379');

  client = createClient({ url });

  client.on('error', (err) => {
    logger.error('Redis client error', { err });
  });

  client.on('connect', () => {
    if (getEnv('NODE_ENV') !== 'test') {
      logger.info('Connected to Redis');
    }
  });

  client.connect().catch((err) => {
    logger.error('Unable to connect to Redis', { err });
  });

  return client;
};

module.exports = {
  getRedisClient,
};
