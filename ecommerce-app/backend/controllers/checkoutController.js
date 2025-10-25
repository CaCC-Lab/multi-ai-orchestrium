const stripeSecretKey = process.env.STRIPE_SECRET_KEY || 'sk_test_dummy';
const stripe = require('stripe')(stripeSecretKey);
const { Cart, Product, Order, User } = require('../models');
const { randomBytes } = require('crypto');
const { convertCurrency, SUPPORTED_CURRENCIES, getExchangeRate } = require('../utils/currency');

// Generate a random ID similar to UUID
const generateId = () => randomBytes(4).toString('hex').toUpperCase();

// Create an order and process payment
const processCheckout = async (req, res) => {
  try {
    const userId = req.user.id;
    const { shippingAddress, billingAddress, paymentMethod, currency = 'USD' } = req.body;

    // Validate currency
    if (currency && !SUPPORTED_CURRENCIES.includes(currency)) {
      return res.status(400).json({ message: `Unsupported currency: ${currency}` });
    }

    // Get user's cart
    const cartItems = await Cart.findAll({
      where: { userId },
      include: [{
        model: Product,
        attributes: ['id', 'name', 'price', 'stockQuantity', 'currency']
      }]
    });

    if (!cartItems || cartItems.length === 0) {
      return res.status(400).json({ message: 'Cart is empty' });
    }

    // Validate stock availability and calculate total in cart currency
    let totalAmountInCartCurrency = 0;
    const orderItems = [];

    for (const item of cartItems) {
      const product = item.Product;
      
      // Check if product is in stock
      if (product.stockQuantity < item.quantity) {
        return res.status(400).json({ 
          message: `Insufficient stock for ${product.name}. Available: ${product.stockQuantity}, Requested: ${item.quantity}` 
        });
      }

      // Convert price to the cart's currency if needed
      let priceInCartCurrency = parseFloat(item.priceAtTime);
      if (item.currency !== currency) {
        priceInCartCurrency = convertCurrency(parseFloat(item.priceAtTime), item.currency, currency);
      }

      // Add to order items
      orderItems.push({
        productId: product.id,
        name: product.name,
        quantity: item.quantity,
        price: priceInCartCurrency,
        currency: currency,
        total: parseFloat((priceInCartCurrency * item.quantity).toFixed(2))
      });

      totalAmountInCartCurrency += parseFloat((priceInCartCurrency * item.quantity).toFixed(2));
    }

    // Shipping cost in requested currency (simplified - in real app this would be calculated based on distance, weight, etc.)
    const shippingCost = convertCurrency(10.00, 'USD', currency); // Base shipping cost in USD
    totalAmountInCartCurrency += shippingCost;

    // Tax calculation (simplified - 8% tax rate)
    const taxRate = 0.08;
    const taxAmount = parseFloat((totalAmountInCartCurrency * taxRate).toFixed(2));
    totalAmountInCartCurrency += taxAmount;

    // Generate identifiers
    const orderNumber = `ORD-${Date.now()}-${generateId()}`;
    const trackingNumber = `TRK-${Date.now()}-${generateId()}`;
    const estimatedDeliveryDate = new Date(Date.now() + 5 * 24 * 60 * 60 * 1000); // Default 5 days delivery window

    // Convert to USD for Stripe (Stripe processes in USD)
    const totalAmountInUSD = convertCurrency(totalAmountInCartCurrency, currency, 'USD');

    // Create payment intent with Stripe
    let paymentIntent;
    try {
      paymentIntent = await stripe.paymentIntents.create({
        amount: Math.round(totalAmountInUSD * 100), // Amount in cents (always in USD for now)
        currency: 'usd', // Stripe processes in USD
        metadata: {
          userId: userId.toString(),
          orderNumber: orderNumber,
          originalCurrency: currency,
          originalAmount: totalAmountInCartCurrency
        }
      });
    } catch (paymentError) {
      return res.status(400).json({ message: 'Payment processing failed', error: paymentError.message });
    }

    // Create order in database
    const order = await Order.create({
      userId,
      orderNumber,
      items: orderItems,
      totalAmount: totalAmountInCartCurrency,
      currency: currency,
      shippingAddress,
      billingAddress,
      paymentMethod,
      paymentStatus: 'pending',
      paymentIntentId: paymentIntent.id,
      shippingCost,
      taxAmount,
      trackingNumber,
      estimatedDelivery: estimatedDeliveryDate
    });

    // Clear the user's cart after order creation
    await Cart.destroy({
      where: { userId }
    });

    // Respond with payment intent and order details
    res.status(201).json({
      success: true,
      message: 'Order created successfully',
      order: {
        id: order.id,
        orderNumber: order.orderNumber,
        totalAmount: order.totalAmount,
        currency: order.currency,
        paymentIntent: {
          client_secret: paymentIntent.client_secret
        }
      }
    });

    // In a real application, you would process inventory reduction in a background job
    // to handle cases where payment fails after inventory reduction
    // For this example, we'll reduce inventory immediately
    for (const item of cartItems) {
      const product = item.Product;
      await Product.update(
        { 
          stockQuantity: product.stockQuantity - item.quantity,
          // Update the product if stock reaches 0 (out of stock)
          isActive: product.stockQuantity - item.quantity > 0 ? product.isActive : false
        },
        { where: { id: product.id } }
      );
    }
  } catch (error) {
    res.status(500).json({ message: 'Server error during checkout', error: error.message });
  }
};

// Process payment confirmation (when Stripe sends webhook)
const confirmPayment = async (req, res) => {
  try {
    const { paymentIntentId } = req.body;

    // Retrieve payment intent from Stripe
    const paymentIntent = await stripe.paymentIntents.retrieve(paymentIntentId);

    if (paymentIntent.status === 'succeeded') {
      // Update order status to paid
      await Order.update(
        { paymentStatus: 'paid', status: 'processing' },
        { where: { paymentIntentId } }
      );

      res.status(200).json({
        success: true,
        message: 'Payment confirmed and order updated'
      });
    } else {
      res.status(400).json({
        success: false,
        message: 'Payment not succeeded',
        status: paymentIntent.status
      });
    }
  } catch (error) {
    res.status(500).json({ message: 'Server error during payment confirmation', error: error.message });
  }
};

// Handle Stripe webhook for payment events
const handleWebhook = async (req, res) => {
  const sig = req.headers['stripe-signature'];
  const endpointSecret = process.env.STRIPE_WEBHOOK_SECRET;

  let event;

  try {
    // In a real application, you would verify the webhook signature
    // event = stripe.webhooks.constructEvent(req.body, sig, endpointSecret);
    
    // For this example, we'll trust the event without signature verification
    event = req.body;
  } catch (err) {
    console.error('Webhook signature verification failed:', err);
    return res.status(400).send(`Webhook Error: ${err.message}`);
  }

  // Handle the event
  switch (event.type) {
    case 'payment_intent.succeeded':
      const paymentIntent = event.data.object;
      
      // Update order status to paid
      await Order.update(
        { 
          paymentStatus: 'paid', 
          status: 'processing' 
        },
        { where: { paymentIntentId: paymentIntent.id } }
      );
      
      console.log('Payment succeeded for order:', paymentIntent.metadata.orderNumber);
      break;

    case 'payment_intent.payment_failed':
      const failedPaymentIntent = event.data.object;
      
      // Update order status to failed
      await Order.update(
        { 
          paymentStatus: 'failed',
          status: 'cancelled'
        },
        { where: { paymentIntentId: failedPaymentIntent.id } }
      );
      
      console.log('Payment failed for order:', failedPaymentIntent.metadata.orderNumber);
      break;

    default:
      console.log(`Unhandled event type ${event.type}`);
  }

  // Return a 200 response to acknowledge receipt of the event
  res.json({ received: true });
};

module.exports = {
  processCheckout,
  confirmPayment,
  handleWebhook
};