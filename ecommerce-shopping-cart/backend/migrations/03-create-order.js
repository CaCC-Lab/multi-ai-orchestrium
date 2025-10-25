'use strict';

module.exports = {
  up: async (queryInterface, Sequelize) => {
    await queryInterface.createTable('Orders', {
      id: {
        allowNull: false,
        autoIncrement: true,
        primaryKey: true,
        type: Sequelize.INTEGER
      },
      orderItems: {
        type: Sequelize.JSONB, // Store as JSONB for PostgreSQL
        allowNull: false
      },
      shippingAddress: {
        type: Sequelize.JSONB,
        allowNull: false
      },
      paymentMethod: {
        type: Sequelize.STRING,
        allowNull: false
      },
      paymentResult: {
        type: Sequelize.JSONB // Store payment result details
      },
      taxPrice: {
        type: Sequelize.DECIMAL(10, 2),
        defaultValue: 0.00
      },
      shippingPrice: {
        type: Sequelize.DECIMAL(10, 2),
        defaultValue: 0.00
      },
      totalPrice: {
        type: Sequelize.DECIMAL(10, 2),
        defaultValue: 0.00
      },
      isPaid: {
        type: Sequelize.BOOLEAN,
        defaultValue: false
      },
      paidAt: {
        type: Sequelize.DATE
      },
      isDelivered: {
        type: Sequelize.BOOLEAN,
        defaultValue: false
      },
      deliveredAt: {
        type: Sequelize.DATE
      },
      currency: {
        type: Sequelize.STRING,
        defaultValue: 'USD'
      },
      createdAt: {
        allowNull: false,
        type: Sequelize.DATE
      },
      updatedAt: {
        allowNull: false,
        type: Sequelize.DATE
      }
    });
  },
  down: async (queryInterface, Sequelize) => {
    await queryInterface.dropTable('Orders');
  }
};