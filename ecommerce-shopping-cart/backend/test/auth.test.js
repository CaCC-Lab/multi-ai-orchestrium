const request = require('supertest');
const { sequelize } = require('../config/db');
const app = require('../server');
const User = require('../models/User');
const bcrypt = require('bcryptjs');

describe('Auth Controller', () => {
  beforeAll(async () => {
    await sequelize.sync({ force: true });
  });

  beforeEach(async () => {
    await User.destroy({ where: {} });
  });

  afterAll(async () => {
    await sequelize.close();
  });

  describe('POST /api/v1/auth/register', () => {
    it('should register a new user', async () => {
      const userData = {
        firstName: 'John',
        lastName: 'Doe',
        email: 'john.doe@example.com',
        password: 'password123',
        phone: '+1234567890'
      };

      const res = await request(app)
        .post('/api/v1/auth/register')
        .send(userData)
        .expect(201);

      expect(res.body.success).toBe(true);
      expect(res.body.token).toBeDefined();
      expect(res.body.data.email).toBe(userData.email);
    });

    it('should return error for duplicate email', async () => {
      // Create first user
      await request(app)
        .post('/api/v1/auth/register')
        .send({
          firstName: 'John',
          lastName: 'Doe',
          email: 'john.doe@example.com',
          password: 'password123'
        });

      // Try to create another user with same email
      const res = await request(app)
        .post('/api/v1/auth/register')
        .send({
          firstName: 'Jane',
          lastName: 'Smith',
          email: 'john.doe@example.com', // Same email
          password: 'password456'
        })
        .expect(400);

      expect(res.body.success).toBe(false);
    });

    it('should return error for invalid input', async () => {
      const res = await request(app)
        .post('/api/v1/auth/register')
        .send({
          firstName: 'J', // Too short
          lastName: 'Doe',
          email: 'invalid-email', // Invalid email
          password: '123' // Too short
        })
        .expect(400);

      expect(res.body.success).toBe(false);
    });
  });

  describe('POST /api/v1/auth/login', () => {
    it('should login a user with valid credentials', async () => {
      // First, register a user
      await request(app)
        .post('/api/v1/auth/register')
        .send({
          firstName: 'John',
          lastName: 'Doe',
          email: 'john.doe@example.com',
          password: 'password123'
        });

      const res = await request(app)
        .post('/api/v1/auth/login')
        .send({
          email: 'john.doe@example.com',
          password: 'password123'
        })
        .expect(200);

      expect(res.body.success).toBe(true);
      expect(res.body.token).toBeDefined();
    });

    it('should not login with invalid credentials', async () => {
      const res = await request(app)
        .post('/api/v1/auth/login')
        .send({
          email: 'nonexistent@example.com',
          password: 'wrongpassword'
        })
        .expect(401);

      expect(res.body.success).toBe(false);
    });
  });

  describe('GET /api/v1/auth/me', () => {
    it('should return current user details with valid token', async () => {
      // Register and get token
      const registerRes = await request(app)
        .post('/api/v1/auth/register')
        .send({
          firstName: 'John',
          lastName: 'Doe',
          email: 'john.doe@example.com',
          password: 'password123'
        });

      const token = registerRes.body.token;

      const res = await request(app)
        .get('/api/v1/auth/me')
        .set('Authorization', `Bearer ${token}`)
        .expect(200);

      expect(res.body.success).toBe(true);
      expect(res.body.data.email).toBe('john.doe@example.com');
    });

    it('should return error without valid token', async () => {
      const res = await request(app)
        .get('/api/v1/auth/me')
        .expect(401);

      expect(res.body.success).toBe(false);
    });
  });
});