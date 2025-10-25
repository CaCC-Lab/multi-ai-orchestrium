const { ValidationError } = require('joi');
const { BaseError } = require('sequelize');
const { logger } = require('../config/logger');

const buildErrorResponse = (code, message, details = undefined) => {
  const error = { code, message };
  if (details) {
    error.details = details;
  }
  return {
    success: false,
    error,
  };
};

const notFoundHandler = (req, res, next) => {
  res.status(404).json(buildErrorResponse('NOT_FOUND', 'Resource not found'));
};

// eslint-disable-next-line no-unused-vars
const errorHandler = (err, req, res, next) => {
  logger.error('Unhandled error', { error: err, path: req.originalUrl });

  if (err instanceof ValidationError) {
    return res.status(400).json(
      buildErrorResponse(
        'VALIDATION_ERROR',
        'One or more fields have validation errors',
        err.details.map((detail) => ({ field: detail.context?.key, message: detail.message }))
      )
    );
  }

  if (err.name === 'UnauthorizedError') {
    return res.status(401).json(buildErrorResponse('UNAUTHORIZED', 'Authentication required'));
  }

  if (err.code === 'EBADCSRFTOKEN') {
    return res.status(403).json(buildErrorResponse('CSRF_ERROR', 'Invalid CSRF token'));
  }

  if (err.status) {
    return res.status(err.status).json(
      buildErrorResponse(err.code || 'ERROR', err.message || 'An unexpected error occurred', err.details)
    );
  }

  if (err instanceof BaseError) {
    return res.status(400).json(buildErrorResponse('DATABASE_ERROR', err.message));
  }

  return res.status(500).json(buildErrorResponse('INTERNAL_SERVER_ERROR', 'Something went wrong'));
};

module.exports = {
  notFoundHandler,
  errorHandler,
};
