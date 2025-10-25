const express = require('express');
const { getProducts, getProduct, createProduct, updateProduct, deleteProduct, searchProducts } = require('../controllers/products');
const { protect, authorize } = require('../middleware/auth');
const { cacheForProducts, cacheForProduct } = require('../middleware/cache');

const router = express.Router();

router.route('/')
  .get(cacheForProducts, getProducts)
  .post(protect, authorize('admin'), createProduct);

router.route('/search').get(cacheForProducts, searchProducts);

router.route('/:id')
  .get(cacheForProduct, getProduct)
  .put(protect, authorize('admin'), updateProduct)
  .delete(protect, authorize('admin'), deleteProduct);

module.exports = router;