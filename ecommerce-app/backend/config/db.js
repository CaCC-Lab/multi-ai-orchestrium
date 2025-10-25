const { Sequelize } = require('sequelize');
const dotenv = require('dotenv');

dotenv.config();

const ENVIRONMENT = process.env.NODE_ENV || 'development';

const createSequelizeInstance = () => {
  if (ENVIRONMENT === 'test') {
    return new Sequelize('sqlite::memory:', {
      logging: false
    });
  }

  if (process.env.DATABASE_URL) {
    return new Sequelize(process.env.DATABASE_URL, {
      dialect: 'postgres',
      logging: ENVIRONMENT === 'development' ? console.log : false,
      dialectOptions: {
        ssl: process.env.DB_SSL === 'true'
      },
      pool: {
        max: 5,
        min: 0,
        acquire: 30000,
        idle: 10000
      }
    });
  }

  return new Sequelize(
    process.env.DB_NAME,
    process.env.DB_USER,
    process.env.DB_PASSWORD,
    {
      host: process.env.DB_HOST,
      dialect: 'postgres',
      port: process.env.DB_PORT,
      logging: ENVIRONMENT === 'development' ? console.log : false,
      pool: {
        max: 5,
        min: 0,
        acquire: 30000,
        idle: 10000
      }
    }
  );
};

const sequelize = createSequelizeInstance();

const authenticateDB = async () => {
  try {
    await sequelize.authenticate();
    if (ENVIRONMENT !== 'test') {
      console.log('Database connected successfully with Sequelize');
    }
  } catch (error) {
    console.error('Unable to connect to the database:', error);
    if (ENVIRONMENT !== 'test') {
      throw error;
    }
  }
};

if (ENVIRONMENT !== 'test') {
  authenticateDB();
}

module.exports = sequelize;
module.exports.authenticateDB = authenticateDB;