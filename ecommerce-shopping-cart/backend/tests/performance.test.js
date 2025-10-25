// Sample unit test for performance middleware

const request = require('supertest');
const app = require('../server');

describe('Performance and Health Checks', () => {
  test('should return health status', async () => {
    const response = await request(app).get('/health');
    
    expect(response.status).toBe(200);
    expect(response.body).toHaveProperty('status', 'OK');
    expect(response.body).toHaveProperty('uptime');
    expect(response.body).toHaveProperty('memory');
    expect(response.body.memory).toHaveProperty('rss');
    expect(response.body.memory).toHaveProperty('heapTotal');
    expect(response.body.memory).toHaveProperty('heapUsed');
  });

  test('should respond to basic routes', async () => {
    const response = await request(app).get('/');
    
    // Since we don't have a root route, this should return 404
    expect(response.status).toBe(404);
  });

  test('should respond to API docs route', async () => {
    const response = await request(app).get('/api-docs');
    
    // Should return 200 for swagger docs
    expect(response.status).toBe(200);
  });
});