import React from 'react';
import { Navbar, Nav, NavDropdown, Badge, Container } from 'react-bootstrap';
import { useSelector, useDispatch } from 'react-redux';
import { Link, useNavigate } from 'react-router-dom';
import { logout } from '../store/authSlice';

const Header = () => {
  const { user, isAuthenticated } = useSelector(state => state.auth);
  const { items } = useSelector(state => state.cart);
  const dispatch = useDispatch();

  const logoutHandler = () => {
    dispatch(logout());
  };

  // Calculate cart count
  const cartCount = Array.isArray(items) 
    ? items.reduce((count, item) => count + (item.quantity || 1), 0)
    : 0;

  return (
    <header>
      <Navbar bg="light" expand="lg" collapseOnSelect>
        <Container>
          <Link to="/" className="navbar-brand">E-Commerce Store</Link>
          <Navbar.Toggle aria-controls="basic-navbar-nav" />
          <Navbar.Collapse id="basic-navbar-nav">
            <Nav className="ms-auto">
              <Nav.Link as={Link} to="/cart">
                Cart 
                {cartCount > 0 && (
                  <Badge bg="danger" className="ms-1">
                    {cartCount}
                  </Badge>
                )}
              </Nav.Link>
              
              {isAuthenticated ? (
                <NavDropdown title={user?.firstName || 'User'} id="username">
                  <NavDropdown.Item as={Link} to="/profile">Profile</NavDropdown.Item>
                  <NavDropdown.Item as={Link} to="/order-history">Order History</NavDropdown.Item>
                  {user?.role === 'admin' && (
                    <NavDropdown.Item as={Link} to="/admin">Admin Dashboard</NavDropdown.Item>
                  )}
                  <NavDropdown.Divider />
                  <NavDropdown.Item onClick={logoutHandler}>
                    Logout
                  </NavDropdown.Item>
                </NavDropdown>
              ) : (
                <>
                  <Nav.Link as={Link} to="/login">Login</Nav.Link>
                  <Nav.Link as={Link} to="/register">Register</Nav.Link>
                </>
              )}
            </Nav>
          </Navbar.Collapse>
        </Container>
      </Navbar>
    </header>
  );
};

export default Header;