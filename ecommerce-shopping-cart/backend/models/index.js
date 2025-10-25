const { sequelize } = require('../src/config/database');

const defineUser = require('./user');
const defineCategory = require('./category');
const defineProduct = require('./product');
const defineCart = require('./cart');
const defineCartItem = require('./cartItem');
const defineAddress = require('./address');
const defineOrder = require('./order');
const defineOrderItem = require('./orderItem');
const defineInventoryTransaction = require('./inventoryTransaction');
const defineEmailLog = require('./emailLog');
const defineCurrencyRate = require('./currencyRate');
const defineRefreshToken = require('./refreshToken');

const models = {};

models.User = defineUser(sequelize);
models.Category = defineCategory(sequelize);
models.Product = defineProduct(sequelize);
models.Cart = defineCart(sequelize);
models.CartItem = defineCartItem(sequelize);
models.Address = defineAddress(sequelize);
models.Order = defineOrder(sequelize);
models.OrderItem = defineOrderItem(sequelize);
models.InventoryTransaction = defineInventoryTransaction(sequelize);
models.EmailLog = defineEmailLog(sequelize);
models.CurrencyRate = defineCurrencyRate(sequelize);
models.RefreshToken = defineRefreshToken(sequelize);

const setupAssociations = () => {
  const {
    User,
    Category,
    Product,
    Cart,
    CartItem,
    Address,
    Order,
    OrderItem,
    InventoryTransaction,
    EmailLog,
    CurrencyRate,
    RefreshToken,
  } = models;

  // User associations
  User.hasMany(Address, { foreignKey: 'userId', as: 'addresses' });
  Address.belongsTo(User, { foreignKey: 'userId', as: 'user' });

  User.hasOne(Cart, { foreignKey: 'userId', as: 'cart' });
  Cart.belongsTo(User, { foreignKey: 'userId', as: 'user' });

  User.hasMany(Order, { foreignKey: 'userId', as: 'orders' });
  Order.belongsTo(User, { foreignKey: 'userId', as: 'user' });

  User.hasMany(InventoryTransaction, { foreignKey: 'createdBy', as: 'inventoryTransactions' });
  InventoryTransaction.belongsTo(User, { foreignKey: 'createdBy', as: 'createdByUser' });

  User.hasMany(EmailLog, { foreignKey: 'userId', as: 'emailLogs' });
  EmailLog.belongsTo(User, { foreignKey: 'userId', as: 'user' });

  User.hasMany(RefreshToken, { foreignKey: 'userId', as: 'refreshTokens' });
  RefreshToken.belongsTo(User, { foreignKey: 'userId', as: 'user' });

  // Category associations
  Category.hasMany(Category, { foreignKey: 'parentId', as: 'children' });
  Category.belongsTo(Category, { foreignKey: 'parentId', as: 'parent' });

  Category.hasMany(Product, { foreignKey: 'categoryId', as: 'products' });
  Product.belongsTo(Category, { foreignKey: 'categoryId', as: 'category' });

  // Product associations
  Product.hasMany(CartItem, { foreignKey: 'productId', as: 'cartItems' });
  CartItem.belongsTo(Product, { foreignKey: 'productId', as: 'product' });

  Product.hasMany(OrderItem, { foreignKey: 'productId', as: 'orderItems' });
  OrderItem.belongsTo(Product, { foreignKey: 'productId', as: 'product' });

  Product.hasMany(InventoryTransaction, { foreignKey: 'productId', as: 'inventoryTransactions' });
  InventoryTransaction.belongsTo(Product, { foreignKey: 'productId', as: 'product' });

  // Cart associations
  Cart.hasMany(CartItem, { foreignKey: 'cartId', as: 'items', onDelete: 'CASCADE' });
  CartItem.belongsTo(Cart, { foreignKey: 'cartId', as: 'cart' });

  // Order associations
  Order.hasMany(OrderItem, { foreignKey: 'orderId', as: 'items', onDelete: 'CASCADE' });
  OrderItem.belongsTo(Order, { foreignKey: 'orderId', as: 'order' });

  Order.belongsTo(Address, { foreignKey: 'shippingAddressId', as: 'shippingAddress' });
  Order.belongsTo(Address, { foreignKey: 'billingAddressId', as: 'billingAddress' });

  // Currency rate associations
  CurrencyRate.belongsTo(User, { foreignKey: 'createdBy', as: 'createdByUser' });
  User.hasMany(CurrencyRate, { foreignKey: 'createdBy', as: 'currencyRates' });
};

let initialized = false;

const initializeModels = async () => {
  if (initialized) {
    return;
  }

  setupAssociations();

  if (process.env.NODE_ENV === 'test') {
    await sequelize.sync({ force: true });
  }

  initialized = true;
};

module.exports = {
  sequelize,
  initializeModels,
  ...models,
};