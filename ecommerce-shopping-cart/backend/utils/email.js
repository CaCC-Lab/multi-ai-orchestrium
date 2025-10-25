const sgMail = require('@sendgrid/mail');
sgMail.setApiKey(process.env.SENDGRID_API_KEY);

/**
 * Send order confirmation email
 * @param {Object} order - Order object
 * @param {Object} user - User object
 * @returns {Promise}
 */
const sendOrderConfirmation = async (order, user) => {
  try {
    const msg = {
      to: user.email,
      from: 'noreply@ecommerceshop.com',
      subject: 'Order Confirmation - E-Commerce Shop',
      html: `
        <h2>Thank you for your order!</h2>
        <p>Hi ${user.name},</p>
        <p>Your order (#${order.id}) has been confirmed.</p>
        <div>
          <h3>Order Details:</h3>
          <p><strong>Order ID:</strong> ${order.id}</p>
          <p><strong>Date:</strong> ${new Date(order.createdAt).toDateString()}</p>
          <p><strong>Total:</strong> $${order.totalPrice}</p>
        </div>
        <p>You will receive another email when your order ships.</p>
        <p>Thanks,<br>The E-Commerce Team</p>
      `,
    };

    await sgMail.send(msg);
    console.log(`Order confirmation email sent to ${user.email}`);
  } catch (error) {
    console.error('Error sending order confirmation email:', error);
    if (error.response) {
      console.error(error.response.body);
    }
    throw error;
  }
};

/**
 * Send shipping notification email
 * @param {Object} order - Order object
 * @param {Object} user - User object
 * @returns {Promise}
 */
const sendShippingNotification = async (order, user) => {
  try {
    const msg = {
      to: user.email,
      from: 'noreply@ecommerceshop.com',
      subject: 'Order Shipped - E-Commerce Shop',
      html: `
        <h2>Your order has been shipped!</h2>
        <p>Hi ${user.name},</p>
        <p>Your order (#${order.id}) has been shipped.</p>
        <div>
          <h3>Order Details:</h3>
          <p><strong>Order ID:</strong> ${order.id}</p>
          <p><strong>Tracking Number:</strong> ${order.trackingNumber || 'N/A'}</p>
          <p><strong>Estimated Delivery:</strong> ${order.estimatedDelivery || 'N/A'}</p>
        </div>
        <p>We'll notify you again when your order is delivered.</p>
        <p>Thanks,<br>The E-Commerce Team</p>
      `,
    };

    await sgMail.send(msg);
    console.log(`Shipping notification email sent to ${user.email}`);
  } catch (error) {
    console.error('Error sending shipping notification email:', error);
    if (error.response) {
      console.error(error.response.body);
    }
    throw error;
  }
};

/**
 * Send delivery notification email
 * @param {Object} order - Order object
 * @param {Object} user - User object
 * @returns {Promise}
 */
const sendDeliveryNotification = async (order, user) => {
  try {
    const msg = {
      to: user.email,
      from: 'noreply@ecommerceshop.com',
      subject: 'Order Delivered - E-Commerce Shop',
      html: `
        <h2>Your order has been delivered!</h2>
        <p>Hi ${user.name},</p>
        <p>Your order (#${order.id}) has been delivered.</p>
        <div>
          <h3>Order Details:</h3>
          <p><strong>Order ID:</strong> ${order.id}</p>
          <p><strong>Delivery Date:</strong> ${new Date(order.deliveredAt).toDateString()}</p>
        </div>
        <p>Thank you for shopping with us. We hope you enjoyed your purchase!</p>
        <p>Thanks,<br>The E-Commerce Team</p>
      `,
    };

    await sgMail.send(msg);
    console.log(`Delivery notification email sent to ${user.email}`);
  } catch (error) {
    console.error('Error sending delivery notification email:', error);
    if (error.response) {
      console.error(error.response.body);
    }
    throw error;
  }
};

/**
 * Send payment confirmation email
 * @param {Object} order - Order object
 * @param {Object} user - User object
 * @returns {Promise}
 */
const sendPaymentConfirmation = async (order, user) => {
  try {
    const msg = {
      to: user.email,
      from: 'noreply@ecommerceshop.com',
      subject: 'Payment Confirmed - E-Commerce Shop',
      html: `
        <h2>Payment Confirmed for Order #${order.id}</h2>
        <p>Hi ${user.name},</p>
        <p>Your payment for order #${order.id} has been confirmed.</p>
        <div>
          <h3>Payment Details:</h3>
          <p><strong>Order ID:</strong> ${order.id}</p>
          <p><strong>Amount:</strong> $${order.totalPrice}</p>
          <p><strong>Payment Method:</strong> ${order.paymentMethod}</p>
          <p><strong>Payment Date:</strong> ${new Date(order.paidAt).toDateString()}</p>
        </div>
        <p>Your order will be processed shortly.</p>
        <p>Thanks,<br>The E-Commerce Team</p>
      `,
    };

    await sgMail.send(msg);
    console.log(`Payment confirmation email sent to ${user.email}`);
  } catch (error) {
    console.error('Error sending payment confirmation email:', error);
    if (error.response) {
      console.error(error.response.body);
    }
    throw error;
  }
};

/**
 * Send welcome email to new user
 * @param {Object} user - User object
 * @returns {Promise}
 */
const sendWelcomeEmail = async (user) => {
  try {
    const msg = {
      to: user.email,
      from: 'noreply@ecommerceshop.com',
      subject: 'Welcome to E-Commerce Shop!',
      html: `
        <h2>Welcome to our store, ${user.name}!</h2>
        <p>Thank you for registering with us.</p>
        <p>We're excited to have you as a new member of our community.</p>
        <p>Start shopping now and enjoy exclusive offers!</p>
        <p>Thanks,<br>The E-Commerce Team</p>
      `,
    };

    await sgMail.send(msg);
    console.log(`Welcome email sent to ${user.email}`);
  } catch (error) {
    console.error('Error sending welcome email:', error);
    if (error.response) {
      console.error(error.response.body);
    }
    throw error;
  }
};

/**
 * Send password reset email
 * @param {string} email - User email
 * @param {string} resetToken - Password reset token
 * @returns {Promise}
 */
const sendPasswordResetEmail = async (email, resetToken) => {
  try {
    const resetUrl = `${process.env.FRONTEND_URL}/reset-password/${resetToken}`;
    
    const msg = {
      to: email,
      from: 'noreply@ecommerceshop.com',
      subject: 'Password Reset Request',
      html: `
        <h2>Password Reset Request</h2>
        <p>You requested a password reset for your account.</p>
        <p>Click the link below to reset your password:</p>
        <a href="${resetUrl}">Reset Password</a>
        <p>This link will expire in 1 hour.</p>
        <p>If you didn't request this, please ignore this email.</p>
        <p>Thanks,<br>The E-Commerce Team</p>
      `,
    };

    await sgMail.send(msg);
    console.log(`Password reset email sent to ${email}`);
  } catch (error) {
    console.error('Error sending password reset email:', error);
    if (error.response) {
      console.error(error.response.body);
    }
    throw error;
  }
};

module.exports = {
  sendOrderConfirmation,
  sendShippingNotification,
  sendDeliveryNotification,
  sendPaymentConfirmation,
  sendWelcomeEmail,
  sendPasswordResetEmail
};