const request = require('supertest');
const { sequelize } = require('../config/db');
const app = require('../server');
const User = require('../models/User');
const Product = require('../models/Product');
const Cart = require('../models/Cart');

describe('Cart Controller', () => {
  let user, product, userToken;

  beforeAll(async () => {
    await sequelize.sync({ force: true });
  });

  beforeEach(async () => {
    await Cart.destroy({ where: {} });
    await Product.destroy({ where: {} });
    await User.destroy({ where: {} });

    // Create user
    user = await User.create({
      firstName: 'John',
      lastName: 'Doe',
      email: 'john.doe@example.com',
      password: 'password123',
      phone: '+1234567890'
    });

    // Create product
    product = await Product.create({
      name: 'Test Product',
      description: 'Test Description',
      price: 29.99,
      category: 'Electronics',
      inventory: 10
    });

    // Login to get token
    const loginRes = await request(app)
      .post('/api/v1/auth/login')
      .send({ email: 'john.doe@example.com', password: 'password123' });

    userToken = loginRes.body.token;
  });

  afterAll(async () => {
    await sequelize.close();
  });

  describe('POST /api/v1/cart', () => {
    it('should add an item to cart', async () => {
      const res = await request(app)
        .post('/api/v1/cart')
        .set('Authorization', `Bearer ${userToken}`)
        .send({
          productId: product.id,
          quantity: 2
        })
        .expect(200);

      expect(res.body.success).toBe(true);
      expect(res.body.data.productId).toBe(product.id);
      expect(res.body.data.quantity).toBe(2);
    });

    it('should return error for non-existent product', async () => {
      const res = await request(app)
        .post('/api/v1/cart')
        .set('Authorization', `Bearer ${userToken}`)
        .send({
          productId: 999999, // Non-existent product
          quantity: 1
        })
        .expect(404);

      expect(res.body.success).toBe(false);
    });
  });

  describe('GET /api/v1/cart', () => {
    it('should get user cart items', async () => {
      // First add an item to cart
      await request(app)
        .post('/api/v1/cart')
        .set('Authorization', `Bearer ${userToken}`)
        .send({
          productId: product.id,
          quantity: 2
        });

      const res = await request(app)
        .get('/api/v1/cart')
        .set('Authorization', `Bearer ${userToken}`)
        .expect(200);

      expect(res.body.success).toBe(true);
      expect(res.body.count).toBe(1);
      expect(res.body.data[0].productId).toBe(product.id);
      expect(res.body.data[0].quantity).toBe(2);
    });
  });

  describe('PUT /api/v1/cart/:id', () => {
    it('should update cart item quantity', async () => {
      // Add item to cart
      const addToCartRes = await request(app)
        .post('/api/v1/cart')
        .set('Authorization', `Bearer ${userToken}`)
        .send({
          productId: product.id,
          quantity: 1
        });

      const cartItemId = addToCartRes.body.data.id;

      // Update quantity
      const res = await request(app)
        .put(`/api/v1/cart/${cartItemId}`)
        .set('Authorization', `Bearer ${userToken}`)
        .send({ quantity: 3 })
        .expect(200);

      expect(res.body.success).toBe(true);
      expect(res.body.data.quantity).toBe(3);
    });
  });

  describe('DELETE /api/v1/cart/:id', () => {
    it('should remove item from cart', async () => {
      // Add item to cart
      const addToCartRes = await request(app)
        .post('/api/v1/cart')
        .set('Authorization', `Bearer ${userToken}`)
        .send({
          productId: product.id,
          quantity: 2
        });

      const cartItemId = addToCartRes.body.data.id;

      // Remove item
      const res = await request(app)
        .delete(`/api/v1/cart/${cartItemId}`)
        .set('Authorization', `Bearer ${userToken}`)
        .expect(200);

      expect(res.body.success).toBe(true);

      // Verify item is removed
      const cartRes = await request(app)
        .get('/api/v1/cart')
        .set('Authorization', `Bearer ${userToken}`)
        .expect(200);

      expect(cartRes.body.count).toBe(0);
    });
  });
});