# E-Commerce Shopping Cart System - Admin Guide

## Table of Contents
1. [Introduction](#introduction)
2. [Accessing Admin Panel](#accessing-admin-panel)
3. [Managing Products](#managing-products)
4. [Managing Users](#managing-users)
5. [Managing Orders](#managing-orders)
6. [Inventory Management](#inventory-management)
7. [Analytics & Reports](#analytics--reports)
8. [System Configuration](#system-configuration)
9. [Troubleshooting](#troubleshooting)

## Introduction

This guide provides administrators with instructions on managing the E-Commerce Shopping Cart System. As an admin, you have special privileges to manage products, users, orders, and system settings.

### Prerequisites
- Valid admin account credentials
- Access to the admin panel
- Understanding of e-commerce business processes

## Accessing Admin Panel

### Logging In
1. Navigate to the website
2. Click "Login" in the header
3. Enter your admin credentials
4. Click "Sign In"
5. After login, you'll see "Admin Dashboard" in your user menu

### Admin Dashboard
The admin dashboard provides:
- Summary statistics (orders, revenue, products)
- Quick access to management functions
- Recent activity overview

## Managing Products

### Adding New Products
1. Navigate to the Admin Dashboard
2. Click on "Manage Products" 
3. Select "Add New Product"
4. Fill in product details:
   - Product Name (required)
   - Description
   - Price (required, positive number)
   - Category (required)
   - Brand
   - SKU (Stock Keeping Unit)
   - Initial inventory count
   - Images (upload multiple if needed)
   - Product specifications (as JSON)
   - Discount percentage (optional)
5. Click "Create Product"

### Editing Existing Products
1. Go to "Manage Products"
2. Find the product in the list
3. Click "Edit" or on the product name
4. Update product information
5. Click "Update Product"

### Updating Product Images
1. In the product edit form
2. Upload new images
3. The old images will be replaced

### Deactivating Products
- To hide a product from customers without deleting it:
- Edit the product
- Uncheck the "Active" status
- Click "Update Product"

### Product Categories
- Products can be categorized for better organization
- Common categories include Electronics, Clothing, Books, etc.
- Create new categories as needed for your inventory

## Managing Users

### Viewing All Users
1. Access Admin Dashboard
2. Navigate to "Manage Users" section
3. View list of all registered users
4. Filter users by status, registration date, or role

### User Information
Each user record includes:
- Name and email
- Registration date
- Last login
- Account status (active/inactive)
- User role (user/admin)

### Managing User Accounts
- Deactivate user accounts if needed
- Update user information
- Change user roles (with caution)

### User Roles
- **User**: Regular customer with standard privileges
- **Admin**: Full system access (assign with caution)

## Managing Orders

### Viewing All Orders
1. Go to Admin Dashboard
2. Navigate to "Manage Orders" 
3. View all orders in the system
4. Filter by status, date, or customer

### Order Information
Each order contains:
- Order ID and number
- Customer details
- Items ordered
- Total amount
- Order status
- Payment status
- Shipping address
- Order date

### Updating Order Status
1. Find the order in the order list
2. Click on the order to view details
3. Update status as per fulfillment process:
   - Pending → Processing → Shipped → Delivered
   - Or mark as Cancelled if needed
4. Add tracking number when shipped

### Order Fulfillment
1. Process orders in chronological order
2. Update status appropriately
3. Maintain accurate inventory levels
4. Send shipping notifications to customers

## Inventory Management

### Checking Current Inventory
1. Go to the "Inventory Management" section
2. View current stock levels for all products
3. Identify low stock items

### Low Stock Alerts
- System automatically identifies products with low inventory (default: <10 units)
- Access low stock items from the "Low Stock" section
- Replenish inventory as needed

### Updating Inventory
#### Method 1: Direct Update
1. Go to the specific product
2. Update the "Inventory" field
3. Save changes

#### Method 2: Bulk Import
- Available in future updates
- Import inventory changes via CSV

### Adjusting Inventory
For inventory adjustments (due to damage, loss, etc.):
1. Go to the specific product
2. Use the "Adjust Inventory" function
3. Specify quantity and reason for adjustment

### Inventory Reports
- Generate inventory reports
- Track inventory trends over time
- Forecast restocking needs

## Analytics & Reports

### Sales Reports
- Daily, weekly, monthly sales
- Product performance
- Revenue trends
- Top selling products

### Customer Reports
- New customer registration trends
- Customer demographics
- Order frequency

### Inventory Reports
- Current stock levels
- Low stock alerts
- Product turnover rates

### Accessing Reports
1. Navigate to "Reports" in the admin panel
2. Select the report type
3. Set date range and filters
4. Generate and export reports

## System Configuration

### Site Settings
- Store name and contact information
- Currency settings
- Tax rates
- Shipping zones and rates

### Email Configuration
- Update SMTP settings
- Configure notification templates
- Set up automated emails

### Security Settings
- Manage admin accounts
- Configure rate limiting
- Set up 2FA if available

## Troubleshooting

### Common Issues

**Problem**: Can't access admin panel
**Solution**: 
- Verify you have admin role
- Check your login credentials
- Contact main administrator if access denied

**Problem**: Products not appearing after creation
**Solution**:
- Check if product is marked as "Active"
- Verify all required fields were filled
- Clear cache if using a CDN

**Problem**: Orders not updating properly
**Solution**:
- Check for concurrent edits
- Verify database connections
- Review API endpoints

### Data Integrity
- Always backup data before major changes
- Use the system as intended
- Follow proper procedures for each task

### Performance Issues
- Monitor system resources
- Review caching configurations
- Check database performance

## Support

For technical issues or additional help:
- Contact the development team
- Submit tickets through the support system
- Check the system status page

---

**Important**: Changes made in the admin panel affect all users. Exercise caution when modifying data or system settings.