'use strict';

module.exports = {
  async up(queryInterface, Sequelize) {
    await queryInterface.createTable('carts', {
      id: {
        type: Sequelize.UUID,
        primaryKey: true,
        allowNull: false,
        defaultValue: Sequelize.literal('uuid_generate_v4()'),
      },
      user_id: {
        type: Sequelize.UUID,
        references: {
          model: 'users',
          key: 'id',
        },
        onDelete: 'CASCADE',
      },
      session_id: {
        type: Sequelize.STRING(255),
      },
      currency: {
        type: Sequelize.STRING(3),
        defaultValue: 'USD',
      },
      subtotal: {
        type: Sequelize.DECIMAL(10, 2),
        defaultValue: 0,
      },
      tax: {
        type: Sequelize.DECIMAL(10, 2),
        defaultValue: 0,
      },
      shipping_cost: {
        type: Sequelize.DECIMAL(10, 2),
        defaultValue: 0,
      },
      total: {
        type: Sequelize.DECIMAL(10, 2),
        defaultValue: 0,
      },
      item_count: {
        type: Sequelize.INTEGER,
        defaultValue: 0,
      },
      expires_at: {
        type: Sequelize.DATE,
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

    await queryInterface.addIndex('carts', ['user_id']);
    await queryInterface.addIndex('carts', ['session_id']);
  },

  async down(queryInterface) {
    await queryInterface.dropTable('carts');
  },
};
