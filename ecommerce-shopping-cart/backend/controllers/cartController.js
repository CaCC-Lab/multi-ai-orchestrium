const Cart = require('../models/Cart');
const Product = require('../models/Product');
const { convertPrice, getSupportedCurrencies } = require('../utils/currencies');
const { clearCachePattern } = require('../utils/redis');

/**
 * @swagger
 * tags:
 *   name: Cart
 *   description: Shopping cart management
 */

/**
 * @swagger
 * /cart:
 *   get:
 *     summary: Get user's cart
 *     tags: [Cart]
 *     security:
 *       - bearerAuth: []
 *     responses:
 *       200:
 *         description: User's cart retrieved successfully
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/Cart'
 *       401:
 *         description: Not authorized, token failed
 */

/**
 * @swagger
 * /cart/add:
 *   post:
 *     summary: Add item to cart
 *     tags: [Cart]
 *     security:
 *       - bearerAuth: []
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             properties:
 *               productId:
 *                 type: integer
 *                 example: 1
 *               qty:
 *                 type: integer
 *                 example: 2
 *               currency:
 *                 type: string
 *                 default: USD
 *                 example: USD
 *     responses:
 *       201:
 *         description: Item added to cart successfully
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/Cart'
 *       400:
 *         description: Invalid input or not enough stock
 *       401:
 *         description: Not authorized, token failed
 *       404:
 *         description: Product not found
 */

/**
 * @swagger
 * components:
 *   schemas:
 *     Cart:
 *       type: object
 *       properties:
 *         id:
 *           type: integer
 *           description: The auto-generated id of the cart
 *           example: 1
 *         userId:
 *           type: integer
 *           description: User ID associated with the cart
 *           example: 1
 *         items:
 *           type: array
 *           description: Cart items
 *           items:
 *             type: object
 *             properties:
 *               product:
 *                 $ref: '#/components/schemas/Product'
 *               qty:
 *                 type: integer
 *                 description: Quantity of the product
 *                 example: 2
 *         currency:
 *           type: string
 *           description: Currency for the cart
 *           example: USD
 *         totalItems:
 *           type: integer
 *           description: Total number of items
 *           example: 2
 *         totalPrice:
 *           type: number
 *           description: Total price of all items
 *           example: 399.98
 */

// @desc    Get user's cart
// @route   GET /api/cart
// @access  Private
exports.getCart = async (req, res) => {
  try {
    // Try to find existing cart for user
    let cart = await Cart.findOne({ where: { userId: req.user.id } });

    if (!cart) {
      // Create a new cart if one doesn't exist
      cart = await Cart.create({
        userId: req.user.id,
        items: [],
        totalItems: 0,
        totalPrice: 0.00
      });
    }

    res.json(cart);
  } catch (error) {
    console.error(error);
    res.status(500).json({ message: 'Server error' });
  }
};

// @desc    Add item to cart
// @route   POST /api/cart/add
// @access  Private
exports.addToCart = async (req, res) => {
  try {
    const { productId, qty, currency = 'USD' } = req.body;

    // Validate currency
    const supportedCurrencies = getSupportedCurrencies();
    if (!supportedCurrencies.includes(currency)) {
      return res.status(400).json({ message: 'Invalid currency' });
    }

    // Get product to verify it exists and get price
    const product = await Product.findByPk(productId);
    if (!product) {
      return res.status(404).json({ message: 'Product not found' });
    }

    if (product.countInStock < qty) {
      return res.status(400).json({ message: 'Not enough items in stock' });
    }

    // Find user's cart
    let cart = await Cart.findOne({ where: { userId: req.user.id } });

    if (!cart) {
      // Create new cart if it doesn't exist
      cart = await Cart.create({
        userId: req.user.id,
        items: [],
        currency: currency,
        totalItems: 0,
        totalPrice: 0.00
      });
    }

    // Update cart currency if different
    if (cart.currency !== currency) {
      // Convert existing prices to new currency
      cart.items = cart.items.map(item => {
        item.product.price = convertPrice(item.product.price, cart.currency, currency);
        item.product.currency = currency;
        return item;
      });
      cart.currency = currency;
    }

    // Check if product is already in cart
    const existingItemIndex = cart.items.findIndex(item => item.product.id === productId);

    if (existingItemIndex > -1) {
      // Update quantity if product exists in cart
      const existingQty = cart.items[existingItemIndex].qty;
      const newQty = existingQty + qty;

      if (product.countInStock < newQty) {
        return res.status(400).json({ message: 'Not enough items in stock' });
      }

      cart.items[existingItemIndex].qty = newQty;
    } else {
      // Add new product to cart (convert price to cart currency)
      const productPriceInCartCurrency = convertPrice(parseFloat(product.price), 'USD', currency);
      
      cart.items.push({
        product: {
          id: product.id,
          name: product.name,
          price: productPriceInCartCurrency,
          image: product.image,
          currency: currency
        },
        qty: qty
      });
    }

    // Calculate totals in cart currency
    const updatedItems = cart.items;
    let totalItems = 0;
    let totalPrice = 0;

    updatedItems.forEach(item => {
      totalItems += item.qty;
      totalPrice += parseFloat(item.product.price) * item.qty;
    });

    cart.totalItems = totalItems;
    cart.totalPrice = totalPrice;

    await cart.save();

    res.status(201).json(cart);
  } catch (error) {
    console.error(error);
    res.status(500).json({ message: 'Server error' });
  }
};

// @desc    Update cart item quantity
// @route   PUT /api/cart/update
// @access  Private
exports.updateCart = async (req, res) => {
  try {
    const { productId, qty } = req.body;

    if (qty <= 0) {
      return res.status(400).json({ message: 'Quantity must be greater than 0' });
    }

    // Get product to verify stock availability
    const product = await Product.findByPk(productId);
    if (!product) {
      return res.status(404).json({ message: 'Product not found' });
    }

    if (product.countInStock < qty) {
      return res.status(400).json({ message: 'Not enough items in stock' });
    }

    // Find user's cart
    const cart = await Cart.findOne({ where: { userId: req.user.id } });

    if (!cart) {
      return res.status(404).json({ message: 'Cart not found' });
    }

    // Find the item in the cart
    const itemIndex = cart.items.findIndex(item => item.product.id === productId);

    if (itemIndex === -1) {
      return res.status(404).json({ message: 'Item not found in cart' });
    }

    // Update quantity
    cart.items[itemIndex].qty = qty;

    // Calculate totals
    let totalItems = 0;
    let totalPrice = 0;

    cart.items.forEach(item => {
      totalItems += item.qty;
      totalPrice += parseFloat(item.product.price) * item.qty;
    });

    cart.totalItems = totalItems;
    cart.totalPrice = totalPrice;

    await cart.save();

    res.json(cart);
  } catch (error) {
    console.error(error);
    res.status(500).json({ message: 'Server error' });
  }
};

// @desc    Remove item from cart
// @route   DELETE /api/cart/remove/:id
// @access  Private
exports.removeFromCart = async (req, res) => {
  try {
    const productId = req.params.id;

    // Find user's cart
    const cart = await Cart.findOne({ where: { userId: req.user.id } });

    if (!cart) {
      return res.status(404).json({ message: 'Cart not found' });
    }

    // Filter out the item to be removed
    const updatedItems = cart.items.filter(item => item.product.id !== productId);

    if (updatedItems.length === cart.items.length) {
      return res.status(404).json({ message: 'Item not found in cart' });
    }

    cart.items = updatedItems;

    // Calculate totals
    let totalItems = 0;
    let totalPrice = 0;

    cart.items.forEach(item => {
      totalItems += item.qty;
      totalPrice += parseFloat(item.product.price) * item.qty;
    });

    cart.totalItems = totalItems;
    cart.totalPrice = totalPrice;

    await cart.save();

    res.json(cart);
  } catch (error) {
    console.error(error);
    res.status(500).json({ message: 'Server error' });
  }
};

// @desc    Clear user's cart
// @route   DELETE /api/cart/clear
// @access  Private
exports.clearCart = async (req, res) => {
  try {
    // Find user's cart
    const cart = await Cart.findOne({ where: { userId: req.user.id } });

    if (!cart) {
      return res.status(404).json({ message: 'Cart not found' });
    }

    // Clear items
    cart.items = [];
    cart.totalItems = 0;
    cart.totalPrice = 0.00;

    await cart.save();

    res.json({ message: 'Cart cleared successfully' });
  } catch (error) {
    console.error(error);
    res.status(500).json({ message: 'Server error' });
  }
};