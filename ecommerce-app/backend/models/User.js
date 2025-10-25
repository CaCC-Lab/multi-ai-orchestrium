const { DataTypes } = require('sequelize');
const sequelize = require('../config/db');

const User = sequelize.define('User', {
  id: {
    type: DataTypes.INTEGER,
    primaryKey: true,
    autoIncrement: true
  },
  firstName: {
    type: DataTypes.STRING,
    allowNull: false
  },
  lastName: {
    type: DataTypes.STRING,
    allowNull: false
  },
  email: {
    type: DataTypes.STRING,
    allowNull: false,
    unique: true,
    validate: {
      isEmail: true
    }
  },
  password: {
    type: DataTypes.STRING,
    allowNull: false,
    validate: {
      len: [6, 100] // Password must be at least 6 characters long
    }
  },
  role: {
    type: DataTypes.ENUM('customer', 'admin'),
    defaultValue: 'customer'
  },
  phone: {
    type: DataTypes.STRING
  },
  address: {
    type: DataTypes.JSON // Store as JSON object
  },
  isActive: {
    type: DataTypes.BOOLEAN,
    defaultValue: true
  }
}, {
  tableName: 'users',
  timestamps: true,
  indexes: [
    {
      fields: ['email'] // Index for faster email lookups (unique is already indexed)
    },
    {
      fields: ['role'] // Index for faster role-based queries
    },
    {
      fields: ['isActive'] // Index for faster active user filtering
    },
    {
      fields: ['role', 'isActive'] // Composite index for admin/active combinations
    }
  ]
});

module.exports = User;