const request = require('supertest');
const { sequelize } = require('../config/db');
const app = require('../server');
const User = require('../models/User');
const Product = require('../models/Product');
const Cart = require('../models/Cart');
const Order = require('../models/Order');

describe('Order Controller', () => {
  let user, product, userToken;

  beforeAll(async () => {
    await sequelize.sync({ force: true });
  });

  beforeEach(async () => {
    await Order.destroy({ where: {} });
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

  describe('POST /api/v1/orders', () => {
    it('should create a new order', async () => {
      // Add item to cart first
      await request(app)
        .post('/api/v1/cart')
        .set('Authorization', `Bearer ${userToken}`)
        .send({
          productId: product.id,
          quantity: 2
        });

      const orderData = {
        shippingAddress: {
          address: '123 Main St',
          city: 'New York',
          postalCode: '10001',
          country: 'USA'
        },
        paymentMethod: 'card',
        currency: 'USD'
      };

      const res = await request(app)
        .post('/api/v1/orders')
        .set('Authorization', `Bearer ${userToken}`)
        .send(orderData)
        .expect(201);

      expect(res.body.success).toBe(true);
      expect(res.body.data.order.totalAmount).toBe('59.98'); // 2 * 29.99
      expect(res.body.data.order.status).toBe('pending');
      expect(res.body.data.clientSecret).toBeDefined();
    });

    it('should not create order with empty cart', async () => {
      const orderData = {
        shippingAddress: {
          address: '123 Main St',
          city: 'New York',
          postalCode: '10001',
          country: 'USA'
        },
        paymentMethod: 'card'
      };

      const res = await request(app)
        .post('/api/v1/orders')
        .set('Authorization', `Bearer ${userToken}`)
        .send(orderData)
        .expect(400);

      expect(res.body.success).toBe(false);
    });
  });

  describe('GET /api/v1/orders/myorders', () => {
    it('should get user orders', async () => {
      // Create an order first
      // Add item to cart first
      await request(app)
        .post('/api/v1/cart')
        .set('Authorization', `Bearer ${userToken}`)
        .send({
          productId: product.id,
          quantity: 1
        });

      await request(app)
        .post('/api/v1/orders')
        .set('Authorization', `Bearer ${userToken}`)
        .send({
          shippingAddress: {
            address: '123 Main St',
            city: 'New York',
            postalCode: '10001',
            country: 'USA'
          },
          paymentMethod: 'card'
        });

      const res = await request(app)
        .get('/api/v1/orders/myorders')
        .set('Authorization', `Bearer ${userToken}`)
        .expect(200);

      expect(res.body.success).toBe(true);
      expect(res.body.count).toBe(1);
      expect(res.body.data[0].userId).toBe(user.id);
    });
  });

  describe('GET /api/v1/orders/:id', () => {
    it('should get a specific order', async () => {
      // Create an order first
      // Add item to cart first
      await request(app)
        .post('/api/v1/cart')
        .set('Authorization', `Bearer ${userToken}`)
        .send({
          productId: product.id,
          quantity: 1
        });

      const orderRes = await request(app)
        .post('/api/v1/orders')
        .set('Authorization', `Bearer ${userToken}`)
        .send({
          shippingAddress: {
            address: '123 Main St',
            city: 'New York',
            postalCode: '10001',
            country: 'USA'
          },
          paymentMethod: 'card'
        });

      const orderId = orderRes.body.data.order.id;

      const res = await request(app)
        .get(`/api/v1/orders/${orderId}`)
        .set('Authorization', `Bearer ${userToken}`)
        .expect(200);

      expect(res.body.success).toBe(true);
      expect(res.body.data.id).toBe(orderId);
    });
  });
});