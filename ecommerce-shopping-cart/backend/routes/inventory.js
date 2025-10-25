const express = require('express');
const { updateInventory, adjustInventory, getLowStockProducts } = require('../controllers/inventory');
const { protect, authorize } = require('../middleware/auth');

const router = express.Router();

router.route('/:id/inventory')
  .put(protect, authorize('admin'), updateInventory)
  .patch(protect, authorize('admin'), adjustInventory);

router.route('/low-stock')
  .get(protect, authorize('admin'), getLowStockProducts);

module.exports = router;