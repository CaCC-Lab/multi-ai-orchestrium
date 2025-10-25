const request = require('supertest');
const { sequelize } = require('../config/db');
const app = require('../server');
const User = require('../models/User');
const Product = require('../models/Product');

describe('Product Controller', () => {
  let adminUser, userToken, adminToken;

  beforeAll(async () => {
    await sequelize.sync({ force: true });
  });

  beforeEach(async () => {
    await Product.destroy({ where: {} });
    await User.destroy({ where: {} });

    // Create users
    const userData = {
      firstName: 'John',
      lastName: 'Doe',
      email: 'john.doe@example.com',
      password: 'password123',
      phone: '+1234567890'
    };

    const adminData = {
      firstName: 'Admin',
      lastName: 'User',
      email: 'admin@example.com',
      password: 'password123',
      role: 'admin',
      phone: '+1234567890'
    };

    await User.create(userData);
    adminUser = await User.create(adminData);

    // Login to get tokens
    const userLogin = await request(app)
      .post('/api/v1/auth/login')
      .send({ email: 'john.doe@example.com', password: 'password123' });

    const adminLogin = await request(app)
      .post('/api/v1/auth/login')
      .send({ email: 'admin@example.com', password: 'password123' });

    userToken = userLogin.body.token;
    adminToken = adminLogin.body.token;
  });

  afterAll(async () => {
    await sequelize.close();
  });

  describe('GET /api/v1/products', () => {
    it('should get all active products', async () => {
      // Create some products
      await Product.create({
        name: 'Test Product 1',
        description: 'Test Description 1',
        price: 19.99,
        category: 'Electronics',
        inventory: 10
      });

      await Product.create({
        name: 'Test Product 2',
        description: 'Test Description 2',
        price: 29.99,
        category: 'Books',
        inventory: 5
      });

      const res = await request(app)
        .get('/api/v1/products')
        .expect(200);

      expect(res.body.success).toBe(true);
      expect(res.body.data.length).toBe(2);
      expect(res.body.data[0].name).toBe('Test Product 1');
    });
  });

  describe('POST /api/v1/products', () => {
    it('should create a new product with admin token', async () => {
      const productData = {
        name: 'New Product',
        description: 'New Product Description',
        price: 49.99,
        category: 'Electronics',
        inventory: 20
      };

      const res = await request(app)
        .post('/api/v1/products')
        .set('Authorization', `Bearer ${adminToken}`)
        .send(productData)
        .expect(201);

      expect(res.body.success).toBe(true);
      expect(res.body.data.name).toBe(productData.name);
    });

    it('should not create a product without admin token', async () => {
      const productData = {
        name: 'Unauthorized Product',
        description: 'This should fail',
        price: 19.99,
        category: 'Books',
        inventory: 10
      };

      const res = await request(app)
        .post('/api/v1/products')
        .set('Authorization', `Bearer ${userToken}`)
        .send(productData)
        .expect(403);

      expect(res.body.success).toBe(false);
    });
  });

  describe('GET /api/v1/products/:id', () => {
    it('should get a single product by ID', async () => {
      const product = await Product.create({
        name: 'Get Product Test',
        description: 'Get Product Description',
        price: 39.99,
        category: 'Electronics',
        inventory: 15
      });

      const res = await request(app)
        .get(`/api/v1/products/${product.id}`)
        .expect(200);

      expect(res.body.success).toBe(true);
      expect(res.body.data.name).toBe(product.name);
    });

    it('should return 404 for non-existent product', async () => {
      const res = await request(app)
        .get('/api/v1/products/999999')
        .expect(404);

      expect(res.body.success).toBe(false);
    });
  });

  describe('PUT /api/v1/products/:id', () => {
    it('should update a product with admin token', async () => {
      const product = await Product.create({
        name: 'Update Product Test',
        description: 'Old Description',
        price: 39.99,
        category: 'Electronics',
        inventory: 15
      });

      const updatedData = {
        name: 'Updated Product Name',
        description: 'New Description',
        price: 49.99
      };

      const res = await request(app)
        .put(`/api/v1/products/${product.id}`)
        .set('Authorization', `Bearer ${adminToken}`)
        .send(updatedData)
        .expect(200);

      expect(res.body.success).toBe(true);
      expect(res.body.data.name).toBe(updatedData.name);
      expect(res.body.data.description).toBe(updatedData.description);
    });
  });

  describe('GET /api/v1/products/search', () => {
    it('should search products by name', async () => {
      await Product.create({
        name: 'Laptop Test',
        description: 'Test laptop product',
        price: 999.99,
        category: 'Electronics',
        inventory: 5
      });

      await Product.create({
        name: 'Phone Test',
        description: 'Test phone product',
        price: 699.99,
        category: 'Electronics',
        inventory: 10
      });

      const res = await request(app)
        .get('/api/v1/products/search?query=Laptop')
        .expect(200);

      expect(res.body.success).toBe(true);
      expect(res.body.data.length).toBe(1);
      expect(res.body.data[0].name).toContain('Laptop');
    });
  });
});