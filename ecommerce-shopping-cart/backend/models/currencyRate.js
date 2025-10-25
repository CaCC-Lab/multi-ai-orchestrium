const { DataTypes, Model } = require('sequelize');

module.exports = (sequelize) => {
  class CurrencyRate extends Model {}

  CurrencyRate.init(
    {
      id: {
        type: DataTypes.UUID,
        defaultValue: DataTypes.UUIDV4,
        primaryKey: true,
      },
      fromCurrency: {
        type: DataTypes.STRING(3),
        allowNull: false,
        field: 'from_currency',
      },
      toCurrency: {
        type: DataTypes.STRING(3),
        allowNull: false,
        field: 'to_currency',
      },
      rate: {
        type: DataTypes.DECIMAL(12, 6),
        allowNull: false,
      },
      validFrom: {
        type: DataTypes.DATE,
        allowNull: false,
        field: 'valid_from',
      },
      validUntil: {
        type: DataTypes.DATE,
        field: 'valid_until',
      },
      createdBy: {
        type: DataTypes.UUID,
        field: 'created_by',
      },
    },
    {
      sequelize,
      modelName: 'CurrencyRate',
      tableName: 'currency_rates',
      underscored: true,
      timestamps: true,
    }
  );

  return CurrencyRate;
};
