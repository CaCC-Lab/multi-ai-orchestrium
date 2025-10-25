// Sample unit test for authentication controller functions

const request = require('supertest');
const app = require('../server');
const User = require('../models/User');
const bcrypt = require('bcryptjs');

describe('Auth Controller', () => {
  afterAll(async () => {
    // Clean up users after tests
    await User.destroy({ where: {} });
  });

  describe('POST /api/auth/register', () => {
    test('should register a new user', async () => {
      const userData = {
        name: 'Test User',
        email: 'test@example.com',
        password: 'password123'
      };

      const response = await request(app)
        .post('/api/auth/register')
        .send(userData)
        .set('Content-Type', 'application/json');
      
      expect(response.status).toBe(201);
      expect(response.body).toHaveProperty('id');
      expect(response.body).toHaveProperty('email', 'test@example.com');
      expect(response.body).toHaveProperty('name', 'Test User');
      expect(response.body).toHaveProperty('token');
    });

    test('should not register user with invalid email', async () => {
      const userData = {
        name: 'Test User',
        email: 'invalid-email',
        password: 'password123'
      };

      const response = await request(app)
        .post('/api/auth/register')
        .send(userData)
        .set('Content-Type', 'application/json');
      
      expect(response.status).toBe(400);
      expect(response.body).toHaveProperty('errors');
    });

    test('should not register user with short password', async () => {
      const userData = {
        name: 'Test User',
        email: 'test2@example.com',
        password: '123'
      };

      const response = await request(app)
        .post('/api/auth/register')
        .send(userData)
        .set('Content-Type', 'application/json');
      
      expect(response.status).toBe(400);
      expect(response.body).toHaveProperty('errors');
    });
  });

  describe('POST /api/auth/login', () => {
    let user;

    beforeAll(async () => {
      // Create a test user for login tests
      const hashedPassword = await bcrypt.hash('password123', 10);
      user = await User.create({
        name: 'Login Test User',
        email: 'login@example.com',
        password: hashedPassword
      });
    });

    afterAll(async () => {
      await User.destroy({ where: {} });
    });

    test('should login existing user with valid credentials', async () => {
      const loginData = {
        email: 'login@example.com',
        password: 'password123'
      };

      const response = await request(app)
        .post('/api/auth/login')
        .send(loginData)
        .set('Content-Type', 'application/json');
      
      expect(response.status).toBe(200);
      expect(response.body).toHaveProperty('id', user.id);
      expect(response.body).toHaveProperty('email', 'login@example.com');
      expect(response.body).toHaveProperty('token');
    });

    test('should not login with invalid email', async () => {
      const loginData = {
        email: 'nonexistent@example.com',
        password: 'password123'
      };

      const response = await request(app)
        .post('/api/auth/login')
        .send(loginData)
        .set('Content-Type', 'application/json');
      
      expect(response.status).toBe(400);
      expect(response.body).toHaveProperty('message', 'Invalid credentials');
    });

    test('should not login with invalid password', async () => {
      const loginData = {
        email: 'login@example.com',
        password: 'wrongpassword'
      };

      const response = await request(app)
        .post('/api/auth/login')
        .send(loginData)
        .set('Content-Type', 'application/json');
      
      expect(response.status).toBe(400);
      expect(response.body).toHaveProperty('message', 'Invalid credentials');
    });
  });

  describe('GET /api/auth/profile', () => {
    let user;
    let token;

    beforeAll(async () => {
      // Create a test user and get token
      const hashedPassword = await bcrypt.hash('password123', 10);
      user = await User.create({
        name: 'Profile Test User',
        email: 'profile@example.com',
        password: hashedPassword
      });

      // Get a valid token by logging in
      const loginResponse = await request(app)
        .post('/api/auth/login')
        .send({
          email: 'profile@example.com',
          password: 'password123'
        });
      
      token = loginResponse.body.token;
    });

    afterAll(async () => {
      await User.destroy({ where: {} });
    });

    test('should get user profile with valid token', async () => {
      const response = await request(app)
        .get('/api/auth/profile')
        .set('Authorization', `Bearer ${token}`);
      
      expect(response.status).toBe(200);
      expect(response.body).toHaveProperty('id', user.id);
      expect(response.body).toHaveProperty('email', 'profile@example.com');
      expect(response.body).toHaveProperty('name', 'Profile Test User');
    });

    test('should not get user profile without token', async () => {
      const response = await request(app)
        .get('/api/auth/profile');
      
      expect(response.status).toBe(401);
      expect(response.body).toHaveProperty('message', 'Not authorized, no token');
    });
  });
});