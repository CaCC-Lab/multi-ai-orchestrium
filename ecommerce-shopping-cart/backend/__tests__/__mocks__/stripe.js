module.exports = jest.fn().mockImplementation(() => ({
  paymentIntents: {
    create: jest.fn().mockResolvedValue({
      id: 'pi_mock123',
      client_secret: 'pi_mock123_secret123',
      status: 'succeeded'
    }),
    retrieve: jest.fn()
  },
  webhooks: {
    constructEvent: jest.fn()
  }
}));