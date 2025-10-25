const sgMail = require('@sendgrid/mail');
require('dotenv').config();

sgMail.setApiKey(process.env.SENDGRID_API_KEY);

// Generic send email function
const sendEmail = async (options) => {
  const msg = {
    to: options.email,
    from: process.env.FROM_EMAIL || 'noreply@ecommercesite.com',
    subject: options.subject,
    text: options.text || options.message,
    html: options.html || `<p>${options.message}</p>`,
  };

  await sgMail.send(msg);
};

// Send order confirmation email
const sendOrderConfirmation = async (order, user) => {
  const html = `
    <h2>Order Confirmation</h2>
    <p>Dear ${user.firstName},</p>
    <p>Thank you for your order! Here are the details:</p>
    <p><strong>Order Number:</strong> ${order.orderNumber}</p>
    <p><strong>Total Amount:</strong> $${order.totalAmount}</p>
    <p><strong>Status:</strong> ${order.status}</p>
    <p><strong>Shipping Address:</strong></p>
    <p>
      ${order.shippingAddress.address}<br>
      ${order.shippingAddress.city}, ${order.shippingAddress.postalCode}, ${order.shippingAddress.country}
    </p>
    <p>Thank you for shopping with us!</p>
  `;

  await sendEmail({
    email: user.email,
    subject: `Order Confirmation - ${order.orderNumber}`,
    html
  });
};

// Send shipping notification
const sendShippingNotification = async (order, user) => {
  const html = `
    <h2>Shipping Notification</h2>
    <p>Dear ${user.firstName},</p>
    <p>Your order #${order.orderNumber} has been shipped!</p>
    <p><strong>Tracking Number:</strong> ${order.trackingNumber || 'N/A'}</p>
    <p>Estimated delivery: Within 3-5 business days</p>
    <p>Thank you for shopping with us!</p>
  `;

  await sendEmail({
    email: user.email,
    subject: `Order Shipped - ${order.orderNumber}`,
    html
  });
};

// Send password reset email
const sendPasswordReset = async (user, resetUrl) => {
  const html = `
    <h2>Password Reset</h2>
    <p>Dear ${user.firstName},</p>
    <p>You requested a password reset. Please click the link below to reset your password:</p>
    <p><a href="${resetUrl}">Reset Password</a></p>
    <p>If you did not request this, please ignore this email.</p>
    <p>Link expires in 10 minutes.</p>
  `;

  await sendEmail({
    email: user.email,
    subject: 'Password Reset Request',
    html
  });
};

// Send welcome email
const sendWelcomeEmail = async (user) => {
  const html = `
    <h2>Welcome to Our Store!</h2>
    <p>Dear ${user.firstName},</p>
    <p>Thank you for registering with us!</p>
    <p>Welcome to our platform. We're excited to have you as a customer.</p>
    <p>Start shopping now and enjoy exclusive offers for new customers!</p>
    <p>Thank you!</p>
  `;

  await sendEmail({
    email: user.email,
    subject: 'Welcome to Our Store!',
    html
  });
};

module.exports = {
  sendEmail,
  sendOrderConfirmation,
  sendShippingNotification,
  sendPasswordReset,
  sendWelcomeEmail
};