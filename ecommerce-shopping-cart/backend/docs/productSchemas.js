/**
 * @swagger
 * components:
 *   schemas:
 *     Product:
 *       type: object
 *       required:
 *         - name
 *         - price
 *         - description
 *       properties:
 *         id:
 *           type: integer
 *           description: The auto-generated id of the product
 *           example: 1
 *         name:
 *           type: string
 *           description: Product name
 *           example: Wireless Headphones
 *         description:
 *           type: string
 *           description: Product description
 *           example: High-quality wireless headphones with noise cancellation
 *         price:
 *           type: number
 *           description: Product price
 *           example: 199.99
 *         category:
 *           type: string
 *           description: Product category
 *           example: Electronics
 *         brand:
 *           type: string
 *           description: Product brand
 *           example: SoundTech
 *         image:
 *           type: string
 *           description: Product image URL
 *           example: https://example.com/image.jpg
 *         countInStock:
 *           type: integer
 *           description: Number in stock
 *           example: 10
 *         rating:
 *           type: number
 *           description: Product rating
 *           example: 4.5
 *         numReviews:
 *           type: integer
 *           description: Number of reviews
 *           example: 15
 *         isFeatured:
 *           type: boolean
 *           description: Whether product is featured
 *           example: true
 *         currency:
 *           type: string
 *           description: Currency for the price
 *           example: USD
 *       example:
 *         id: 1
 *         name: Wireless Headphones
 *         description: High-quality wireless headphones with noise cancellation
 *         price: 199.99
 *         category: Electronics
 *         brand: SoundTech
 *         image: https://example.com/image.jpg
 *         countInStock: 10
 *         rating: 4.5
 *         numReviews: 15
 *         isFeatured: true
 *         currency: USD
 */

/**
 * @swagger
 * components:
 *   securitySchemes:
 *     bearerAuth:
 *       type: http
 *       scheme: bearer
 *       bearerFormat: JWT
 */