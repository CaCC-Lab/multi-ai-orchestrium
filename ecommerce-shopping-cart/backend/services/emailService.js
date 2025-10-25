// services/emailService.js
const sgMail = require('@sendgrid/mail');
sgMail.setApiKey(process.env.SENDGRID_API_KEY);

// Send order confirmation email
const sendOrderConfirmation = async (user, order) => {
  try {
    const msg = {
      to: user.email,
      from: process.env.EMAIL_FROM,
      subject: 'Order Confirmation - E-commerce Store',
      html: `
        <h2>Order Confirmation</h2>
        <p>Dear ${user.firstName} ${user.lastName},</p>
        <p>Thank you for your order! Your order #${order.id} has been confirmed.</p>
        <p><strong>Total Amount:</strong> $${order.totalAmount}</p>
        <p><strong>Status:</strong> ${order.status}</p>
        <p><strong>Shipping Address:</strong></p>
        <p>
          ${order.shippingAddress.fullName}<br>
          ${order.shippingAddress.address}<br>
          ${order.shippingAddress.city}, ${order.shippingAddress.state} ${order.shippingAddress.zipCode}<br>
          ${order.shippingAddress.country}
        </p>
        <p>You will receive another email when your order is shipped.</p>
        <p>Best regards,<br>E-commerce Store Team</p>
      `,
    };

    await sgMail.send(msg);
    console.log(`Order confirmation email sent to ${user.email}`);
  } catch (error) {
    console.error('Error sending order confirmation email:', error);
    if (error.response) {
      console.error(error.response.body);
    }
  }
};

// Send order shipped email
const sendOrderShipped = async (user, order) => {
  try {
    const msg = {
      to: user.email,
      from: process.env.EMAIL_FROM,
      subject: 'Order Shipped - E-commerce Store',
      html: `
        <h2>Your Order Has Been Shipped</h2>
        <p>Dear ${user.firstName} ${user.lastName},</p>
        <p>Your order #${order.id} has been shipped.</p>
        <p><strong>Tracking Information:</strong> Will be provided shortly</p>
        <p><strong>Estimated Delivery:</strong> 3-5 business days</p>
        <p>If you have any questions, please contact our customer service team.</p>
        <p>Best regards,<br>E-commerce Store Team</p>
      `,
    };

    await sgMail.send(msg);
    console.log(`Order shipped email sent to ${user.email}`);
  } catch (error) {
    console.error('Error sending order shipped email:', error);
    if (error.response) {
      console.error(error.response.body);
    }
  }
};

// Send low stock alert to admin
const sendLowStockAlert = async (adminEmail, products) => {
  try {
    const productDetails = products.map(p => 
      `<li>${p.name} - ${p.stockQuantity} remaining</li>`
    ).join('');

    const msg = {
      to: adminEmail,
      from: process.env.EMAIL_FROM,
      subject: 'Low Stock Alert - E-commerce Store',
      html: `
        <h2>Low Stock Alert</h2>
        <p>The following products are running low on stock:</p>
        <ul>${productDetails}</ul>
        <p>Please restock these items as soon as possible.</p>
      `,
    };

    await sgMail.send(msg);
    console.log(`Low stock alert email sent to ${adminEmail}`);
  } catch (error) {
    console.error('Error sending low stock alert email:', error);
    if (error.response) {
      console.error(error.response.body);
    }
  }
};

// Send registration welcome email
const sendWelcomeEmail = async (user) => {
  try {
    const msg = {
      to: user.email,
      from: process.env.EMAIL_FROM,
      subject: 'Welcome to Our E-commerce Store!',
      html: `
        <h2>Welcome ${user.firstName}!</h2>
        <p>Thank you for registering with our e-commerce store.</p>
        <p>Start shopping now and enjoy our exclusive offers for new customers!</p>
        <p>Best regards,<br>E-commerce Store Team</p>
      `,
    };

    await sgMail.send(msg);
    console.log(`Welcome email sent to ${user.email}`);
  } catch (error) {
    console.error('Error sending welcome email:', error);
    if (error.response) {
      console.error(error.response.body);
    }
  }
};

module.exports = {
  sendOrderConfirmation,
  sendOrderShipped,
  sendLowStockAlert,
  sendWelcomeEmail
};