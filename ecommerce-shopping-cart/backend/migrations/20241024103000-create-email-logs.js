'use strict';

module.exports = {
  async up(queryInterface, Sequelize) {
    await queryInterface.createTable('email_logs', {
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
        onDelete: 'SET NULL',
      },
      email_type: {
        type: Sequelize.STRING(50),
        allowNull: false,
      },
      recipient_email: {
        type: Sequelize.STRING(255),
        allowNull: false,
      },
      subject: {
        type: Sequelize.STRING(255),
        allowNull: false,
      },
      status: {
        type: Sequelize.ENUM('sent', 'failed', 'bounced'),
        defaultValue: 'sent',
      },
      external_id: {
        type: Sequelize.STRING(255),
      },
      error_message: {
        type: Sequelize.TEXT,
      },
      sent_at: {
        type: Sequelize.DATE,
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

    await queryInterface.addIndex('email_logs', ['user_id']);
    await queryInterface.addIndex('email_logs', ['email_type']);
    await queryInterface.addIndex('email_logs', ['status']);
  },

  async down(queryInterface) {
    await queryInterface.dropTable('email_logs');
  },
};
