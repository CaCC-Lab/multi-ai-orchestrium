// Currency conversion rates (in a real app, these would be fetched from an API)
const EXCHANGE_RATES = {
  USD: 1,        // US Dollar (base currency)
  EUR: 0.85,     // Euro
  GBP: 0.73,     // British Pound
  JPY: 110,      // Japanese Yen
  CAD: 1.25,     // Canadian Dollar
  AUD: 1.35,     // Australian Dollar
  CHF: 0.92,     // Swiss Franc
  CNY: 6.45,     // Chinese Yuan
  INR: 74.5,     // Indian Rupee
  BRL: 5.3,      // Brazilian Real
};

// List of supported currencies
const SUPPORTED_CURRENCIES = Object.keys(EXCHANGE_RATES);

// Get exchange rate between two currencies
const getExchangeRate = (fromCurrency, toCurrency) => {
  if (fromCurrency === toCurrency) return 1;
  
  if (!EXCHANGE_RATES[fromCurrency] || !EXCHANGE_RATES[toCurrency]) {
    throw new Error(`Unsupported currency: ${fromCurrency} or ${toCurrency}`);
  }
  
  // Convert via USD (base currency)
  return (1 / EXCHANGE_RATES[fromCurrency]) * EXCHANGE_RATES[toCurrency];
};

// Convert amount from one currency to another
const convertCurrency = (amount, fromCurrency, toCurrency) => {
  if (fromCurrency === toCurrency) return amount;
  
  const rate = getExchangeRate(fromCurrency, toCurrency);
  return parseFloat((amount * rate).toFixed(2));
};

// Format currency for display
const formatCurrency = (amount, currency = 'USD') => {
  return new Intl.NumberFormat('en-US', {
    style: 'currency',
    currency: currency,
    minimumFractionDigits: 2,
    maximumFractionDigits: 2
  }).format(amount);
};

// Get currency symbol
const getCurrencySymbol = (currency) => {
  const symbols = {
    USD: '$',
    EUR: '€',
    GBP: '£',
    JPY: '¥',
    CAD: 'C$',
    AUD: 'A$',
    CHF: 'Fr',
    CNY: '¥',
    INR: '₹',
    BRL: 'R$'
  };
  
  return symbols[currency] || currency;
};

module.exports = {
  EXCHANGE_RATES,
  SUPPORTED_CURRENCIES,
  getExchangeRate,
  convertCurrency,
  formatCurrency,
  getCurrencySymbol
};