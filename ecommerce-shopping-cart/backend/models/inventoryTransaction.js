const { DataTypes, Model } = require('sequelize');

module.exports = (sequelize) => {
  class InventoryTransaction extends Model {}

  InventoryTransaction.init(
    {
      id: {
        type: DataTypes.UUID,
        defaultValue: DataTypes.UUIDV4,
        primaryKey: true,
      },
      productId: {
        type: DataTypes.UUID,
        allowNull: false,
        field: 'product_id',
      },
      type: {
        type: DataTypes.ENUM('purchase', 'sale', 'adjustment', 'return'),
        allowNull: false,
      },
      quantity: {
        type: DataTypes.INTEGER,
        allowNull: false,
      },
      referenceType: {
        type: DataTypes.STRING(100),
        field: 'reference_type',
      },
      referenceId: {
        type: DataTypes.UUID,
        field: 'reference_id',
      },
      notes: {
        type: DataTypes.TEXT,
      },
      createdBy: {
        type: DataTypes.UUID,
        field: 'created_by',
      },
      metadata: {
        type: DataTypes.JSONB,
        defaultValue: {},
      },
    },
    {
      sequelize,
      modelName: 'InventoryTransaction',
      tableName: 'inventory_transactions',
      underscored: true,
      timestamps: true,
      createdAt: 'created_at',
      updatedAt: 'updated_at',
    }
  );

  return InventoryTransaction;
};
