const { getSupportedCurrencies } = require('../utils/currencies');

// Middleware to validate and set currency for requests
const currencyMiddleware = (req, res, next) => {
  // Get currency from query params, headers, or default to USD
  let currency = req.query.currency || req.headers['x-currency'] || 'USD';
  
  // Normalize to uppercase
  currency = currency.toUpperCase();
  
  // Validate currency
  const supportedCurrencies = getSupportedCurrencies();
  if (!supportedCurrencies.includes(currency)) {
    // Default to USD if currency is not supported
    currency = 'USD';
  }
  
  // Set the currency for this request
  req.currency = currency;
  
  next();
};

module.exports = currencyMiddleware;