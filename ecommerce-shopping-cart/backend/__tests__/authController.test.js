// backend/__tests__/authController.test.js
const { register, login } = require('../controllers/authController');
const User = require('../models/User');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');

// Mock external dependencies
jest.mock('../models/User');
jest.mock('bcryptjs');
jest.mock('jsonwebtoken');
jest.mock('../services/emailService', () => ({
  sendWelcomeEmail: jest.fn().mockResolvedValue()
}));

describe('Auth Controller', () => {
  let req, res, next;

  beforeEach(() => {
    req = {
      body: {}
    };
    res = {
      status: jest.fn().mockReturnThis(),
      json: jest.fn(),
      cookie: jest.fn()
    };
    next = jest.fn();
  });

  afterEach(() => {
    jest.clearAllMocks();
  });

  describe('register', () => {
    it('should register a new user', async () => {
      const mockUser = {
        id: 1,
        firstName: 'John',
        lastName: 'Doe',
        email: 'john@example.com',
        password: 'hashedPassword',
        save: jest.fn()
      };

      req.body = {
        firstName: 'John',
        lastName: 'Doe',
        email: 'john@example.com',
        password: 'password123'
      };

      User.findOne.mockResolvedValue(null); // No existing user
      User.create.mockResolvedValue(mockUser);
      bcrypt.hash = jest.fn().mockResolvedValue('hashedPassword');
      jwt.sign = jest.fn().mockReturnValue('mockToken');

      await register(req, res);

      expect(res.status).toHaveBeenCalledWith(201);
      expect(res.json).toHaveBeenCalledWith(
        expect.objectContaining({
          message: 'User registered successfully',
          token: 'mockToken',
          user: expect.objectContaining({
            id: 1,
            firstName: 'John',
            lastName: 'Doe',
            email: 'john@example.com'
          })
        })
      );
    });

    it('should return error if user already exists', async () => {
      req.body = {
        firstName: 'John',
        lastName: 'Doe',
        email: 'john@example.com',
        password: 'password123'
      };

      User.findOne.mockResolvedValue({ id: 1, email: 'john@example.com' });

      await register(req, res);

      expect(res.status).toHaveBeenCalledWith(400);
      expect(res.json).toHaveBeenCalledWith({
        message: 'User already exists with this email'
      });
    });
  });

  describe('login', () => {
    it('should login user with valid credentials', async () => {
      const mockUser = {
        id: 1,
        firstName: 'John',
        lastName: 'Doe',
        email: 'john@example.com',
        password: 'hashedPassword'
      };

      req.body = {
        email: 'john@example.com',
        password: 'password123'
      };

      User.findOne.mockResolvedValue(mockUser);
      bcrypt.compare = jest.fn().mockResolvedValue(true);
      jwt.sign = jest.fn().mockReturnValue('mockToken');

      await login(req, res);

      expect(res.json).toHaveBeenCalledWith(
        expect.objectContaining({
          message: 'Login successful',
          token: 'mockToken',
          user: expect.objectContaining({
            id: 1,
            firstName: 'John',
            lastName: 'Doe',
            email: 'john@example.com'
          })
        })
      );
    });

    it('should return error for invalid credentials', async () => {
      req.body = {
        email: 'nonexistent@example.com',
        password: 'wrongpassword'
      };

      User.findOne.mockResolvedValue(null); // No user found

      await login(req, res);

      expect(res.status).toHaveBeenCalledWith(400);
      expect(res.json).toHaveBeenCalledWith({
        message: 'Invalid credentials'
      });
    });
  });
});