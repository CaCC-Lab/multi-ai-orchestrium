module.exports = {
  apps: [
    {
      name: 'ecommerce-app',
      script: './backend/server.js',
      instances: 'max', // Use all CPU cores
      exec_mode: 'cluster',
      env: {
        NODE_ENV: 'development',
        PORT: 5000,
        DB_HOST: 'localhost',
        DB_NAME: 'ecommerce_db',
        DB_USERNAME: 'postgres',
        DB_PASSWORD: 'your_db_password',
        JWT_SECRET: 'your_jwt_secret_key_here',
        STRIPE_API_KEY: 'your_stripe_api_key',
        SENDGRID_API_KEY: 'your_sendgrid_api_key',
        REDIS_URL: 'redis://localhost:6379'
      },
      env_production: {
        NODE_ENV: 'production',
        PORT: process.env.PORT || 5000,
        DB_HOST: process.env.DB_HOST,
        DB_NAME: process.env.DB_NAME,
        DB_USERNAME: process.env.DB_USERNAME,
        DB_PASSWORD: process.env.DB_PASSWORD,
        JWT_SECRET: process.env.JWT_SECRET,
        STRIPE_API_KEY: process.env.STRIPE_API_KEY,
        SENDGRID_API_KEY: process.env.SENDGRID_API_KEY,
        REDIS_URL: process.env.REDIS_URL
      }
    }
  ]
};