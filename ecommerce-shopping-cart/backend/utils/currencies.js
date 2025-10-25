// currencies.js - Currency utility functions and data

// List of supported currencies with their symbols and conversion rates to USD
const currencies = {
  USD: { symbol: '$', name: 'US Dollar', rate: 1.0 },
  EUR: { symbol: '€', name: 'Euro', rate: 0.85 },
  GBP: { symbol: '£', name: 'British Pound', rate: 0.73 },
  JPY: { symbol: '¥', name: 'Japanese Yen', rate: 110.0 },
  CAD: { symbol: 'C$', name: 'Canadian Dollar', rate: 1.25 },
  AUD: { symbol: 'A$', name: 'Australian Dollar', rate: 1.35 },
  CHF: { symbol: 'Fr', name: 'Swiss Franc', rate: 0.92 },
  CNY: { symbol: '¥', name: 'Chinese Yuan', rate: 6.45 },
  SEK: { symbol: 'kr', name: 'Swedish Krona', rate: 8.55 },
  NZD: { symbol: 'NZ$', name: 'New Zealand Dollar', rate: 1.42 }
};

// Function to format price based on currency
const formatPrice = (amount, currency = 'USD') => {
  const currencyInfo = currencies[currency] || currencies.USD;
  
  // Format the number with 2 decimal places
  const formattedAmount = Number(amount).toFixed(2);
  
  // Return formatted price with symbol
  return `${currencyInfo.symbol}${formattedAmount}`;
};

// Function to convert price from one currency to another
const convertPrice = (amount, fromCurrency = 'USD', toCurrency = 'USD') => {
  if (fromCurrency === toCurrency) {
    return amount;
  }
  
  // Convert to USD first, then to target currency
  const amountInUSD = amount / currencies[fromCurrency].rate;
  const convertedAmount = amountInUSD * currencies[toCurrency].rate;
  
  return convertedAmount;
};

// Function to get all supported currencies
const getSupportedCurrencies = () => {
  return Object.keys(currencies);
};

// Function to get currency symbol
const getCurrencySymbol = (currency = 'USD') => {
  const currencyInfo = currencies[currency] || currencies.USD;
  return currencyInfo.symbol;
};

module.exports = {
  currencies,
  formatPrice,
  convertPrice,
  getSupportedCurrencies,
  getCurrencySymbol
};