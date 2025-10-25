const { 
  getExchangeRate, 
  convertCurrency, 
  formatCurrency, 
  getCurrencySymbol,
  EXCHANGE_RATES 
} = require('../../utils/currency');

describe('Currency Utility Functions', () => {
  describe('getExchangeRate', () => {
    test('should return 1 when converting currency to itself', () => {
      expect(getExchangeRate('USD', 'USD')).toBe(1);
      expect(getExchangeRate('EUR', 'EUR')).toBe(1);
    });

    test('should correctly convert between USD and EUR', () => {
      const rate = getExchangeRate('USD', 'EUR');
      expect(rate).toBe(0.85); // Based on our exchange rates
    });

    test('should correctly convert between EUR and USD', () => {
      const rate = getExchangeRate('EUR', 'USD');
      expect(rate).toBe(1 / 0.85); // Inverse of EUR to USD rate
    });

    test('should throw error for unsupported currencies', () => {
      expect(() => getExchangeRate('USD', 'XYZ')).toThrow('Unsupported currency');
      expect(() => getExchangeRate('XYZ', 'USD')).toThrow('Unsupported currency');
    });
  });

  describe('convertCurrency', () => {
    test('should return same amount when converting same currency', () => {
      expect(convertCurrency(100, 'USD', 'USD')).toBe(100);
    });

    test('should correctly convert USD to EUR', () => {
      expect(convertCurrency(100, 'USD', 'EUR')).toBeCloseTo(85, 2);
    });

    test('should correctly convert EUR to USD', () => {
      expect(convertCurrency(85, 'EUR', 'USD')).toBeCloseTo(100, 2);
    });

    test('should correctly convert USD to GBP', () => {
      expect(convertCurrency(100, 'USD', 'GBP')).toBeCloseTo(73, 2);
    });
  });

  describe('formatCurrency', () => {
    test('should format currency with proper symbols', () => {
      expect(formatCurrency(100, 'USD')).toBe('$100.00');
      expect(formatCurrency(100, 'EUR')).toBe('€100.00');
      expect(formatCurrency(100, 'GBP')).toBe('£100.00');
    });

    test('should format currency with decimals', () => {
      expect(formatCurrency(100.5, 'USD')).toBe('$100.50');
      expect(formatCurrency(100.555, 'USD')).toBe('$100.56');
    });
  });

  describe('getCurrencySymbol', () => {
    test('should return correct symbols for supported currencies', () => {
      expect(getCurrencySymbol('USD')).toBe('$');
      expect(getCurrencySymbol('EUR')).toBe('€');
      expect(getCurrencySymbol('GBP')).toBe('£');
      expect(getCurrencySymbol('JPY')).toBe('¥');
    });

    test('should return currency code for unsupported currencies', () => {
      expect(getCurrencySymbol('XYZ')).toBe('XYZ');
    });
  });

  describe('EXCHANGE_RATES constant', () => {
    test('should contain USD as base currency with rate 1', () => {
      expect(EXCHANGE_RATES.USD).toBe(1);
    });

    test('should contain other currencies with expected rates', () => {
      expect(EXCHANGE_RATES.EUR).toBe(0.85);
      expect(EXCHANGE_RATES.GBP).toBe(0.73);
      expect(EXCHANGE_RATES.JPY).toBe(110);
    });
  });
});