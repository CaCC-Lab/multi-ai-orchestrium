import React, { useState, useEffect } from 'react';
import { Container, Form, Button, Row, Col, Alert } from 'react-bootstrap';
import { useDispatch, useSelector } from 'react-redux';
import { useNavigate, Link } from 'react-router-dom';
import { loginUser, clearError } from '../store/authSlice';

const Login = () => {
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  
  const dispatch = useDispatch();
  const navigate = useNavigate();
  const { isAuthenticated, error, loading } = useSelector(state => state.auth);

  useEffect(() => {
    if (isAuthenticated) {
      navigate('/');
    }
  }, [isAuthenticated, navigate]);

  const submitHandler = (e) => {
    e.preventDefault();
    dispatch(loginUser({ email, password }));
  };

  const handleDismissError = () => {
    dispatch(clearError());
  };

  return (
    <Container className="my-4">
      <Row className="justify-content-center">
        <Col xs={12} md={6}>
          <h2>Sign In</h2>
          
          {error && (
            <Alert variant="danger" dismissible onClose={handleDismissError}>
              {error}
            </Alert>
          )}
          
          <Form onSubmit={submitHandler}>
            <Form.Group className="mb-3" controlId="email">
              <Form.Label>Email Address</Form.Label>
              <Form.Control
                type="email"
                placeholder="Enter email"
                value={email}
                onChange={(e) => setEmail(e.target.value)}
                required
              />
            </Form.Group>
            
            <Form.Group className="mb-3" controlId="password">
              <Form.Label>Password</Form.Label>
              <Form.Control
                type="password"
                placeholder="Enter password"
                value={password}
                onChange={(e) => setPassword(e.target.value)}
                required
              />
            </Form.Group>
            
            <Button 
              type="submit" 
              variant="primary" 
              disabled={loading}
              className="w-100"
            >
              {loading ? 'Signing In...' : 'Sign In'}
            </Button>
          </Form>
          
          <Row className="py-3">
            <Col>
              New Customer?{' '}
              <Link to="/register">Register</Link>
            </Col>
          </Row>
        </Col>
      </Row>
    </Container>
  );
};

export default Login;