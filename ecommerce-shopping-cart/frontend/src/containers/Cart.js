import React, { useEffect } from 'react';
import { Container, Table, Button, Row, Col } from 'react-bootstrap';
import { useDispatch, useSelector } from 'react-redux';
import { Link } from 'react-router-dom';
import { getCartItems, removeFromCart, updateCartItem, clearCart } from '../store/cartSlice';

const Cart = () => {
  const dispatch = useDispatch();
  const { items: cartItems, total, loading, error } = useSelector(state => state.cart);

  useEffect(() => {
    dispatch(getCartItems());
  }, [dispatch]);

  const removeFromCartHandler = (id) => {
    dispatch(removeFromCart(id));
  };

  const updateQuantityHandler = (id, quantity) => {
    if (quantity <= 0) {
      dispatch(removeFromCart(id));
    } else {
      dispatch(updateCartItem({ id, quantity }));
    }
  };

  const clearCartHandler = () => {
    dispatch(clearCart());
  };

  if (loading) return <p>Loading cart...</p>;

  return (
    <Container>
      <h1 className="my-4">Shopping Cart</h1>
      
      {error && <p className="text-danger">Error: {error}</p>}
      
      {cartItems && cartItems.length > 0 ? (
        <>
          <Table striped hover responsive className="my-4">
            <thead>
              <tr>
                <th>Product</th>
                <th>Price</th>
                <th>Quantity</th>
                <th>Subtotal</th>
                <th>Actions</th>
              </tr>
            </thead>
            <tbody>
              {cartItems.map((item) => (
                <tr key={item.id || item.productId}>
                  <td>
                    {item.Product ? item.Product.name : 'Product Name'}
                  </td>
                  <td>
                    ${item.priceAtTime ? parseFloat(item.priceAtTime).toFixed(2) : '0.00'}
                  </td>
                  <td>
                    <input
                      type="number"
                      min="1"
                      value={item.quantity}
                      onChange={(e) => updateQuantityHandler(item.id || item.productId, parseInt(e.target.value))}
                      style={{ width: '70px' }}
                    />
                  </td>
                  <td>
                    ${item.quantity * (item.priceAtTime || 0)}
                  </td>
                  <td>
                    <Button
                      variant="danger"
                      size="sm"
                      onClick={() => removeFromCartHandler(item.id || item.productId)}
                    >
                      Remove
                    </Button>
                  </td>
                </tr>
              ))}
            </tbody>
          </Table>
          
          <Row>
            <Col md={8}>
              <Button variant="light" onClick={clearCartHandler}>
                Clear Cart
              </Button>
            </Col>
            <Col md={4}>
              <Table className="table-bordered">
                <tbody>
                  <tr>
                    <td><strong>Total</strong></td>
                    <td><strong>${parseFloat(total || 0).toFixed(2)}</strong></td>
                  </tr>
                </tbody>
              </Table>
              <Link to="/checkout">
                <Button className="btn-block" disabled={parseFloat(total || 0) === 0}>
                  Proceed to Checkout
                </Button>
              </Link>
            </Col>
          </Row>
        </>
      ) : (
        <div className="text-center">
          <p>Your cart is empty</p>
          <Link to="/">
            <Button variant="primary">Go Back Shopping</Button>
          </Link>
        </div>
      )}
    </Container>
  );
};

export default Cart;