const request = require('supertest');
const app = require('../../app'); // Import the Express app

describe('Server Integration Tests', () => {
  describe('GET /api/health', () => {
    test('should return health check information', async () => {
      const response = await request(app)
        .get('/api/health')
        .expect(200);
      
      expect(response.body).toHaveProperty('message');
      expect(response.body.message).toBe('Server is running');
      expect(response.body).toHaveProperty('timestamp');
      expect(new Date(response.body.timestamp)).toBeInstanceOf(Date);
    });
  });

  describe('Invalid routes', () => {
    test('should return 404 for invalid routes', async () => {
      const response = await request(app)
        .get('/invalid-route')
        .expect(404);
      
      expect(response.body).toHaveProperty('message');
      expect(response.body.message).toBe('Route not found');
    });
  });
});