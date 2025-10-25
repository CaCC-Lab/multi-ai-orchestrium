const { DataTypes, Model } = require('sequelize');

module.exports = (sequelize) => {
  class Product extends Model {}

  Product.init(
    {
      id: {
        type: DataTypes.UUID,
        primaryKey: true,
        defaultValue: DataTypes.UUIDV4,
      },
      sku: {
        type: DataTypes.STRING(50),
        allowNull: false,
        unique: true,
      },
      name: {
        type: DataTypes.STRING(255),
        allowNull: false,
      },
      slug: {
        type: DataTypes.STRING(255),
        allowNull: false,
        unique: true,
      },
      description: {
        type: DataTypes.TEXT,
      },
      shortDescription: {
        type: DataTypes.STRING(500),
        field: 'short_description',
      },
      categoryId: {
        type: DataTypes.UUID,
        field: 'category_id',
      },
      price: {
        type: DataTypes.DECIMAL(10, 2),
        allowNull: false,
        validate: { min: 0 },
      },
      compareAtPrice: {
        type: DataTypes.DECIMAL(10, 2),
        field: 'compare_at_price',
        validate: { min: 0 },
      },
      cost: {
        type: DataTypes.DECIMAL(10, 2),
        validate: { min: 0 },
      },
      currency: {
        type: DataTypes.STRING(3),
        defaultValue: 'USD',
      },
      stockQuantity: {
        type: DataTypes.INTEGER,
        defaultValue: 0,
        field: 'stock_quantity',
        validate: { min: 0 },
      },
      lowStockThreshold: {
        type: DataTypes.INTEGER,
        defaultValue: 10,
        field: 'low_stock_threshold',
      },
      weight: {
        type: DataTypes.DECIMAL(10, 2),
      },
      dimensions: {
        type: DataTypes.STRING(100),
      },
      isActive: {
        type: DataTypes.BOOLEAN,
        defaultValue: true,
        field: 'is_active',
      },
      isFeatured: {
        type: DataTypes.BOOLEAN,
        defaultValue: false,
        field: 'is_featured',
      },
      rating: {
        type: DataTypes.DECIMAL(3, 2),
        defaultValue: 0,
        validate: { min: 0, max: 5 },
      },
      reviewCount: {
        type: DataTypes.INTEGER,
        defaultValue: 0,
        field: 'review_count',
      },
      images: {
        type: DataTypes.JSONB,
        defaultValue: [],
      },
      metadata: {
        type: DataTypes.JSONB,
        defaultValue: {},
      },
      seoTitle: {
        type: DataTypes.STRING(255),
        field: 'seo_title',
      },
      seoDescription: {
        type: DataTypes.STRING(500),
        field: 'seo_description',
      },
    },
    {
      sequelize,
      modelName: 'Product',
      tableName: 'products',
      underscored: true,
      timestamps: true,
    }
  );

  return Product;
};
