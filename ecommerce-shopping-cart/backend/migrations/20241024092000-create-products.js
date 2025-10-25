'use strict';

module.exports = {
  async up(queryInterface, Sequelize) {
    await queryInterface.createTable('products', {
      id: {
        type: Sequelize.UUID,
        primaryKey: true,
        allowNull: false,
        defaultValue: Sequelize.literal('uuid_generate_v4()'),
      },
      sku: {
        type: Sequelize.STRING(50),
        allowNull: false,
        unique: true,
      },
      name: {
        type: Sequelize.STRING(255),
        allowNull: false,
      },
      slug: {
        type: Sequelize.STRING(255),
        allowNull: false,
        unique: true,
      },
      description: {
        type: Sequelize.TEXT,
      },
      short_description: {
        type: Sequelize.STRING(500),
      },
      category_id: {
        type: Sequelize.UUID,
        references: {
          model: 'categories',
          key: 'id',
        },
        onDelete: 'SET NULL',
      },
      price: {
        type: Sequelize.DECIMAL(10, 2),
        allowNull: false,
      },
      compare_at_price: {
        type: Sequelize.DECIMAL(10, 2),
      },
      cost: {
        type: Sequelize.DECIMAL(10, 2),
      },
      currency: {
        type: Sequelize.STRING(3),
        defaultValue: 'USD',
      },
      stock_quantity: {
        type: Sequelize.INTEGER,
        defaultValue: 0,
      },
      low_stock_threshold: {
        type: Sequelize.INTEGER,
        defaultValue: 10,
      },
      weight: {
        type: Sequelize.DECIMAL(10, 2),
      },
      dimensions: {
        type: Sequelize.STRING(100),
      },
      is_active: {
        type: Sequelize.BOOLEAN,
        defaultValue: true,
      },
      is_featured: {
        type: Sequelize.BOOLEAN,
        defaultValue: false,
      },
      rating: {
        type: Sequelize.DECIMAL(3, 2),
        defaultValue: 0,
      },
      review_count: {
        type: Sequelize.INTEGER,
        defaultValue: 0,
      },
      images: {
        type: Sequelize.JSONB,
        defaultValue: [],
      },
      metadata: {
        type: Sequelize.JSONB,
        defaultValue: {},
      },
      seo_title: {
        type: Sequelize.STRING(255),
      },
      seo_description: {
        type: Sequelize.STRING(500),
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

    await queryInterface.addIndex('products', ['sku']);
    await queryInterface.addIndex('products', ['slug']);
    await queryInterface.addIndex('products', ['category_id']);
    await queryInterface.addIndex('products', ['is_active']);
    await queryInterface.addIndex('products', ['price']);
    await queryInterface.sequelize.query(
      "CREATE INDEX IF NOT EXISTS products_name_fulltext ON products USING GIN (to_tsvector('english', name));"
    );
    await queryInterface.sequelize.query(
      "CREATE INDEX IF NOT EXISTS products_description_fulltext ON products USING GIN (to_tsvector('english', description));"
    );
  },

  async down(queryInterface) {
    await queryInterface.dropTable('products');
  },
};
