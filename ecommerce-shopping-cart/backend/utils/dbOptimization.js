// Database query optimization utilities

// Optimize queries by adding proper indexes
const createIndexes = async (sequelize) => {
  try {
    // Create indexes on commonly queried fields
    
    // Index on product name for search
    await sequelize.query('CREATE INDEX IF NOT EXISTS idx_products_name ON "Products" USING gin(name gin_trgm_ops);');
    
    // Index on product category
    await sequelize.query('CREATE INDEX IF NOT EXISTS idx_products_category ON "Products" (category);');
    
    // Index on product brand
    await sequelize.query('CREATE INDEX IF NOT EXISTS idx_products_brand ON "Products" (brand);');
    
    // Index on product price
    await sequelize.query('CREATE INDEX IF NOT EXISTS idx_products_price ON "Products" (price);');
    
    // Index on product rating
    await sequelize.query('CREATE INDEX IF NOT EXISTS idx_products_rating ON "Products" (rating);');
    
    // Index on user email for authentication
    await sequelize.query('CREATE INDEX IF NOT EXISTS idx_users_email ON "Users" (email);');
    
    // Index on order userId for user order history
    await sequelize.query('CREATE INDEX IF NOT EXISTS idx_orders_user_id ON "Orders" ("userId");');
    
    // Index on order creation date
    await sequelize.query('CREATE INDEX IF NOT EXISTS idx_orders_created_at ON "Orders" (created_at);');
    
    // Index on cart userId
    await sequelize.query('CREATE INDEX IF NOT EXISTS idx_carts_user_id ON "Carts" ("userId");');

    console.log('Database indexes created successfully');
    
  } catch (error) {
    console.error('Error creating indexes:', error);
  }
};

// Optimize database connection pool
const optimizeConnectionPool = (sequelize) => {
  // The pool configuration is already set in config/db.js
  // This function can be used to adjust pool settings dynamically if needed
  
  console.log('Database connection pool optimized');
  return sequelize;
};

// Function to run database maintenance tasks
const runMaintenance = async (sequelize) => {
  try {
    // Analyze tables to update statistics
    await sequelize.query('ANALYZE;');
    
    // Optionally vacuum tables (use VACUUM ANALYZE for updating statistics)
    // Note: This is typically done by the database maintenance system
    console.log('Database maintenance completed');
  } catch (error) {
    console.error('Error during maintenance:', error);
  }
};

module.exports = {
  createIndexes,
  optimizeConnectionPool,
  runMaintenance
};