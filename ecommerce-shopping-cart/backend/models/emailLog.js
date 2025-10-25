const { DataTypes, Model } = require('sequelize');

module.exports = (sequelize) => {
  class EmailLog extends Model {}

  EmailLog.init(
    {
      id: {
        type: DataTypes.UUID,
        defaultValue: DataTypes.UUIDV4,
        primaryKey: true,
      },
      userId: {
        type: DataTypes.UUID,
        field: 'user_id',
      },
      emailType: {
        type: DataTypes.STRING(50),
        allowNull: false,
        field: 'email_type',
      },
      recipientEmail: {
        type: DataTypes.STRING(255),
        allowNull: false,
        field: 'recipient_email',
      },
      subject: {
        type: DataTypes.STRING(255),
        allowNull: false,
      },
      status: {
        type: DataTypes.ENUM('sent', 'failed', 'bounced'),
        defaultValue: 'sent',
      },
      externalId: {
        type: DataTypes.STRING(255),
        field: 'external_id',
      },
      errorMessage: {
        type: DataTypes.TEXT,
        field: 'error_message',
      },
      sentAt: {
        type: DataTypes.DATE,
        field: 'sent_at',
      },
      metadata: {
        type: DataTypes.JSONB,
        defaultValue: {},
      },
    },
    {
      sequelize,
      modelName: 'EmailLog',
      tableName: 'email_logs',
      underscored: true,
      timestamps: true,
    }
  );

  return EmailLog;
};
