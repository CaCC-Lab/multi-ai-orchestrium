// backend/__tests__/integration.test.js
const request = require('supertest');
const app = require('../server'); // Adjust path to your main server file

describe('Integration Tests', () => {
  it('should get a response from the home route', async () => {
    const response = await request(app).get('/');
    
    expect(response.status).toBe(200);
    expect(response.body).toHaveProperty('message');
    expect(response.body.message).toBe('E-commerce API is running!');
  });

  it('should return 404 for non-existent route', async () => {
    const response = await request(app).get('/nonexistent');
    
    expect(response.status).toBe(404);
  });
});