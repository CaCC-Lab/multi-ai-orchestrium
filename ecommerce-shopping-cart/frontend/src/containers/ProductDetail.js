import React, { useState, useEffect } from 'react';
import { Container, Row, Col, Button, Card, Image, ListGroup, Form } from 'react-bootstrap';
import { useParams, useNavigate } from 'react-router-dom';
import { useDispatch, useSelector } from 'react-redux';
import { fetchProduct } from '../store/productSlice';
import { addToCart } from '../store/cartSlice';

const ProductDetail = () => {
  const { id } = useParams();
  const navigate = useNavigate();
  const dispatch = useDispatch();
  const { product, loading, error } = useSelector(state => state.products);
  
  const [quantity, setQuantity] = useState(1);

  useEffect(() => {
    if (id) {
      dispatch(fetchProduct(id));
    }
  }, [dispatch, id]);

  const addToCartHandler = () => {
    dispatch(addToCart({ productId: product.id, quantity }));
    navigate('/cart');
  };

  if (loading) return <p>Loading product...</p>;
  if (error) return <p className="text-danger">Error: {error}</p>;

  return (
    <Container>
      {product && (
        <Row>
          <Col md={6}>
            {product.images && product.images.length > 0 ? (
              <Image 
                src={product.images[0]} 
                alt={product.name} 
                fluid 
              />
            ) : (
              <Image 
                src="https://via.placeholder.com/600x400" 
                alt={product.name} 
                fluid 
              />
            )}
          </Col>
          
          <Col md={6}>
            <Card>
              <Card.Body>
                <Card.Title>{product.name}</Card.Title>
                <Card.Text>{product.description}</Card.Text>
                
                <ListGroup variant="flush">
                  <ListGroup.Item>
                    <h3>${product.price}</h3>
                  </ListGroup.Item>
                  
                  <ListGroup.Item>
                    Category: {product.category}
                  </ListGroup.Item>
                  
                  <ListGroup.Item>
                    Status: {product.inventory > 0 ? 'In Stock' : 'Out of Stock'}
                  </ListGroup.Item>
                  
                  {product.inventory > 0 && (
                    <ListGroup.Item>
                      <Row>
                        <Col>Quantity:</Col>
                        <Col>
                          <Form.Control
                            as="select"
                            value={quantity}
                            onChange={(e) => setQuantity(Number(e.target.value))}
                          >
                            {[...Array(product.inventory).keys()].map(x => (
                              <option key={x + 1} value={x + 1}>
                                {x + 1}
                              </option>
                            ))}
                          </Form.Control>
                        </Col>
                      </Row>
                    </ListGroup.Item>
                  )}
                </ListGroup>
                
                <ListGroup.Item>
                  <div className="d-grid gap-2">
                    {product.inventory > 0 ? (
                      <Button
                        onClick={addToCartHandler}
                        disabled={product.inventory === 0}
                        size="lg"
                      >
                        Add to Cart
                      </Button>
                    ) : (
                      <Button variant="danger" disabled size="lg">
                        Out of Stock
                      </Button>
                    )}
                  </div>
                </ListGroup.Item>
              </Card.Body>
            </Card>
          </Col>
        </Row>
      )}
    </Container>
  );
};

export default ProductDetail;