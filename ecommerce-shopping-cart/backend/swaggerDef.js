const swaggerJsdoc = require('swagger-jsdoc');

const options = {
  definition: {
    openapi: '3.0.0',
    info: {
      title: 'E-Commerce Shopping Cart API',
      version: '1.0.0',
      description: 'A complete e-commerce shopping cart API built with Node.js, Express and PostgreSQL',
      contact: {
        name: 'API Support',
        email: 'support@ecommerceapi.com',
      },
    },
    servers: [
      {
        url: 'http://localhost:5000/api',
        description: 'Development server',
      },
      {
        url: 'https://yourdomain.com/api',
        description: 'Production server',
      },
    ],
  },
  apis: ['./routes/*.js', './controllers/*.js'], // files containing OpenAPI definitions
};

const specs = swaggerJsdoc(options);

module.exports = specs;