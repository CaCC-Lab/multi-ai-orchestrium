const app = require('./app');
const sequelize = require('./config/db');

const PORT = process.env.PORT || 5000;

// Start server after database connection
const startServer = async () => {
  try {
    await sequelize.sync(); // This will create tables if they don't exist
    app.listen(PORT, () => {
      console.log(`Server running on port ${PORT}`);
      console.log(`Swagger UI available at http://localhost:${PORT}/api-docs`);
    });
  } catch (error) {
    console.error('Unable to start server:', error);
  }
};

startServer();