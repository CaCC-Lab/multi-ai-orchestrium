const { DataTypes, Model } = require('sequelize');

module.exports = (sequelize) => {
  class Order extends Model {}

  Order.init(
    {
      id: {
        type: DataTypes.UUID,
        defaultValue: DataTypes.UUIDV4,
        primaryKey: true,
      },
      orderNumber: {
        type: DataTypes.STRING(60),
        allowNull: false,
        unique: true,
        field: 'order_number',
      },
      userId: {
        type: DataTypes.UUID,
        allowNull: false,
        field: 'user_id',
      },
      status: {
        type: DataTypes.ENUM(
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
      paymentStatus: {
        type: DataTypes.ENUM('pending', 'authorized', 'paid', 'failed', 'refunded', 'partially_refunded'),
        defaultValue: 'pending',
        field: 'payment_status',
      },
      paymentMethod: {
        type: DataTypes.STRING(50),
        field: 'payment_method',
      },
      paymentIntentId: {
        type: DataTypes.STRING(255),
        field: 'payment_intent_id',
      },
      currency: {
        type: DataTypes.STRING(3),
        defaultValue: 'USD',
      },
      subtotal: {
        type: DataTypes.DECIMAL(10, 2),
        allowNull: false,
      },
      tax: {
        type: DataTypes.DECIMAL(10, 2),
        defaultValue: 0,
      },
      shippingCost: {
        type: DataTypes.DECIMAL(10, 2),
        defaultValue: 0,
        field: 'shipping_cost',
      },
      discount: {
        type: DataTypes.DECIMAL(10, 2),
        defaultValue: 0,
      },
      total: {
        type: DataTypes.DECIMAL(10, 2),
        allowNull: false,
      },
      shippingAddressId: {
        type: DataTypes.UUID,
        field: 'shipping_address_id',
      },
      billingAddressId: {
        type: DataTypes.UUID,
        field: 'billing_address_id',
      },
      trackingNumber: {
        type: DataTypes.STRING(120),
        field: 'tracking_number',
      },
      shippedAt: {
        type: DataTypes.DATE,
        field: 'shipped_at',
      },
      deliveredAt: {
        type: DataTypes.DATE,
        field: 'delivered_at',
      },
      cancelledAt: {
        type: DataTypes.DATE,
        field: 'cancelled_at',
      },
      notes: {
        type: DataTypes.TEXT,
      },
      metadata: {
        type: DataTypes.JSONB,
        defaultValue: {},
      },
    },
    {
      sequelize,
      modelName: 'Order',
      tableName: 'orders',
      underscored: true,
      timestamps: true,
    }
  );

  return Order;
};
