// controllers/inventoryController.js
const { checkLowStock, getInventoryReport: serviceGetInventoryReport } = require('../services/inventoryService');

// Get inventory report
const getInventoryReport = async (req, res) => {
  try {
    const report = await serviceGetInventoryReport();
    
    res.json({
      message: 'Inventory report retrieved successfully',
      report
    });
  } catch (error) {
    console.error('Get inventory report error:', error);
    res.status(500).json({ message: 'Server error' });
  }
};

// Get low stock products
const getLowStockProducts = async (req, res) => {
  try {
    const threshold = parseInt(req.query.threshold) || 10;
    const products = await checkLowStock(threshold);
    
    res.json({
      message: 'Low stock products retrieved successfully',
      products,
      threshold
    });
  } catch (error) {
    console.error('Get low stock products error:', error);
    res.status(500).json({ message: 'Server error' });
  }
};

module.exports = {
  getInventoryReport,
  getLowStockProducts
};