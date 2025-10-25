import React from 'react';
import { Card, Button } from 'react-bootstrap';
import { Link } from 'react-router-dom';
import { useDispatch } from 'react-redux';
import { addToCart } from '../store/cartSlice';

const ProductCard = ({ product }) => {
  const dispatch = useDispatch();

  const addToCartHandler = () => {
    dispatch(addToCart({ productId: product.id, quantity: 1 }));
  };

  return (
    <Card className="h-100">
      {product.images && product.images.length > 0 ? (
        <Card.Img 
          variant="top" 
          src={product.images[0]} 
          style={{ height: '200px', objectFit: 'cover' }} 
        />
      ) : (
        <Card.Img 
          variant="top" 
          src="https://via.placeholder.com/300x200" 
          style={{ height: '200px', objectFit: 'cover' }} 
        />
      )}
      <Card.Body className="d-flex flex-column">
        <Card.Title>{product.name}</Card.Title>
        <Card.Text className="flex-grow-1">
          {product.description?.substring(0, 60)}...
        </Card.Text>
        <div className="mt-auto">
          <div className="d-flex justify-content-between align-items-center">
            <h5>${product.price}</h5>
            <Button 
              variant="primary" 
              size="sm"
              onClick={addToCartHandler}
            >
              Add to Cart
            </Button>
          </div>
        </div>
      </Card.Body>
    </Card>
  );
};

export default ProductCard;