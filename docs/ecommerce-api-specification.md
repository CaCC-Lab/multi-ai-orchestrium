# E-Commerce Shopping Cart System - API Specification

## API Overview

- **Base URL**: `https://api.example.com/v1`
- **Protocol**: HTTPS only
- **Authentication**: JWT Bearer token
- **Response Format**: JSON
- **API Version**: v1

---

## Authentication Endpoints

### POST /auth/register
Register a new user account.

**Request Body:**
```json
{
  "email": "user@example.com",
  "password": "SecurePass123!",
  "firstName": "John",
  "lastName": "Doe",
  "phone": "+1234567890"
}
```

**Response:** `201 Created`
```json
{
  "success": true,
  "message": "User registered successfully. Please verify your email.",
  "data": {
    "user": {
      "id": 1,
      "email": "user@example.com",
      "firstName": "John",
      "lastName": "Doe",
      "isVerified": false
    }
  }
}
```

---

### POST /auth/login
Authenticate user and receive JWT tokens.

**Request Body:**
```json
{
  "email": "user@example.com",
  "password": "SecurePass123!"
}
```

**Response:** `200 OK`
```json
{
  "success": true,
  "data": {
    "user": {
      "id": 1,
      "email": "user@example.com",
      "firstName": "John",
      "lastName": "Doe",
      "role": "customer"
    },
    "tokens": {
      "accessToken": "eyJhbGciOiJIUzI1NiIs...",
      "refreshToken": "eyJhbGciOiJIUzI1NiIs...",
      "expiresIn": 900
    }
  }
}
```

---

### POST /auth/refresh
Refresh access token using refresh token.

**Request Body:**
```json
{
  "refreshToken": "eyJhbGciOiJIUzI1NiIs..."
}
```

**Response:** `200 OK`
```json
{
  "success": true,
  "data": {
    "accessToken": "eyJhbGciOiJIUzI1NiIs...",
    "expiresIn": 900
  }
}
```

---

### POST /auth/logout
Invalidate refresh token.

**Headers:** `Authorization: Bearer {accessToken}`

**Response:** `200 OK`
```json
{
  "success": true,
  "message": "Logged out successfully"
}
```

---

### POST /auth/forgot-password
Request password reset email.

**Request Body:**
```json
{
  "email": "user@example.com"
}
```

**Response:** `200 OK`
```json
{
  "success": true,
  "message": "Password reset email sent"
}
```

---

### POST /auth/reset-password
Reset password using token from email.

**Request Body:**
```json
{
  "token": "reset-token-from-email",
  "newPassword": "NewSecurePass123!"
}
```

**Response:** `200 OK`
```json
{
  "success": true,
  "message": "Password reset successful"
}
```

---

## Product Endpoints

### GET /products
Get paginated product list with optional filters.

**Query Parameters:**
- `page` (default: 1)
- `limit` (default: 20, max: 100)
- `category` (optional)
- `minPrice` (optional)
- `maxPrice` (optional)
- `search` (optional)
- `sort` (optional: `price_asc`, `price_desc`, `name`, `rating`, `newest`)
- `isActive` (default: true)

**Example:** `GET /products?page=1&limit=20&category=electronics&sort=price_asc`

**Response:** `200 OK`
```json
{
  "success": true,
  "data": {
    "products": [
      {
        "id": 1,
        "sku": "PROD-001",
        "name": "Wireless Headphones",
        "slug": "wireless-headphones",
        "shortDescription": "High-quality wireless headphones",
        "price": 99.99,
        "compareAtPrice": 129.99,
        "currency": "USD",
        "stockQuantity": 50,
        "rating": 4.5,
        "reviewCount": 128,
        "images": [
          "https://cdn.example.com/products/prod-001-1.jpg"
        ],
        "category": {
          "id": 5,
          "name": "Electronics",
          "slug": "electronics"
        },
        "isActive": true,
        "isFeatured": true
      }
    ],
    "pagination": {
      "page": 1,
      "limit": 20,
      "totalItems": 150,
      "totalPages": 8,
      "hasNext": true,
      "hasPrev": false
    }
  }
}
```

---

### GET /products/:id
Get single product details.

**Response:** `200 OK`
```json
{
  "success": true,
  "data": {
    "product": {
      "id": 1,
      "sku": "PROD-001",
      "name": "Wireless Headphones",
      "slug": "wireless-headphones",
      "description": "Premium wireless headphones with noise cancellation...",
      "shortDescription": "High-quality wireless headphones",
      "price": 99.99,
      "compareAtPrice": 129.99,
      "cost": 45.00,
      "currency": "USD",
      "stockQuantity": 50,
      "lowStockThreshold": 10,
      "weight": 0.5,
      "dimensions": "20x15x10cm",
      "rating": 4.5,
      "reviewCount": 128,
      "images": [
        "https://cdn.example.com/products/prod-001-1.jpg",
        "https://cdn.example.com/products/prod-001-2.jpg"
      ],
      "metadata": {
        "color": "Black",
        "brand": "TechBrand"
      },
      "category": {
        "id": 5,
        "name": "Electronics",
        "slug": "electronics"
      },
      "isActive": true,
      "isFeatured": true,
      "createdAt": "2024-01-15T10:30:00Z",
      "updatedAt": "2024-02-20T14:45:00Z"
    }
  }
}
```

---

### POST /products (Admin Only)
Create a new product.

**Headers:** 
- `Authorization: Bearer {accessToken}`
- `Content-Type: application/json`

**Request Body:**
```json
{
  "sku": "PROD-002",
  "name": "Smart Watch",
  "slug": "smart-watch",
  "description": "Feature-rich smartwatch...",
  "shortDescription": "Smartwatch with health tracking",
  "categoryId": 5,
  "price": 199.99,
  "compareAtPrice": 249.99,
  "cost": 89.00,
  "stockQuantity": 100,
  "weight": 0.1,
  "images": [
    "https://cdn.example.com/products/prod-002-1.jpg"
  ],
  "metadata": {
    "color": "Silver",
    "brand": "SmartTech"
  }
}
```

**Response:** `201 Created`
```json
{
  "success": true,
  "message": "Product created successfully",
  "data": {
    "product": {
      "id": 2,
      "sku": "PROD-002",
      "name": "Smart Watch",
      // ... full product object
    }
  }
}
```

---

### PUT /products/:id (Admin Only)
Update existing product.

**Headers:** `Authorization: Bearer {accessToken}`

**Request Body:** (partial update supported)
```json
{
  "price": 189.99,
  "stockQuantity": 150
}
```

**Response:** `200 OK`
```json
{
  "success": true,
  "message": "Product updated successfully",
  "data": {
    "product": {
      // ... updated product object
    }
  }
}
```

---

### DELETE /products/:id (Admin Only)
Soft delete a product (set isActive to false).

**Headers:** `Authorization: Bearer {accessToken}`

**Response:** `200 OK`
```json
{
  "success": true,
  "message": "Product deleted successfully"
}
```

---

## Cart Endpoints

### GET /cart
Get current user's cart.

**Headers:** `Authorization: Bearer {accessToken}`

**Response:** `200 OK`
```json
{
  "success": true,
  "data": {
    "cart": {
      "id": 1,
      "userId": 1,
      "currency": "USD",
      "items": [
        {
          "id": 1,
          "productId": 1,
          "product": {
            "id": 1,
            "name": "Wireless Headphones",
            "price": 99.99,
            "images": ["https://cdn.example.com/products/prod-001-1.jpg"]
          },
          "quantity": 2,
          "price": 99.99,
          "subtotal": 199.98
        }
      ],
      "subtotal": 199.98,
      "tax": 19.99,
      "total": 219.97,
      "itemCount": 2
    }
  }
}
```

---

### POST /cart/items
Add item to cart.

**Headers:** `Authorization: Bearer {accessToken}`

**Request Body:**
```json
{
  "productId": 1,
  "quantity": 2
}
```

**Response:** `200 OK`
```json
{
  "success": true,
  "message": "Item added to cart",
  "data": {
    "cartItem": {
      "id": 1,
      "productId": 1,
      "quantity": 2,
      "price": 99.99,
      "subtotal": 199.98
    },
    "cart": {
      // ... updated cart object
    }
  }
}
```

---

### PUT /cart/items/:id
Update cart item quantity.

**Headers:** `Authorization: Bearer {accessToken}`

**Request Body:**
```json
{
  "quantity": 3
}
```

**Response:** `200 OK`
```json
{
  "success": true,
  "message": "Cart item updated",
  "data": {
    "cartItem": {
      "id": 1,
      "quantity": 3,
      "subtotal": 299.97
    },
    "cart": {
      // ... updated cart object
    }
  }
}
```

---

### DELETE /cart/items/:id
Remove item from cart.

**Headers:** `Authorization: Bearer {accessToken}`

**Response:** `200 OK`
```json
{
  "success": true,
  "message": "Item removed from cart",
  "data": {
    "cart": {
      // ... updated cart object
    }
  }
}
```

---

### DELETE /cart
Clear entire cart.

**Headers:** `Authorization: Bearer {accessToken}`

**Response:** `200 OK`
```json
{
  "success": true,
  "message": "Cart cleared"
}
```

---

## Order Endpoints

### POST /orders
Create new order from cart.

**Headers:** `Authorization: Bearer {accessToken}`

**Request Body:**
```json
{
  "shippingAddressId": 1,
  "billingAddressId": 1,
  "paymentMethodId": "pm_1234567890",
  "notes": "Please deliver before 5 PM"
}
```

**Response:** `201 Created`
```json
{
  "success": true,
  "message": "Order created successfully",
  "data": {
    "order": {
      "id": 1,
      "orderNumber": "ORD-20240315-0001",
      "userId": 1,
      "status": "pending",
      "paymentStatus": "pending",
      "currency": "USD",
      "subtotal": 199.98,
      "tax": 19.99,
      "shippingCost": 10.00,
      "total": 229.97,
      "items": [
        {
          "id": 1,
          "productId": 1,
          "productName": "Wireless Headphones",
          "productSku": "PROD-001",
          "quantity": 2,
          "price": 99.99,
          "subtotal": 199.98
        }
      ],
      "shippingAddress": {
        // ... address object
      },
      "createdAt": "2024-03-15T10:30:00Z"
    }
  }
}
```

---

### GET /orders
Get user's order history.

**Headers:** `Authorization: Bearer {accessToken}`

**Query Parameters:**
- `page` (default: 1)
- `limit` (default: 20)
- `status` (optional)

**Response:** `200 OK`
```json
{
  "success": true,
  "data": {
    "orders": [
      {
        "id": 1,
        "orderNumber": "ORD-20240315-0001",
        "status": "delivered",
        "paymentStatus": "paid",
        "total": 229.97,
        "itemCount": 2,
        "createdAt": "2024-03-15T10:30:00Z",
        "deliveredAt": "2024-03-18T14:20:00Z"
      }
    ],
    "pagination": {
      "page": 1,
      "limit": 20,
      "totalItems": 15,
      "totalPages": 1
    }
  }
}
```

---

### GET /orders/:id
Get order details.

**Headers:** `Authorization: Bearer {accessToken}`

**Response:** `200 OK`
```json
{
  "success": true,
  "data": {
    "order": {
      "id": 1,
      "orderNumber": "ORD-20240315-0001",
      "status": "delivered",
      "paymentStatus": "paid",
      "paymentMethod": "card",
      "currency": "USD",
      "subtotal": 199.98,
      "tax": 19.99,
      "shippingCost": 10.00,
      "total": 229.97,
      "items": [
        // ... order items
      ],
      "shippingAddress": {
        // ... address object
      },
      "billingAddress": {
        // ... address object
      },
      "trackingNumber": "1Z999AA10123456784",
      "createdAt": "2024-03-15T10:30:00Z",
      "shippedAt": "2024-03-16T09:15:00Z",
      "deliveredAt": "2024-03-18T14:20:00Z"
    }
  }
}
```

---

### PUT /orders/:id/cancel
Cancel an order.

**Headers:** `Authorization: Bearer {accessToken}`

**Response:** `200 OK`
```json
{
  "success": true,
  "message": "Order cancelled successfully",
  "data": {
    "order": {
      "id": 1,
      "status": "cancelled",
      "cancelledAt": "2024-03-15T11:00:00Z"
    }
  }
}
```

---

## Admin Order Management Endpoints

### GET /admin/orders
Get all orders (admin only).

**Headers:** `Authorization: Bearer {accessToken}`

**Query Parameters:**
- `page`, `limit`, `status`, `paymentStatus`, `startDate`, `endDate`

**Response:** `200 OK`
```json
{
  "success": true,
  "data": {
    "orders": [
      // ... array of orders
    ],
    "pagination": {
      // ... pagination info
    }
  }
}
```

---

### PUT /admin/orders/:id/status
Update order status (admin only).

**Headers:** `Authorization: Bearer {accessToken}`

**Request Body:**
```json
{
  "status": "shipped",
  "trackingNumber": "1Z999AA10123456784"
}
```

**Response:** `200 OK`
```json
{
  "success": true,
  "message": "Order status updated",
  "data": {
    "order": {
      // ... updated order
    }
  }
}
```

---

## Address Endpoints

### GET /addresses
Get user's saved addresses.

**Headers:** `Authorization: Bearer {accessToken}`

**Response:** `200 OK`
```json
{
  "success": true,
  "data": {
    "addresses": [
      {
        "id": 1,
        "type": "both",
        "firstName": "John",
        "lastName": "Doe",
        "addressLine1": "123 Main St",
        "city": "New York",
        "state": "NY",
        "postalCode": "10001",
        "country": "US",
        "phone": "+1234567890",
        "isDefault": true
      }
    ]
  }
}
```

---

### POST /addresses
Add new address.

**Headers:** `Authorization: Bearer {accessToken}`

**Request Body:**
```json
{
  "type": "shipping",
  "firstName": "John",
  "lastName": "Doe",
  "addressLine1": "123 Main St",
  "city": "New York",
  "state": "NY",
  "postalCode": "10001",
  "country": "US",
  "phone": "+1234567890",
  "isDefault": false
}
```

**Response:** `201 Created`
```json
{
  "success": true,
  "message": "Address added successfully",
  "data": {
    "address": {
      // ... address object
    }
  }
}
```

---

## Payment Endpoints

### POST /payments/create-intent
Create Stripe payment intent.

**Headers:** `Authorization: Bearer {accessToken}`

**Request Body:**
```json
{
  "amount": 22997,
  "currency": "usd"
}
```

**Response:** `200 OK`
```json
{
  "success": true,
  "data": {
    "clientSecret": "pi_1234567890_secret_abcdefg",
    "paymentIntentId": "pi_1234567890"
  }
}
```

---

### POST /payments/webhook
Stripe webhook handler (internal).

**Headers:** `Stripe-Signature: {signature}`

**Response:** `200 OK`

---

## Error Response Format

All errors follow this format:

```json
{
  "success": false,
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "Invalid input data",
    "details": [
      {
        "field": "email",
        "message": "Email is required"
      }
    ]
  }
}
```

### Common Error Codes

- `400` - Bad Request
- `401` - Unauthorized
- `403` - Forbidden
- `404` - Not Found
- `409` - Conflict
- `422` - Unprocessable Entity
- `429` - Too Many Requests
- `500` - Internal Server Error

---

## Rate Limiting

- **General**: 100 requests per 15 minutes per IP
- **Auth endpoints**: 5 requests per 15 minutes per IP
- **Admin endpoints**: 1000 requests per 15 minutes per user

**Rate Limit Headers:**
```
X-RateLimit-Limit: 100
X-RateLimit-Remaining: 95
X-RateLimit-Reset: 1615824000
```

---

## API Versioning

- Current version: `v1`
- Version specified in URL: `/v1/products`
- Backward compatibility maintained for 12 months after deprecation notice
