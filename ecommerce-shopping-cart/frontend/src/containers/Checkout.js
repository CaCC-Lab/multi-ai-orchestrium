import React, { useState, useEffect } from 'react';
import { Container, Form, Button, Card, Col, Row } from 'react-bootstrap';
import { useDispatch, useSelector } from 'react-redux';
import { useNavigate } from 'react-router-dom';
import { createOrder } from '../store/orderSlice';
import { clearCart } from '../store/cartSlice';

const Checkout = () => {
  const [step, setStep] = useState(1); // 1: shipping, 2: payment, 3: confirm
  const [shipping, setShipping] = useState({
    address: '',
    city: '',
    postalCode: '',
    country: ''
  });
  const [payment, setPayment] = useState({
    method: 'card'
  });
  
  const dispatch = useDispatch();
  const navigate = useNavigate();
  const { user } = useSelector(state => state.auth);
  const { items: cartItems, total } = useSelector(state => state.cart);
  const { order, loading, error } = useSelector(state => state.orders);

  useEffect(() => {
    if (!cartItems || cartItems.length === 0) {
      navigate('/cart');
    }
  }, [cartItems, navigate]);

  const shippingHandler = (e) => {
    e.preventDefault();
    setStep(2);
  };

  const paymentHandler = (e) => {
    e.preventDefault();
    setStep(3);
  };

  const placeOrderHandler = () => {
    dispatch(createOrder({
      shippingAddress: shipping,
      paymentMethod: payment.method,
      currency: 'USD'
    }));
  };

  useEffect(() => {
    if (order) {
      dispatch(clearCart());
      navigate(`/order/${order.id}`);
    }
  }, [order, dispatch, navigate]);

  return (
    <Container className="my-4">
      <Row>
        <Col md={8}>
          <h2>Checkout</h2>
          
          {/* Step 1: Shipping */}
          {step === 1 && (
            <Form onSubmit={shippingHandler}>
              <h4>Shipping Address</h4>
              <Form.Group className="mb-3" controlId="address">
                <Form.Label>Address</Form.Label>
                <Form.Control
                  type="text"
                  placeholder="Enter address"
                  value={shipping.address}
                  onChange={(e) => setShipping({...shipping, address: e.target.value})}
                  required
                />
              </Form.Group>
              
              <Form.Group className="mb-3" controlId="city">
                <Form.Label>City</Form.Label>
                <Form.Control
                  type="text"
                  placeholder="Enter city"
                  value={shipping.city}
                  onChange={(e) => setShipping({...shipping, city: e.target.value})}
                  required
                />
              </Form.Group>
              
              <Row>
                <Col md={6}>
                  <Form.Group className="mb-3" controlId="postalCode">
                    <Form.Label>Postal Code</Form.Label>
                    <Form.Control
                      type="text"
                      placeholder="Enter postal code"
                      value={shipping.postalCode}
                      onChange={(e) => setShipping({...shipping, postalCode: e.target.value})}
                      required
                    />
                  </Form.Group>
                </Col>
                <Col md={6}>
                  <Form.Group className="mb-3" controlId="country">
                    <Form.Label>Country</Form.Label>
                    <Form.Control
                      type="text"
                      placeholder="Enter country"
                      value={shipping.country}
                      onChange={(e) => setShipping({...shipping, country: e.target.value})}
                      required
                    />
                  </Form.Group>
                </Col>
              </Row>
              
              <Button type="submit" variant="primary">
                Continue to Payment
              </Button>
            </Form>
          )}
          
          {/* Step 2: Payment */}
          {step === 2 && (
            <Form onSubmit={paymentHandler}>
              <h4>Payment Method</h4>
              <Form.Group className="mb-3">
                <Form.Check
                  type="radio"
                  id="card"
                  name="paymentMethod"
                  label="Credit/Debit Card"
                  checked={payment.method === 'card'}
                  onChange={() => setPayment({...payment, method: 'card'})}
                />
              </Form.Group>
              
              <Row>
                <Col md={6}>
                  <Button 
                    variant="secondary" 
                    onClick={() => setStep(1)}
                    className="w-100"
                  >
                    Back
                  </Button>
                </Col>
                <Col md={6}>
                  <Button 
                    type="submit" 
                    variant="primary"
                    className="w-100"
                  >
                    Continue to Confirm
                  </Button>
                </Col>
              </Row>
            </Form>
          )}
          
          {/* Step 3: Confirm Order */}
          {step === 3 && (
            <div>
              <h4>Order Summary</h4>
              
              <Card className="mb-3">
                <Card.Body>
                  <Card.Title>Shipping Address</Card.Title>
                  <Card.Text>
                    {shipping.address}, {shipping.city} {shipping.postalCode}, {shipping.country}
                  </Card.Text>
                </Card.Body>
              </Card>
              
              <Card className="mb-3">
                <Card.Body>
                  <Card.Title>Payment Method</Card.Title>
                  <Card.Text>Credit/Debit Card</Card.Text>
                </Card.Body>
              </Card>
              
              <h4>Order Items</h4>
              <div className="border rounded p-3 mb-3">
                {cartItems && cartItems.map(item => (
                  <Row key={item.id || item.productId} className="mb-2">
                    <Col>{item.Product ? item.Product.name : 'Product Name'}</Col>
                    <Col className="text-right">
                      {item.quantity} x ${item.priceAtTime || 0} = ${(item.quantity * (item.priceAtTime || 0)).toFixed(2)}
                    </Col>
                  </Row>
                ))}
              </div>
              
              <h4>Total: ${total}</h4>
              
              {error && <div className="alert alert-danger">{error}</div>}
              
              <Row>
                <Col md={6}>
                  <Button 
                    variant="secondary" 
                    onClick={() => setStep(2)}
                    className="w-100"
                    disabled={loading}
                  >
                    Back
                  </Button>
                </Col>
                <Col md={6}>
                  <Button 
                    onClick={placeOrderHandler}
                    variant="success"
                    className="w-100"
                    disabled={loading}
                  >
                    {loading ? 'Placing Order...' : 'Place Order'}
                  </Button>
                </Col>
              </Row>
            </div>
          )}
        </Col>
        
        <Col md={4}>
          <Card>
            <Card.Body>
              <Card.Title>Order Summary</Card.Title>
              <div className="d-flex justify-content-between mb-2">
                <span>Items:</span>
                <strong>${total}</strong>
              </div>
              <div className="d-flex justify-content-between mb-2">
                <span>Shipping:</span>
                <strong>$0.00</strong>
              </div>
              <div className="d-flex justify-content-between mb-2">
                <span>Tax:</span>
                <strong>$0.00</strong>
              </div>
              <hr />
              <div className="d-flex justify-content-between">
                <span>Total:</span>
                <strong>${total}</strong>
              </div>
            </Card.Body>
          </Card>
        </Col>
      </Row>
    </Container>
  );
};

export default Checkout;