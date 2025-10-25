// backend/__tests__/productController.test.js
const { getProducts, getProductById } = require('../controllers/productController');
const Product = require('../models/Product');
const { Op } = require('sequelize');

// Mock dependencies
jest.mock('../models/Product');
jest.mock('../utils/cache', () => ({
  getCache: jest.fn().mockResolvedValue(null),
  setCache: jest.fn().mockResolvedValue()
}));

describe('Product Controller', () => {
  let req, res;

  beforeEach(() => {
    req = {
      params: {},
      query: {},
      body: {}
    };
    res = {
      status: jest.fn().mockReturnThis(),
      json: jest.fn()
    };
  });

  afterEach(() => {
    jest.clearAllMocks();
  });

  describe('getProducts', () => {
    it('should return products with pagination', async () => {
      const mockProducts = {
        rows: [
          { id: 1, name: 'Product 1', price: 10.99, isActive: true },
          { id: 2, name: 'Product 2', price: 15.99, isActive: true }
        ],
        count: 2
      };

      req.query = { page: '1', limit: '10' };

      Product.findAndCountAll.mockResolvedValue(mockProducts);

      await getProducts(req, res);

      expect(res.json).toHaveBeenCalledWith({
        products: mockProducts.rows,
        pagination: {
          currentPage: 1,
          totalPages: 1,
          totalProducts: 2,
          hasNext: false,
          hasPrev: false
        }
      });
    });

    it('should handle query parameters correctly', async () => {
      const mockProducts = {
        rows: [],
        count: 0
      };

      req.query = { 
        page: '1', 
        limit: '10', 
        category: 'Electronics', 
        search: 'phone' 
      };

      Product.findAndCountAll.mockResolvedValue(mockProducts);

      await getProducts(req, res);

      // Verify that findAndCountAll was called with the correct where clause
      expect(Product.findAndCountAll).toHaveBeenCalledWith(
        expect.objectContaining({
          where: expect.objectContaining({
            [Op.or]: expect.any(Array)
          })
        })
      );
    });
  });

  describe('getProductById', () => {
    it('should return a product by ID', async () => {
      const mockProduct = { id: 1, name: 'Test Product', price: 29.99, isActive: true };

      req.params = { id: '1' };

      Product.findByPk.mockResolvedValue(mockProduct);

      await getProductById(req, res);

      expect(res.json).toHaveBeenCalledWith(mockProduct);
    });

    it('should return 404 if product is not found', async () => {
      req.params = { id: '999' };

      Product.findByPk.mockResolvedValue(null);

      await getProductById(req, res);

      expect(res.status).toHaveBeenCalledWith(404);
      expect(res.json).toHaveBeenCalledWith({ message: 'Product not found' });
    });

    it('should return 404 if product is not active', async () => {
      const inactiveProduct = { id: 1, name: 'Inactive Product', isActive: false };

      req.params = { id: '1' };

      Product.findByPk.mockResolvedValue(inactiveProduct);

      await getProductById(req, res);

      expect(res.status).toHaveBeenCalledWith(404);
      expect(res.json).toHaveBeenCalledWith({ message: 'Product not found' });
    });
  });
});