process.env.NODE_ENV = 'test';
process.env.JWT_SECRET = process.env.JWT_SECRET || 'test_secret_key';
process.env.STRIPE_SECRET_KEY = 'sk_test_dummy';
process.env.EMAIL_HOST = 'smtp.test';
process.env.EMAIL_PORT = '587';
process.env.EMAIL_USER = 'apikey';
process.env.EMAIL_PASS = 'test_api_key';

// Mock the cache utility to prevent Redis operations from running network calls
jest.mock('../utils/cache', () => ({
  cache: () => (req, res, next) => next(),
  setCache: jest.fn().mockResolvedValue(undefined),
  getCache: jest.fn().mockResolvedValue(null),
  deleteCache: jest.fn().mockResolvedValue(undefined),
  clearCache: jest.fn().mockResolvedValue(undefined)
}));

// Mock email utility to avoid sending real emails
jest.mock('../utils/email', () => ({
  sendOrderConfirmation: jest.fn().mockResolvedValue(undefined),
  sendOrderStatusUpdate: jest.fn().mockResolvedValue(undefined),
  sendLowStockNotification: jest.fn().mockResolvedValue(undefined),
  sendOutOfStockNotification: jest.fn().mockResolvedValue(undefined)
}));

// Mock Redis client
jest.mock('redis', () => ({
  createClient: jest.fn(() => ({
    connect: jest.fn().mockResolvedValue(undefined),
    on: jest.fn(),
    get: jest.fn().mockResolvedValue(null),
    setEx: jest.fn().mockResolvedValue(undefined),
    del: jest.fn().mockResolvedValue(undefined),
    flushAll: jest.fn().mockResolvedValue(undefined)
  }))
}));

// Mock Stripe SDK
jest.mock('stripe', () => {
  return jest.fn().mockImplementation(() => ({
    paymentIntents: {
      create: jest.fn().mockResolvedValue({ id: 'pi_test', client_secret: 'secret' }),
      retrieve: jest.fn().mockResolvedValue({
        status: 'succeeded',
        id: 'pi_test',
        metadata: { orderNumber: 'ORD-TEST' }
      })
    },
    webhooks: {
      constructEvent: jest.fn((payload) => payload)
    }
  }));
});

// Mock nodemailer transport
jest.mock('nodemailer', () => ({
  createTransport: jest.fn(() => ({
    verify: jest.fn(),
    sendMail: jest.fn().mockResolvedValue({ response: 'ok' })
  }))
}));

const sequelize = require('../config/db');
const models = require('../models');

beforeAll(async () => {
  await sequelize.sync({ force: true });
});

beforeEach(async () => {
  await sequelize.sync({ force: true });
});

afterAll(async () => {
  await sequelize.close();
});

const suppressLogs = process.env.SUPPRESS_JEST_LOGS !== 'false';

if (suppressLogs) {
  // Suppress noisy console output during tests unless explicitly disabled
  console.error = jest.fn();
  console.log = jest.fn();
}