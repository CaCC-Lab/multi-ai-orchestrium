const nodemailer = require('nodemailer');
require('dotenv').config();

// Create transporter for sending emails
const transporter = nodemailer.createTransport({
  host: process.env.EMAIL_HOST,
  port: process.env.EMAIL_PORT,
  secure: false, // true for 465, false for other ports
  auth: {
    user: process.env.EMAIL_USER,
    pass: process.env.EMAIL_PASS
  }
});

// Verify transporter configuration
if (process.env.NODE_ENV !== 'test') {
  transporter.verify((error, success) => {
    if (error) {
      console.log('Email transporter configuration error:', error);
    } else {
      console.log('Email transporter is ready to send messages');
    }
  });
}

// Send order confirmation email
const sendOrderConfirmation = async (user, order) => {
  try {
    const mailOptions = {
      from: process.env.EMAIL_FROM || 'noreply@ecommerce.com',
      to: user.email,
      subject: `Order Confirmation - ${order.orderNumber}`,
      html: `
        <h2>Order Confirmation</h2>
        <p>Dear ${user.firstName} ${user.lastName},</p>
        <p>Thank you for your order! Your order has been received and is being processed.</p>
        
        <h3>Order Details</h3>
        <p><strong>Order Number:</strong> ${order.orderNumber}</p>
        <p><strong>Order Date:</strong> ${new Date(order.createdAt).toLocaleDateString()}</p>
        <p><strong>Total Amount:</strong> $${order.totalAmount}</p>
        
        <h3>Items Ordered</h3>
        <ul>
          ${order.items.map(item => `
            <li>
              ${item.name} - Quantity: ${item.quantity} - Price: $${item.price} - Total: $${item.total}
            </li>
          `).join('')}
        </ul>
        
        <p><strong>Shipping Address:</strong></p>
        <p>${order.shippingAddress.street}, ${order.shippingAddress.city}, ${order.shippingAddress.state} ${order.shippingAddress.zip}, ${order.shippingAddress.country}</p>
        
        <p><strong>Current Status:</strong> ${order.status}</p>
        
        <p>You can track your order using the order number on our website.</p>
        
        <p>Thank you for shopping with us!</p>
        <p>The E-commerce Team</p>
      `
    };

    const info = await transporter.sendMail(mailOptions);
    console.log('Order confirmation email sent: ' + info.response);
    return info;
  } catch (error) {
    console.error('Error sending order confirmation email:', error);
    throw error;
  }
};

// Send order status update email
const sendOrderStatusUpdate = async (user, order) => {
  try {
    let statusMessage = '';
    switch (order.status) {
      case 'shipped':
        statusMessage = 'Your order has been shipped and is on its way to you!';
        break;
      case 'delivered':
        statusMessage = 'Your order has been delivered!';
        break;
      case 'cancelled':
        statusMessage = 'Your order has been cancelled.';
        break;
      default:
        statusMessage = `Your order status has been updated to "${order.status}".`;
    }

    const mailOptions = {
      from: process.env.EMAIL_FROM || 'noreply@ecommerce.com',
      to: user.email,
      subject: `Order Status Update - ${order.orderNumber}`,
      html: `
        <h2>Order Status Update</h2>
        <p>Dear ${user.firstName} ${user.lastName},</p>
        <p>${statusMessage}</p>
        
        <h3>Order Details</h3>
        <p><strong>Order Number:</strong> ${order.orderNumber}</p>
        <p><strong>Status:</strong> ${order.status}</p>
        
        <p>You can track your order using the order number on our website.</p>
        
        <p>If you have any questions, please contact our support team.</p>
        
        <p>The E-commerce Team</p>
      `
    };

    const info = await transporter.sendMail(mailOptions);
    console.log('Order status update email sent: ' + info.response);
    return info;
  } catch (error) {
    console.error('Error sending order status update email:', error);
    throw error;
  }
};

// Send low stock notification to admin
const sendLowStockNotification = async (adminEmail, product) => {
  try {
    const mailOptions = {
      from: process.env.EMAIL_FROM || 'noreply@ecommerce.com',
      to: adminEmail,
      subject: `Low Stock Alert - ${product.name}`,
      html: `
        <h2>Low Stock Alert</h2>
        <p>The stock for the following product is running low:</p>
        
        <h3>Product Details</h3>
        <p><strong>Product Name:</strong> ${product.name}</p>
        <p><strong>SKU:</strong> ${product.sku}</p>
        <p><strong>Current Stock:</strong> ${product.stockQuantity}</p>
        <p><strong>Category:</strong> ${product.category}</p>
        
        <p>Please restock this item as soon as possible to avoid out of stock situations.</p>
        
        <p>E-commerce Inventory Management System</p>
      `
    };

    const info = await transporter.sendMail(mailOptions);
    console.log('Low stock notification email sent: ' + info.response);
    return info;
  } catch (error) {
    console.error('Error sending low stock notification email:', error);
    throw error;
  }
};

// Send out of stock notification to admin
const sendOutOfStockNotification = async (adminEmail, product) => {
  try {
    const mailOptions = {
      from: process.env.EMAIL_FROM || 'noreply@ecommerce.com',
      to: adminEmail,
      subject: `Out of Stock Alert - ${product.name}`,
      html: `
        <h2>Out of Stock Alert</h2>
        <p>The following product is now out of stock:</p>
        
        <h3>Product Details</h3>
        <p><strong>Product Name:</strong> ${product.name}</p>
        <p><strong>SKU:</strong> ${product.sku}</p>
        <p><strong>Category:</strong> ${product.category}</p>
        
        <p>This product is no longer available for purchase until it is restocked.</p>
        
        <p>Please restock this item as soon as possible.</p>
        
        <p>E-commerce Inventory Management System</p>
      `
    };

    const info = await transporter.sendMail(mailOptions);
    console.log('Out of stock notification email sent: ' + info.response);
    return info;
  } catch (error) {
    console.error('Error sending out of stock notification email:', error);
    throw error;
  }
};

module.exports = {
  sendOrderConfirmation,
  sendOrderStatusUpdate,
  sendLowStockNotification,
  sendOutOfStockNotification
};