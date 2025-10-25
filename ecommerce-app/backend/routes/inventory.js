const express = require('express');
const { getInventoryReport, updateProductStock, bulkUpdateStock, getLowStockAlerts, getOutOfStockProducts } = require('../controllers/inventoryController');
const { adminAuth } = require('../middleware/auth');

const router = express.Router();

// @route   GET api/inventory/report
// @desc    Get inventory report
// @access  Private/Admin
router.get('/report', adminAuth, getInventoryReport);

// @route   PUT api/inventory/:productId/stock
// @desc    Update product stock
// @access  Private/Admin
router.put('/:productId/stock', adminAuth, updateProductStock);

// @route   POST api/inventory/bulk-update
// @desc    Bulk update stock
// @access  Private/Admin
router.post('/bulk-update', adminAuth, bulkUpdateStock);

// @route   GET api/inventory/low-stock
// @desc    Get low stock alerts
// @access  Private/Admin
router.get('/low-stock', adminAuth, getLowStockAlerts);

// @route   GET api/inventory/out-of-stock
// @desc    Get out of stock products
// @access  Private/Admin
router.get('/out-of-stock', adminAuth, getOutOfStockProducts);

module.exports = router;