const { DataTypes } = require('sequelize');
const { sequelize } = require('../config/db');

const User = sequelize.define('User', {
  id: {
    type: DataTypes.INTEGER,
    primaryKey: true,
    autoIncrement: true
  },
  firstName: {
    type: DataTypes.STRING,
    allowNull: false,
    index: true // Add index for searching
  },
  lastName: {
    type: DataTypes.STRING,
    allowNull: false,
    index: true // Add index for searching
  },
  email: {
    type: DataTypes.STRING,
    allowNull: false,
    unique: true,
    index: true, // Add index for quick lookups
    validate: {
      isEmail: true
    }
  },
  password: {
    type: DataTypes.STRING,
    allowNull: false,
    minLength: 6
  },
  role: {
    type: DataTypes.ENUM('user', 'admin'),
    defaultValue: 'user',
    index: true // Add index for role-based queries
  },
  phone: {
    type: DataTypes.STRING,
    index: true // Add index for searching
  },
  address: {
    type: DataTypes.JSONB
  },
  isActive: {
    type: DataTypes.BOOLEAN,
    defaultValue: true,
    index: true // Add index for filtering
  }
}, {
  tableName: 'users',
  timestamps: true,
  indexes: [
    {
      unique: true,
      fields: ['email']
    },
    {
      fields: ['firstName', 'lastName'] // Composite index for name searches
    }
  ]
});

module.exports = User;