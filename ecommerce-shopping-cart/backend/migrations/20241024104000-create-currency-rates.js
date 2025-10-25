'use strict';

module.exports = {
  async up(queryInterface, Sequelize) {
    await queryInterface.createTable('currency_rates', {
      id: {
        type: Sequelize.UUID,
        primaryKey: true,
        allowNull: false,
        defaultValue: Sequelize.literal('uuid_generate_v4()'),
      },
      from_currency: {
        type: Sequelize.STRING(3),
        allowNull: false,
      },
      to_currency: {
        type: Sequelize.STRING(3),
        allowNull: false,
      },
      rate: {
        type: Sequelize.DECIMAL(12, 6),
        allowNull: false,
      },
      valid_from: {
        type: Sequelize.DATE,
        allowNull: false,
      },
      valid_until: {
        type: Sequelize.DATE,
      },
      created_by: {
        type: Sequelize.UUID,
        references: {
          model: 'users',
          key: 'id',
        },
        onDelete: 'SET NULL',
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

    await queryInterface.addConstraint('currency_rates', {
      fields: ['from_currency', 'to_currency', 'valid_from'],
      type: 'unique',
      name: 'currency_rates_unique_period',
    });

    await queryInterface.addIndex('currency_rates', ['from_currency', 'to_currency']);
    await queryInterface.addIndex('currency_rates', ['valid_from']);
  },

  async down(queryInterface) {
    await queryInterface.dropTable('currency_rates');
  },
};
