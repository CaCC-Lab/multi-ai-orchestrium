const { hashPassword, comparePassword, generateToken, verifyToken } = require('../../utils/auth');
const jwt = require('jsonwebtoken');

// Mock environment variables for testing
process.env.JWT_SECRET = 'test_secret_key';

describe('Authentication Utility Functions', () => {
  describe('hashPassword', () => {
    test('should hash a password', async () => {
      const password = 'testPassword123';
      const hashedPassword = await hashPassword(password);
      
      expect(hashedPassword).toBeDefined();
      expect(hashedPassword).not.toBe(password); // Should not be the same as original
      expect(typeof hashedPassword).toBe('string');
    });

    test('should produce different hashes for same password', async () => {
      const password = 'testPassword123';
      const hash1 = await hashPassword(password);
      const hash2 = await hashPassword(password);
      
      expect(hash1).not.toBe(hash2); // bcrypt adds salt, so hashes should be different
    });
  });

  describe('comparePassword', () => {
    test('should return true for matching password and hash', async () => {
      const password = 'testPassword123';
      const hashedPassword = await hashPassword(password);
      
      const isMatch = await comparePassword(password, hashedPassword);
      expect(isMatch).toBe(true);
    });

    test('should return false for non-matching password and hash', async () => {
      const password = 'testPassword123';
      const wrongPassword = 'wrongPassword';
      const hashedPassword = await hashPassword(password);
      
      const isMatch = await comparePassword(wrongPassword, hashedPassword);
      expect(isMatch).toBe(false);
    });
  });

  describe('generateToken and verifyToken', () => {
    test('should generate and verify a valid JWT token', () => {
      const payload = { id: 1, email: 'test@example.com', role: 'customer' };
      const token = generateToken(payload);
      
      expect(token).toBeDefined();
      expect(typeof token).toBe('string');
      
      const decoded = verifyToken(token);
      expect(decoded.id).toBe(payload.id);
      expect(decoded.email).toBe(payload.email);
      expect(decoded.role).toBe(payload.role);
    });

    test('should throw error for invalid token', () => {
      const invalidToken = 'invalid.token.here';
      
      expect(() => verifyToken(invalidToken)).toThrow('Invalid token');
    });

    test('should work with different payloads', () => {
      const payloads = [
        { id: 2, email: 'admin@example.com', role: 'admin' },
        { id: 3, email: 'user@example.com', role: 'customer' },
        { id: 4, email: 'test@example.com', role: 'customer' }
      ];
      
      payloads.forEach(payload => {
        const token = generateToken(payload);
        const decoded = verifyToken(token);
        
        expect(decoded.id).toBe(payload.id);
        expect(decoded.email).toBe(payload.email);
        expect(decoded.role).toBe(payload.role);
      });
    });
  });
});