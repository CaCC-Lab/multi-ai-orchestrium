const sequelize = require('./config/db');
const { User, Product, Order, Cart } = require('./models');

const initDB = async () => {
  try {
    // Test the connection
    await sequelize.authenticate();
    console.log('Database connection has been established successfully.');

    // Sync all models
    await sequelize.sync({ force: false }); // Use { force: true } to drop and recreate tables
    console.log('Models synchronized with database.');
    
    // Close connection
    await sequelize.close();
    console.log('Database connection closed.');
  } catch (error) {
    console.error('Unable to connect to the database:', error);
  }
};

// Run initialization if this file is executed directly
if (require.main === module) {
  initDB();
}

module.exports = initDB;