// Sample unit test for product controller functions

const request = require('supertest');
const app = require('../server');
const Product = require('../models/Product');
const User = require('../models/User');
const { createIndexes } = require('../utils/dbOptimization');

describe('Product Controller', () => {
  beforeAll(async () => {
    // Set up database indexes
    await createIndexes();
  });

  afterAll(async () => {
    // Clean up database after tests
    await Product.destroy({ where: {} });
    await User.destroy({ where: {} });
  });

  describe('GET /api/products', () => {
    test('should fetch all products', async () => {
      // Create a test product
      await Product.create({
        name: 'Test Product',
        price: 19.99,
        description: 'Test description',
        category: 'Test Category',
        brand: 'Test Brand',
        image: 'test-image.jpg',
        countInStock: 10,
        rating: 4.5,
        numReviews: 5
      });

      const response = await request(app).get('/api/products');
      
      expect(response.status).toBe(200);
      expect(response.body.products).toHaveLength(1);
      expect(response.body.products[0]).toHaveProperty('name', 'Test Product');
    });

    test('should handle pagination correctly', async () => {
      // Create 10 products to test pagination
      await Product.destroy({ where: {} });
      for (let i = 1; i <= 10; i++) {
        await Product.create({
          name: `Test Product ${i}`,
          price: 19.99,
          description: 'Test description',
          category: 'Test Category',
          brand: 'Test Brand',
          image: 'test-image.jpg',
          countInStock: 10,
          rating: 4.5,
          numReviews: 5
        });
      }

      const response = await request(app).get('/api/products?pageNumber=1');
      
      expect(response.status).toBe(200);
      expect(response.body.products).toHaveLength(10);
      expect(response.body.page).toBe(1);
    });
  });

  describe('GET /api/products/:id', () => {
    let product;

    beforeEach(async () => {
      product = await Product.create({
        name: 'Single Test Product',
        price: 29.99,
        description: 'Test description',
        category: 'Test Category',
        brand: 'Test Brand',
        image: 'test-image.jpg',
        countInStock: 5,
        rating: 4.0,
        numReviews: 3
      });
    });

    afterEach(async () => {
      await Product.destroy({ where: {} });
    });

    test('should fetch a single product by ID', async () => {
      const response = await request(app).get(`/api/products/${product.id}`);
      
      expect(response.status).toBe(200);
      expect(response.body).toHaveProperty('name', 'Single Test Product');
      expect(response.body).toHaveProperty('price', 29.99);
    });

    test('should return 404 for non-existent product', async () => {
      const response = await request(app).get('/api/products/999999');
      
      expect(response.status).toBe(404);
      expect(response.body).toHaveProperty('message', 'Product not found');
    });
  });
});