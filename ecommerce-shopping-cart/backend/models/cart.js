const { DataTypes, Model } = require('sequelize');

module.exports = (sequelize) => {
  class Cart extends Model {}

  Cart.init(
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
      sessionId: {
        type: DataTypes.STRING(255),
        field: 'session_id',
      },
      currency: {
        type: DataTypes.STRING(3),
        defaultValue: 'USD',
      },
      subtotal: {
        type: DataTypes.DECIMAL(10, 2),
        defaultValue: 0,
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
      total: {
        type: DataTypes.DECIMAL(10, 2),
        defaultValue: 0,
      },
      itemCount: {
        type: DataTypes.INTEGER,
        defaultValue: 0,
        field: 'item_count',
      },
      expiresAt: {
        type: DataTypes.DATE,
        field: 'expires_at',
      },
    },
    {
      sequelize,
      modelName: 'Cart',
      tableName: 'carts',
      underscored: true,
      timestamps: true,
    }
  );

  return Cart;
};
