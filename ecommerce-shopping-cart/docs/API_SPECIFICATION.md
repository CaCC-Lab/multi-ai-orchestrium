# API Specification

## Overview

RESTful API specification for the E-Commerce Shopping Cart System.

**Base URL:** `https://api.example.com/v1`  
**Authentication:** JWT Bearer Token  
**Content Type:** `application/json`

## Authentication

### POST /auth/register
Register a new user account.

**Request:**
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
  "data": {
    "user": {
      "id": 1,
      "email": "user@example.com",
      "firstName": "John",
      "lastName": "Doe"
    },
    "tokens": {
      "accessToken": "eyJhbGciOiJIUzI1NiIs...",
      "refreshToken": "eyJhbGciOiJIUzI1NiIs...",
      "expiresIn": 3600
    }
  }
}
```

### POST /auth/login
Authenticate user and obtain tokens.

**Request:**
```json
{
  "email": "user@example.com",
  "password": "SecurePass123!"
}
```

**Response:** `200 OK`

### POST /auth/refresh
Refresh access token using refresh token.

**Request:**
```json
{
  "refreshToken": "eyJhbGciOiJIUzI1NiIs..."
}
```

### POST /auth/logout
Invalidate refresh token.

**Headers:** `Authorization: Bearer {token}`

### POST /auth/forgot-password
Request password reset email.

### POST /auth/reset-password
Reset password with token.

## Products

### GET /products
List products with pagination, filtering, and search.

**Query Parameters:**
- `page` (integer, default: 1)
- `limit` (integer, default: 20, max: 100)
- `category` (string)
- `minPrice` (decimal)
- `maxPrice` (decimal)
- `search` (string)
- `sort` (enum: `price_asc`, `price_desc`, `name_asc`, `name_desc`, `newest`, `popular`)
- `featured` (boolean)

**Response:** `200 OK`
```json
{
  "success": true,
  "data": {
    "products": [
      {
        "id": 1,
        "sku": "PROD-001",
        "name": "Premium Wireless Headphones",
        "slug": "premium-wireless-headphones",
        "shortDescription": "High-quality sound...",
        "price": 199.99,
        "compareAtPrice": 249.99,
        "category": {
          "id": 5,
          "name": "Electronics",
          "slug": "electronics"
        },
        "primaryImage": "https://cdn.example.com/products/...",
        "rating": 4.5,
        "reviewCount": 128,
        "inStock": true,
        "isFeatured": true
      }
    ],
    "pagination": {
      "page": 1,
      "limit": 20,
      "total": 150,
      "pages": 8
    }
  }
}
```

### GET /products/:id
Get product details.

**Response:** `200 OK`
```json
{
  "success": true,
  "data": {
    "id": 1,
    "sku": "PROD-001",
    "name": "Premium Wireless Headphones",
    "slug": "premium-wireless-headphones",
    "description": "Full product description...",
    "shortDescription": "High-quality sound...",
    "price": 199.99,
    "compareAtPrice": 249.99,
    "category": {...},
    "images": [
      {
        "id": 1,
        "url": "https://cdn.example.com/...",
        "altText": "Front view",
        "isPrimary": true
      }
    ],
    "inventory": {
      "quantity": 50,
      "availableQuantity": 45,
      "lowStockThreshold": 10,
      "allowBackorder": false
    },
    "specifications": {...},
    "rating": 4.5,
    "reviewCount": 128,
    "relatedProducts": [...]
  }
}
```

### GET /products/:id/reviews
Get product reviews.

**Query Parameters:**
- `page`, `limit`, `sort` (newest, highest, lowest, helpful)

### POST /products/:id/reviews
Create product review (requires authentication and verified purchase).

**Request:**
```json
{
  "rating": 5,
  "title": "Excellent product!",
  "comment": "Very satisfied with the purchase..."
}
```

## Categories

### GET /categories
List all categories (hierarchical structure).

**Response:** `200 OK`
```json
{
  "success": true,
  "data": {
    "categories": [
      {
        "id": 1,
        "name": "Electronics",
        "slug": "electronics",
        "imageUrl": "...",
        "productCount": 234,
        "children": [
          {
            "id": 5,
            "name": "Audio",
            "slug": "electronics/audio",
            "productCount": 45
          }
        ]
      }
    ]
  }
}
```

### GET /categories/:slug/products
List products in a category (same as GET /products with category filter).

## Cart

### GET /cart
Get current user's cart (requires authentication).

**Response:** `200 OK`
```json
{
  "success": true,
  "data": {
    "items": [
      {
        "id": 1,
        "product": {
          "id": 1,
          "name": "Premium Wireless Headphones",
          "slug": "premium-wireless-headphones",
          "price": 199.99,
          "primaryImage": "...",
          "inStock": true
        },
        "quantity": 2,
        "subtotal": 399.98
      }
    ],
    "summary": {
      "itemCount": 3,
      "subtotal": 549.97,
      "estimatedTax": 49.50,
      "estimatedTotal": 599.47
    }
  }
}
```

### POST /cart/items
Add item to cart.

**Request:**
```json
{
  "productId": 1,
  "quantity": 2
}
```

**Response:** `201 Created` (returns updated cart)

### PATCH /cart/items/:id
Update cart item quantity.

**Request:**
```json
{
  "quantity": 3
}
```

### DELETE /cart/items/:id
Remove item from cart.

**Response:** `204 No Content`

### DELETE /cart
Clear entire cart.

## Orders

### POST /orders
Create order from cart (checkout).

**Request:**
```json
{
  "shippingAddressId": 1,
  "billingAddressId": 1,
  "shippingMethod": "standard",
  "paymentMethod": "stripe",
  "paymentIntentId": "pi_...",
  "customerNote": "Please leave at door",
  "currency": "USD"
}
```

**Response:** `201 Created`
```json
{
  "success": true,
  "data": {
    "order": {
      "id": 1001,
      "orderNumber": "ORD-20261024-001001",
      "status": "pending",
      "total": 599.47,
      "currency": "USD",
      "createdAt": "2026-01-15T10:30:00Z"
    }
  }
}
```

### GET /orders
List user's orders (requires authentication).

**Query Parameters:**
- `page`, `limit`, `status`

**Response:** `200 OK`
```json
{
  "success": true,
  "data": {
    "orders": [
      {
        "id": 1001,
        "orderNumber": "ORD-20261024-001001",
        "status": "shipped",
        "itemCount": 3,
        "total": 599.47,
        "currency": "USD",
        "trackingNumber": "1Z999AA1012345678",
        "createdAt": "2026-01-15T10:30:00Z",
        "shippedAt": "2026-01-16T14:20:00Z"
      }
    ],
    "pagination": {...}
  }
}
```

### GET /orders/:id
Get order details.

**Response:** `200 OK`
```json
{
  "success": true,
  "data": {
    "id": 1001,
    "orderNumber": "ORD-20261024-001001",
    "status": "shipped",
    "items": [
      {
        "id": 1,
        "productName": "Premium Wireless Headphones",
        "productSku": "PROD-001",
        "quantity": 2,
        "unitPrice": 199.99,
        "subtotal": 399.98,
        "imageUrl": "..."
      }
    ],
    "pricing": {
      "subtotal": 549.97,
      "tax": 49.50,
      "shipping": 0.00,
      "discount": 0.00,
      "total": 599.47,
      "currency": "USD"
    },
    "shippingAddress": {...},
    "billingAddress": {...},
    "payment": {
      "method": "stripe",
      "status": "succeeded",
      "transactionId": "ch_..."
    },
    "tracking": {
      "number": "1Z999AA1012345678",
      "carrier": "UPS",
      "shippedAt": "2026-01-16T14:20:00Z",
      "estimatedDelivery": "2026-01-20T17:00:00Z"
    },
    "timeline": [
      {"status": "pending", "timestamp": "2026-01-15T10:30:00Z"},
      {"status": "processing", "timestamp": "2026-01-15T11:00:00Z"},
      {"status": "shipped", "timestamp": "2026-01-16T14:20:00Z"}
    ]
  }
}
```

### POST /orders/:id/cancel
Cancel order (only if status is pending or processing).

## Payments

### POST /payments/create-intent
Create Stripe payment intent for checkout.

**Request:**
```json
{
  "amount": 59947,
  "currency": "USD"
}
```

**Response:** `200 OK`
```json
{
  "success": true,
  "data": {
    "clientSecret": "pi_..._secret_...",
    "paymentIntentId": "pi_..."
  }
}
```

### POST /payments/webhook
Stripe webhook endpoint (not authenticated, verified by signature).

## User Profile

### GET /users/me
Get current user profile.

**Response:** `200 OK`
```json
{
  "success": true,
  "data": {
    "id": 1,
    "email": "user@example.com",
    "firstName": "John",
    "lastName": "Doe",
    "phone": "+1234567890",
    "role": "customer",
    "emailVerified": true,
    "createdAt": "2025-10-01T12:00:00Z"
  }
}
```

### PATCH /users/me
Update user profile.

### PUT /users/me/password
Change password.

**Request:**
```json
{
  "currentPassword": "OldPass123!",
  "newPassword": "NewSecurePass456!"
}
```

## Addresses

### GET /users/me/addresses
List user's addresses.

### POST /users/me/addresses
Create new address.

**Request:**
```json
{
  "addressType": "shipping",
  "isDefault": true,
  "recipientName": "John Doe",
  "phone": "+1234567890",
  "streetAddress1": "123 Main St",
  "streetAddress2": "Apt 4B",
  "city": "New York",
  "state": "NY",
  "postalCode": "10001",
  "country": "US"
}
```

### PATCH /users/me/addresses/:id
Update address.

### DELETE /users/me/addresses/:id
Delete address.

## Admin Endpoints

All admin endpoints require `role: admin` and are prefixed with `/admin`.

### GET /admin/products
List all products (including inactive).

### POST /admin/products
Create new product.

### PATCH /admin/products/:id
Update product.

### DELETE /admin/products/:id
Soft delete product.

### POST /admin/products/:id/inventory
Update inventory.

**Request:**
```json
{
  "quantity": 100,
  "operation": "set" // or "add" or "subtract"
}
```

### GET /admin/orders
List all orders with advanced filters.

### PATCH /admin/orders/:id/status
Update order status.

**Request:**
```json
{
  "status": "shipped",
  "trackingNumber": "1Z999AA1012345678",
  "carrier": "UPS",
  "adminNote": "Shipped via UPS Ground"
}
```

### GET /admin/users
List all users.

### GET /admin/analytics/dashboard
Get dashboard analytics.

**Response:** `200 OK`
```json
{
  "success": true,
  "data": {
    "summary": {
      "totalOrders": 1523,
      "totalRevenue": 152340.50,
      "averageOrderValue": 100.09,
      "totalCustomers": 845
    },
    "recentOrders": [...],
    "topProducts": [...],
    "lowStockProducts": [...]
  }
}
```

### GET /admin/analytics/sales
Sales analytics with date range.

**Query Parameters:**
- `startDate`, `endDate`, `groupBy` (day/week/month)

## Error Responses

All errors follow consistent format:

```json
{
  "success": false,
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "Invalid request data",
    "details": [
      {
        "field": "email",
        "message": "Invalid email format"
      }
    ]
  }
}
```

### Error Codes
- `400` - Bad Request (validation errors)
- `401` - Unauthorized (missing/invalid token)
- `403` - Forbidden (insufficient permissions)
- `404` - Not Found
- `409` - Conflict (duplicate resource)
- `429` - Too Many Requests (rate limit)
- `500` - Internal Server Error

## Rate Limiting

- **Anonymous:** 100 requests/15 minutes
- **Authenticated:** 500 requests/15 minutes
- **Admin:** 1000 requests/15 minutes

Headers:
```
X-RateLimit-Limit: 500
X-RateLimit-Remaining: 498
X-RateLimit-Reset: 1640995200
```

## Pagination

Standard pagination parameters:
- `page` (default: 1)
- `limit` (default: 20, max: 100)

Response includes:
```json
{
  "pagination": {
    "page": 1,
    "limit": 20,
    "total": 150,
    "pages": 8,
    "hasNext": true,
    "hasPrev": false
  }
}
```

## Webhooks

### Order Status Updates
Webhook events sent to configured URLs:
- `order.created`
- `order.updated`
- `order.shipped`
- `order.delivered`
- `order.cancelled`

## OpenAPI/Swagger

Full OpenAPI 3.0 specification available at:
- **Development:** `http://localhost:3000/api-docs`
- **Production:** `https://api.example.com/api-docs`

---

**Document Version:** 1.0  
**Last Updated:** October 24, 2025
