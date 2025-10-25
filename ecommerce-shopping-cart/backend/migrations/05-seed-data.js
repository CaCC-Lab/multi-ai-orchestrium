'use strict';

module.exports = {
  up: async (queryInterface, Sequelize) => {
    // Seed users
    await queryInterface.bulkInsert('Users', [
      {
        name: 'Admin User',
        email: 'admin@example.com',
        password: '$2b$10$8K1p/aW4H8PhOaK9nqP0K.0HqgN0J7Gv8qF0Y.xkZ3Qh0J7Gv8qF0Y', // 'password' hashed
        isAdmin: true,
        createdAt: new Date(),
        updatedAt: new Date()
      },
      {
        name: 'John Doe',
        email: 'john@example.com',
        password: '$2b$10$8K1p/aW4H8PhOaK9nqP0K.0HqgN0J7Gv8qF0Y.xkZ3Qh0J7Gv8qF0Y', // 'password' hashed
        isAdmin: false,
        createdAt: new Date(),
        updatedAt: new Date()
      }
    ]);

    // Seed products
    await queryInterface.bulkInsert('Products', [
      {
        name: 'Wireless Headphones',
        description: 'High-quality wireless headphones with noise cancellation',
        price: 199.99,
        category: 'Electronics',
        brand: 'SoundTech',
        image: 'https://via.placeholder.com/300',
        countInStock: 10,
        rating: 4.5,
        numReviews: 15,
        isFeatured: true,
        currency: 'USD',
        createdAt: new Date(),
        updatedAt: new Date()
      },
      {
        name: 'Smart Watch',
        description: 'Feature-rich smartwatch with health monitoring',
        price: 249.99,
        category: 'Electronics',
        brand: 'TechTime',
        image: 'https://via.placeholder.com/300',
        countInStock: 5,
        rating: 4.2,
        numReviews: 8,
        isFeatured: true,
        currency: 'USD',
        createdAt: new Date(),
        updatedAt: new Date()
      },
      {
        name: 'Cotton T-Shirt',
        description: 'Comfortable cotton t-shirt for everyday wear',
        price: 24.99,
        category: 'Clothing',
        brand: 'FashionPlus',
        image: 'https://via.placeholder.com/300',
        countInStock: 50,
        rating: 4.0,
        numReviews: 12,
        isFeatured: false,
        currency: 'USD',
        createdAt: new Date(),
        updatedAt: new Date()
      }
    ]);
  },

  down: async (queryInterface, Sequelize) => {
    await queryInterface.bulkDelete('Carts', null, {});
    await queryInterface.bulkDelete('Orders', null, {});
    await queryInterface.bulkDelete('Products', null, {});
    await queryInterface.bulkDelete('Users', null, {});
  }
};