const { Sequelize } = require('sequelize');
const { getEnv } = require('./env');
const { logger } = require('./logger');

const nodeEnv = getEnv('NODE_ENV', 'development');

let sequelize;

if (nodeEnv === 'test') {
  sequelize = new Sequelize('sqlite::memory:', {
    logging: false,
  });
} else {
  const database = getEnv('DB_NAME', 'ecommerce_db');
  const username = getEnv('DB_USERNAME', 'postgres');
  const password = getEnv('DB_PASSWORD', 'postgres');
  const host = getEnv('DB_HOST', 'localhost');
  const port = getEnv('DB_PORT', 5432);

  sequelize = new Sequelize(database, username, password, {
    host,
    port,
    dialect: 'postgres',
    logging: nodeEnv === 'development' ? (msg) => logger.debug(msg) : false,
    pool: {
      max: Number(getEnv('DB_POOL_MAX', 10)),
      min: Number(getEnv('DB_POOL_MIN', 0)),
      acquire: Number(getEnv('DB_POOL_ACQUIRE', 30000)),
      idle: Number(getEnv('DB_POOL_IDLE', 10000)),
    },
  });
}

const connectDatabase = async () => {
  try {
    await sequelize.authenticate();
    if (getEnv('NODE_ENV') !== 'test') {
      logger.info('Database connection established');
    }
  } catch (error) {
    logger.error('Unable to connect to the database', { error });
    throw error;
  }
};

module.exports = {
  sequelize,
  connectDatabase,
};
