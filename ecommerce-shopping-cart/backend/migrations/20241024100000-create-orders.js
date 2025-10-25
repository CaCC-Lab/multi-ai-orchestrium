'use strict';

module.exports = {
  async up(queryInterface, Sequelize) {
    await queryInterface.createTable('orders', {
      id: {
        type: Sequelize.UUID,
        primaryKey: true,
        allowNull: false,
        defaultValue: Sequelize.literal('uuid_generate_v4()'),
      },
      order_number: {
        type: Sequelize.STRING(60),
        allowNull: false,
        unique: true,
      },
      user_id: {
        type: Sequelize.UUID,
        allowNull: false,
        references: {
          model: 'users',
          key: 'id',
        },
        onDelete: 'RESTRICT',
      },
      status: {
        type: Sequelize.ENUM(
          'pending',
          'processing',
          'paid',
          'shipped',
          'delivered',
          'cancelled',
          'refunded',
          'failed'
        ),
        defaultValue: 'pending',
      },
      payment_status: {
        type: Sequelize.ENUM('pending', 'authorized', 'paid', 'failed', 'refunded', 'partially_refunded'),
        defaultValue: 'pending',
      },
      payment_method: {
        type: Sequelize.STRING(50),
      },
      payment_intent_id: {
        type: Sequelize.STRING(255),
      },
      currency: {
        type: Sequelize.STRING(3),
        defaultValue: 'USD',
      },
      subtotal: {
        type: Sequelize.DECIMAL(10, 2),
        allowNull: false,
      },
      tax: {
        type: Sequelize.DECIMAL(10, 2),
        defaultValue: 0,
      },
      shipping_cost: {
        type: Sequelize.DECIMAL(10, 2),
        defaultValue: 0,
      },
      discount: {
        type: Sequelize.DECIMAL(10, 2),
        defaultValue: 0,
      },
      total: {
        type: Sequelize.DECIMAL(10, 2),
        allowNull: false,
      },
      shipping_address_id: {
        type: Sequelize.UUID,
        references: {
          model: 'addresses',
          key: 'id',
        },
        onDelete: 'SET NULL',
      },
      billing_address_id: {
        type: Sequelize.UUID,
        references: {
          model: 'addresses',
          key: 'id',
        },
        onDelete: 'SET NULL',
      },
      tracking_number: {
        type: Sequelize.STRING(120),
      },
      shipped_at: {
        type: Sequelize.DATE,
      },
      delivered_at: {
        type: Sequelize.DATE,
      },
      cancelled_at: {
        type: Sequelize.DATE,
      },
      notes: {
        type: Sequelize.TEXT,
      },
      metadata: {
        type: Sequelize.JSONB,
        defaultValue: {},
      },
      created_at: {
        allowNull: false,
        type: Sequelize.DATE,
        defaultValue: Sequelize.fn('NOW'),
      },
      updated_at: {
        allowNull: false,
        type: Sequelize.DATE,
        defaultValue: Sequelize.fn('NOW'),
      },
    });

    await queryInterface.addIndex('orders', ['user_id']);
    await queryInterface.addIndex('orders', ['status']);
    await queryInterface.addIndex('orders', ['payment_status']);
    await queryInterface.addIndex('orders', ['order_number']);
  },

  async down(queryInterface) {
    await queryInterface.dropTable('orders');
  },
};
