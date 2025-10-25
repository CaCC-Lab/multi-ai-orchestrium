-- Database Schema for E-Commerce Shopping Cart System
-- PostgreSQL

-- Users table
CREATE TABLE IF NOT EXISTS users (
    id SERIAL PRIMARY KEY,
    firstName VARCHAR(50) NOT NULL,
    lastName VARCHAR(50) NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
    password VARCHAR(255) NOT NULL,
    role VARCHAR(20) DEFAULT 'user', -- 'user' or 'admin'
    phone VARCHAR(20),
    address JSONB,
    isActive BOOLEAN DEFAULT true,
    createdAt TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updatedAt TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Create indexes for users
CREATE INDEX IF NOT EXISTS idx_users_email ON users(email);
CREATE INDEX IF NOT EXISTS idx_users_role ON users(role);
CREATE INDEX IF NOT EXISTS idx_users_active ON users(isActive);
CREATE INDEX IF NOT EXISTS idx_users_name ON users(firstName, lastName);

-- Products table
CREATE TABLE IF NOT EXISTS products (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    price DECIMAL(10, 2) NOT NULL CHECK (price >= 0),
    category VARCHAR(100) NOT NULL,
    brand VARCHAR(100),
    sku VARCHAR(100) UNIQUE,
    inventory INTEGER DEFAULT 0,
    images TEXT[],
    specifications JSONB,
    rating DECIMAL(3, 2) DEFAULT 0.00 CHECK (rating >= 0 AND rating <= 5.00),
    numReviews INTEGER DEFAULT 0,
    isActive BOOLEAN DEFAULT true,
    discountPercentage DECIMAL(5, 2) DEFAULT 0.00,
    createdAt TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updatedAt TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Create indexes for products
CREATE INDEX IF NOT EXISTS idx_products_category ON products(category);
CREATE INDEX IF NOT EXISTS idx_products_brand ON products(brand);
CREATE INDEX IF NOT EXISTS idx_products_price ON products(price);
CREATE INDEX IF NOT EXISTS idx_products_active ON products(isActive);
CREATE INDEX IF NOT EXISTS idx_products_name ON products(name);
CREATE INDEX IF NOT EXISTS idx_products_rating ON products(rating);
CREATE INDEX IF NOT EXISTS idx_products_sku ON products(sku);

-- Composite indexes
CREATE INDEX IF NOT EXISTS idx_products_category_active ON products(category, isActive);
CREATE INDEX IF NOT EXISTS idx_products_brand_active ON products(brand, isActive);
CREATE INDEX IF NOT EXISTS idx_products_active_price ON products(isActive, price);
CREATE INDEX IF NOT EXISTS idx_products_active_rating ON products(isActive, rating);

-- Cart table
CREATE TABLE IF NOT EXISTS cart (
    id SERIAL PRIMARY KEY,
    userId INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    productId INTEGER NOT NULL REFERENCES products(id) ON DELETE CASCADE,
    quantity INTEGER NOT NULL DEFAULT 1 CHECK (quantity > 0),
    priceAtTime DECIMAL(10, 2) NOT NULL,
    createdAt TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updatedAt TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(userId, productId) -- Prevent duplicate products in cart
);

-- Create indexes for cart
CREATE INDEX IF NOT EXISTS idx_cart_user ON cart(userId);
CREATE INDEX IF NOT EXISTS idx_cart_product ON cart(productId);

-- Orders table
CREATE TABLE IF NOT EXISTS orders (
    id SERIAL PRIMARY KEY,
    userId INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    orderNumber VARCHAR(50) UNIQUE NOT NULL,
    status VARCHAR(20) DEFAULT 'pending' CHECK (status IN ('pending', 'processing', 'shipped', 'delivered', 'cancelled')),
    items JSONB NOT NULL,
    totalAmount DECIMAL(10, 2) NOT NULL,
    currency VARCHAR(10) DEFAULT 'USD',
    shippingAddress JSONB NOT NULL,
    billingAddress JSONB,
    paymentMethod VARCHAR(50),
    paymentStatus VARCHAR(20) DEFAULT 'pending' CHECK (paymentStatus IN ('pending', 'paid', 'failed', 'refunded')),
    paymentIntentId VARCHAR(255),
    trackingNumber VARCHAR(100),
    notes TEXT,
    createdAt TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updatedAt TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Create indexes for orders
CREATE INDEX IF NOT EXISTS idx_orders_user ON orders(userId);
CREATE INDEX IF NOT EXISTS idx_orders_orderNumber ON orders(orderNumber);
CREATE INDEX IF NOT EXISTS idx_orders_status ON orders(status);
CREATE INDEX IF NOT EXISTS idx_orders_total ON orders(totalAmount);
CREATE INDEX IF NOT EXISTS idx_orders_paymentStatus ON orders(paymentStatus);
CREATE INDEX IF NOT EXISTS idx_orders_paymentIntentId ON orders(paymentIntentId);
CREATE INDEX IF NOT EXISTS idx_orders_trackingNumber ON orders(trackingNumber);

-- Composite indexes
CREATE INDEX IF NOT EXISTS idx_orders_user_created ON orders(userId, createdAt);
CREATE INDEX IF NOT EXISTS idx_orders_status_created ON orders(status, createdAt);
CREATE INDEX IF NOT EXISTS idx_orders_paymentStatus_created ON orders(paymentStatus, createdAt);

-- Create update timestamp trigger function
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updatedAt = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Create triggers for updated_at
CREATE TRIGGER update_users_updated_at BEFORE UPDATE ON users
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_products_updated_at BEFORE UPDATE ON products
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_cart_updated_at BEFORE UPDATE ON cart
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_orders_updated_at BEFORE UPDATE ON orders
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Insert default admin user (you should change the password)
INSERT INTO users (firstName, lastName, email, password, role) 
VALUES ('Admin', 'User', 'admin@example.com', 
        '$2a$10$8K1p/aEJ85K6z2m/JyKp/e.6Y33Q3B6T6Y33Q3B6T6Y33Q3B6T6Y33', 'admin')
ON CONFLICT (email) DO NOTHING;

-- Insert sample products
INSERT INTO products (name, description, price, category, brand, inventory, isActive) 
VALUES 
    ('Wireless Headphones', 'High-quality wireless headphones with noise cancellation', 99.99, 'Electronics', 'Brand A', 50, true),
    ('Smart Watch', 'Feature-rich smartwatch with health tracking', 199.99, 'Electronics', 'Brand B', 30, true),
    ('Cotton T-Shirt', 'Comfortable cotton t-shirt for everyday wear', 19.99, 'Clothing', 'Brand C', 100, true),
    ('Coffee Maker', 'Programmable coffee maker with thermal carafe', 79.99, 'Home & Kitchen', 'Brand D', 25, true)
ON CONFLICT (name) DO NOTHING;