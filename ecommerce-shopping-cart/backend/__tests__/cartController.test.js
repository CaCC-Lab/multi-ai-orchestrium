// backend/__tests__/cartController.test.js
const { getCart, addItem } = require('../controllers/cartController');
const Cart = require('../models/Cart');
const Product = require('../models/Product');

// Mock dependencies
jest.mock('../models/Cart');
jest.mock('../models/Product');

describe('Cart Controller', () => {
  let req, res;

  beforeEach(() => {
    req = {
      params: {},
      query: {},
      body: {},
      user: { id: 1 }
    };
    res = {
      status: jest.fn().mockReturnThis(),
      json: jest.fn()
    };
  });

  afterEach(() => {
    jest.clearAllMocks();
  });

  describe('getCart', () => {
    it('should return user\'s cart items', async () => {
      const mockCartItems = [
        {
          id: 1,
          userId: 1,
          productId: 1,
          quantity: 2,
          Product: { id: 1, name: 'Test Product', price: 10.99 }
        }
      ];

      Cart.findAll.mockResolvedValue(mockCartItems);

      await getCart(req, res);

      expect(Cart.findAll).toHaveBeenCalledWith({
        where: { userId: 1 },
        include: [{ model: Product, attributes: ['id', 'name', 'price', 'imageUrl'] }]
      });

      expect(res.json).toHaveBeenCalledWith({
        cartItems: mockCartItems,
        total: 21.98,
        itemCount: 2
      });
    });
  });

  describe('addItem', () => {
    it('should add item to cart if it does not exist', async () => {
      req.body = { productId: 1, quantity: 2 };
      
      // Simulate that the item doesn't exist in the cart yet
      Cart.findOne.mockResolvedValue(null);
      
      const mockProduct = { 
        id: 1, 
        name: 'Test Product', 
        price: 10.99, 
        stockQuantity: 10 
      };
      
      Product.findByPk.mockResolvedValue(mockProduct);
      
      const mockNewCartItem = { 
        id: 1, 
        userId: 1, 
        productId: 1, 
        quantity: 2, 
        save: jest.fn() 
      };
      
      Cart.create.mockResolvedValue(mockNewCartItem);

      await addItem(req, res);

      expect(Cart.create).toHaveBeenCalledWith({
        userId: 1,
        productId: 1,
        quantity: 2
      });

      expect(res.json).toHaveBeenCalledWith({
        message: 'Item added to cart successfully',
        cartItem: mockNewCartItem
      });
    });

    it('should update quantity if item already exists in cart', async () => {
      req.body = { productId: 1, quantity: 2 };
      
      const existingCartItem = { 
        id: 1, 
        userId: 1, 
        productId: 1, 
        quantity: 1, 
        save: jest.fn() 
      };
      
      Cart.findOne.mockResolvedValue(existingCartItem);
      
      const mockProduct = { 
        id: 1, 
        name: 'Test Product', 
        price: 10.99, 
        stockQuantity: 10 
      };
      
      Product.findByPk.mockResolvedValue(mockProduct);

      await addItem(req, res);

      expect(existingCartItem.quantity).toBe(3); // 1 (existing) + 2 (new)
      expect(existingCartItem.save).toHaveBeenCalled();
    });

    it('should return error if product does not exist', async () => {
      req.body = { productId: 999, quantity: 1 };
      
      Cart.findOne.mockResolvedValue(null);
      Product.findByPk.mockResolvedValue(null);

      await addItem(req, res);

      expect(res.status).toHaveBeenCalledWith(404);
      expect(res.json).toHaveBeenCalledWith({
        message: 'Product not found'
      });
    });
  });
});