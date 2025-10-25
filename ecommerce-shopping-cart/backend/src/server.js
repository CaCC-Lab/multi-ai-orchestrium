const { loadEnv, getEnv } = require('./config/env');
const { connectDatabase } = require('./config/database');
const { logger } = require('./config/logger');
const { getRedisClient } = require('./config/redis');
const app = require('./app');
const { initializeModels } = require('../models');

const startServer = async () => {
  try {
    loadEnv();
    await connectDatabase();
    await initializeModels();
    await getRedisClient();

    const port = getEnv('PORT', 5000);
    app.listen(port, () => {
      logger.info(`Server is running on port ${port}`);
    });
  } catch (error) {
    logger.error('Failed to start server', { error });
    process.exit(1);
  }
};

startServer();
