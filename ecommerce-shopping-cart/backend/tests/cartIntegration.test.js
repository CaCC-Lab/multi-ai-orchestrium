// Sample integration test for cart functionality

const request = require('supertest');
const app = require('../server');
const User = require('../models/User');
const Product = require('../models/Product');
const Cart = require('../models/Cart');
const bcrypt = require('bcryptjs');

describe('Cart Integration Tests', () => {
  let user;
  let token;
  let product;

  beforeAll(async () => {
    // Create a test user
    const hashedPassword = await bcrypt.hash('password123', 10);
    user = await User.create({
      name: 'Cart Test User',
      email: 'cart@example.com',
      password: hashedPassword
    });

    // Get a valid token by logging in
    const loginResponse = await request(app)
      .post('/api/auth/login')
      .send({
        email: 'cart@example.com',
        password: 'password123'
      });
    
    token = loginResponse.body.token;

    // Create a test product
    product = await Product.create({
      name: 'Cart Test Product',
      price: 29.99,
      description: 'Test description for cart',
      category: 'Test Category',
      brand: 'Test Brand',
      image: 'test-image.jpg',
      countInStock: 10,
      rating: 4.0,
      numReviews: 2
    });
  });

  afterAll(async () => {
    // Clean up after tests
    await Cart.destroy({ where: {} });
    await Product.destroy({ where: {} });
    await User.destroy({ where: {} });
  });

  test('should add item to cart, update quantity, and get cart', async () => {
    // Add item to cart
    const addToCartResponse = await request(app)
      .post('/api/cart/add')
      .set('Authorization', `Bearer ${token}`)
      .send({
        productId: product.id,
        qty: 2
      });
    
    expect(addToCartResponse.status).toBe(201);
    expect(addToCartResponse.body.items).toHaveLength(1);
    expect(addToCartResponse.body.items[0]).toHaveProperty('qty', 2);
    expect(addToCartResponse.body.totalItems).toBe(2);
    expect(addToCartResponse.body.totalPrice).toBe(59.98);

    // Update cart item quantity
    const updateCartResponse = await request(app)
      .put('/api/cart/update')
      .set('Authorization', `Bearer ${token}`)
      .send({
        productId: product.id,
        qty: 3
      });
    
    expect(updateCartResponse.status).toBe(200);
    expect(updateCartResponse.body.items[0]).toHaveProperty('qty', 3);
    expect(updateCartResponse.body.totalItems).toBe(3);
    expect(updateCartResponse.body.totalPrice).toBe(89.97);

    // Get cart
    const getCartResponse = await request(app)
      .get('/api/cart')
      .set('Authorization', `Bearer ${token}`);
    
    expect(getCartResponse.status).toBe(200);
    expect(getCartResponse.body.items).toHaveLength(1);
    expect(getCartResponse.body.items[0]).toHaveProperty('qty', 3);
    expect(getCartResponse.body.totalItems).toBe(3);
  });

  test('should remove item from cart', async () => {
    // First add an item to cart
    await request(app)
      .post('/api/cart/add')
      .set('Authorization', `Bearer ${token}`)
      .send({
        productId: product.id,
        qty: 1
      });

    // Remove item from cart
    const response = await request(app)
      .delete(`/api/cart/remove/${product.id}`)
      .set('Authorization', `Bearer ${token}`);
    
    expect(response.status).toBe(200);
    expect(response.body.items).toHaveLength(0);
    expect(response.body.totalItems).toBe(0);
  });

  test('should handle cart operations with multiple products', async () => {
    // Create another test product
    const product2 = await Product.create({
      name: 'Second Cart Test Product',
      price: 15.50,
      description: 'Test description for second cart product',
      category: 'Test Category',
      brand: 'Test Brand',
      image: 'test-image2.jpg',
      countInStock: 5,
      rating: 4.5,
      numReviews: 3
    });

    // Add first product
    await request(app)
      .post('/api/cart/add')
      .set('Authorization', `Bearer ${token}`)
      .send({
        productId: product.id,
        qty: 2
      });

    // Add second product
    const addToCartResponse = await request(app)
      .post('/api/cart/add')
      .set('Authorization', `Bearer ${token}`)
      .send({
        productId: product2.id,
        qty: 3
      });
    
    expect(addToCartResponse.status).toBe(201);
    expect(addToCartResponse.body.items).toHaveLength(2);
    expect(addToCartResponse.body.totalItems).toBe(5);

    // Calculate expected total price: (2 * 29.99) + (3 * 15.50) = 59.98 + 46.50 = 106.48
    const expectedTotal = (2 * 29.99) + (3 * 15.50);
    expect(parseFloat(addToCartResponse.body.totalPrice)).toBeCloseTo(expectedTotal, 2);

    // Clean up the additional product
    await Product.destroy({ where: { id: product2.id } });
  });
});