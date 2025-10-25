const { DataTypes, Model } = require('sequelize');

module.exports = (sequelize) => {
  class Address extends Model {}

  Address.init(
    {
      id: {
        type: DataTypes.UUID,
        defaultValue: DataTypes.UUIDV4,
        primaryKey: true,
      },
      userId: {
        type: DataTypes.UUID,
        allowNull: false,
        field: 'user_id',
      },
      type: {
        type: DataTypes.ENUM('shipping', 'billing', 'both'),
        allowNull: false,
      },
      firstName: {
        type: DataTypes.STRING(100),
        allowNull: false,
        field: 'first_name',
      },
      lastName: {
        type: DataTypes.STRING(100),
        allowNull: false,
        field: 'last_name',
      },
      company: {
        type: DataTypes.STRING(150),
      },
      addressLine1: {
        type: DataTypes.STRING(255),
        allowNull: false,
        field: 'address_line1',
      },
      addressLine2: {
        type: DataTypes.STRING(255),
        field: 'address_line2',
      },
      city: {
        type: DataTypes.STRING(100),
        allowNull: false,
      },
      state: {
        type: DataTypes.STRING(100),
        allowNull: false,
      },
      postalCode: {
        type: DataTypes.STRING(20),
        allowNull: false,
        field: 'postal_code',
      },
      country: {
        type: DataTypes.STRING(2),
        allowNull: false,
      },
      phone: {
        type: DataTypes.STRING(20),
      },
      isDefault: {
        type: DataTypes.BOOLEAN,
        defaultValue: false,
        field: 'is_default',
      },
      metadata: {
        type: DataTypes.JSONB,
        defaultValue: {},
      },
    },
    {
      sequelize,
      modelName: 'Address',
      tableName: 'addresses',
      underscored: true,
      timestamps: true,
    }
  );

  return Address;
};
