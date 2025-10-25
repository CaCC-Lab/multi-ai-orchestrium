import React, { useEffect } from 'react';
import { Link, useNavigate } from 'react-router-dom';
import { useDispatch, useSelector } from 'react-redux';
import { addToCart, removeFromCart } from '../store/slices/cartSlice';
import { Row, Col, ListGroup, Image, Form, Button, Card } from 'react-bootstrap';

function CartScreen() {
  const navigate = useNavigate();
  const dispatch = useDispatch();
  const cart = useSelector((state) => state.cart);
  const { cartItems } = cart;

  const removeFromCartHandler = (id) => {
    dispatch(removeFromCart(id));
  };

  const qtyChangeHandler = (id, qty) => {
    dispatch(addToCart({ productId: id, qty: Number(qty) }));
  };

  const checkoutHandler = () => {
    navigate('/login?redirect=shipping');
  };

  useEffect(() => {
    // Calculate totals when cart items change
  }, [cartItems]);

  // Helper function to get currency symbol
  const getCurrencySymbol = (currency) => {
    switch (currency) {
      case 'USD':
        return '$';
      case 'EUR':
        return '€';
      case 'GBP':
        return '£';
      default:
        return currency; // Return the currency code if not found
    }
  };

  return (
    <Row>
      <Col md={8}>
        <h1 style={{ marginBottom: '20px' }}>Shopping Cart</h1>
        {cartItems.length === 0 ? (
          <div>
            Your cart is empty <Link to="/">Go Back</Link>
          </div>
        ) : (
          <ListGroup variant="flush">
            {cartItems.map((item) => (
              <ListGroup.Item key={item.product.id}>
                <Row>
                  <Col md={2}>
                    <Image src={item.product.image} alt={item.product.name} fluid rounded />
                  </Col>
                  <Col md={3}>
                    <Link to={`/product/${item.product.id}`}>{item.product.name}</Link>
                  </Col>
                  <Col md={2}>
                    {getCurrencySymbol(item.product.currency)}{item.product.price}
                  </Col>
                  <Col md={2}>
                    <Form.Control
                      as="select"
                      value={item.qty}
                      onChange={(e) => qtyChangeHandler(item.product.id, e.target.value)}
                    >
                      {[...Array(item.product.countInStock).keys()].map((x) => (
                        <option key={x + 1} value={x + 1}>
                          {x + 1}
                        </option>
                      ))}
                    </Form.Control>
                  </Col>
                  <Col md={2}>
                    {getCurrencySymbol(item.product.currency)}{(item.qty * item.product.price).toFixed(2)}
                  </Col>
                  <Col md={1}>
                    <Button
                      type="button"
                      variant="light"
                      onClick={() => removeFromCartHandler(item.product.id)}
                    >
                      <i className="fas fa-trash"></i>
                    </Button>
                  </Col>
                </Row>
              </ListGroup.Item>
            ))}
          </ListGroup>
        )}
      </Col>

      <Col md={4}>
        <Card>
          <ListGroup variant="flush">
            <ListGroup.Item>
              <h2>
                Subtotal ({cartItems.reduce((acc, item) => acc + item.qty, 0)}) items
              </h2>
              {cartItems.length > 0 && (
                <>
                  {getCurrencySymbol(cartItems[0].product.currency)}
                  {cartItems
                    .reduce((acc, item) => acc + item.qty * item.product.price, 0)
                    .toFixed(2)}
                </>
              )}
            </ListGroup.Item>
            <ListGroup.Item>
              <Button
                type="button"
                className="btn-block"
                disabled={cartItems.length === 0}
                onClick={checkoutHandler}
              >
                Proceed To Checkout
              </Button>
            </ListGroup.Item>
          </ListGroup>
        </Card>
      </Col>
    </Row>
  );
}

export default CartScreen;