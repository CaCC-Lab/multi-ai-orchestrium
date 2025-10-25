import React, { useState, useEffect } from 'react';
import { Link, useNavigate } from 'react-router-dom';
import { useSelector, useDispatch } from 'react-redux';
import styled from 'styled-components';
import { logout } from '../actions/authActions';
import { getCartItems } from '../actions/cartActions';

// Styled components for responsive header
const HeaderContainer = styled.header`
  background-color: #fff;
  box-shadow: 0 2px 4px rgba(0,0,0,0.1);
  position: sticky;
  top: 0;
  z-index: 100;
`;

const Nav = styled.nav`
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 1rem 2rem;
  max-width: 1400px;
  margin: 0 auto;

  @media (max-width: 768px) {
    padding: 1rem;
  }
`;

const Logo = styled(Link)`
  font-size: 1.5rem;
  font-weight: bold;
  color: #333;
  text-decoration: none;
`;

const MenuIcon = styled.div`
  display: none;
  flex-direction: column;
  cursor: pointer;

  @media (max-width: 768px) {
    display: flex;
  }

  span {
    width: 25px;
    height: 3px;
    background-color: #333;
    margin: 3px 0;
    transition: 0.3s;
  }
`;

const NavLinks = styled.div`
  display: flex;
  align-items: center;

  @media (max-width: 768px) {
    position: fixed;
    top: 70px;
    left: ${props => props.isOpen ? '0' : '-100%'};
    width: 100%;
    height: calc(100vh - 70px);
    background-color: #fff;
    flex-direction: column;
    justify-content: flex-start;
    align-items: center;
    padding-top: 2rem;
    transition: left 0.3s ease-in-out;
    z-index: 101;
  }
`;

const NavLink = styled(Link)`
  margin: 0 1rem;
  padding: 0.5rem 1rem;
  border-radius: 4px;
  transition: background-color 0.3s;

  &:hover {
    background-color: #f0f0f0;
  }

  &.active {
    background-color: #007bff;
    color: white;
  }

  @media (max-width: 768px) {
    margin: 0.5rem 0;
    width: 80%;
    text-align: center;
  }
`;

const CartIcon = styled.div`
  position: relative;
  cursor: pointer;
  margin-left: 1rem;

  span {
    position: absolute;
    top: -8px;
    right: -8px;
    background-color: #dc3545;
    color: white;
    border-radius: 50%;
    width: 20px;
    height: 20px;
    display: flex;
    align-items: center;
    justify-content: center;
    font-size: 0.75rem;
  }

  @media (max-width: 768px) {
    margin-left: 0;
    margin-right: 1rem;
  }
`;

const AuthLinks = styled.div`
  display: flex;
  align-items: center;

  button {
    margin-left: 1rem;
    padding: 0.5rem 1rem;
    border: none;
    border-radius: 4px;
    cursor: pointer;
    background-color: #007bff;
    color: white;
    font-weight: bold;

    &:hover {
      background-color: #0056b3;
    }
  }

  @media (max-width: 768px) {
    flex-direction: column;
    width: 100%;
    margin-top: 1rem;

    button {
      margin: 0.5rem 0;
      width: 80%;
    }
  }
`;

function Header() {
  const [mobileMenuOpen, setMobileMenuOpen] = useState(false);
  const { user, isAuthenticated } = useSelector(state => state.auth);
  const { totalItems } = useSelector(state => state.cart);
  const dispatch = useDispatch();
  const navigate = useNavigate();

  useEffect(() => {
    if (isAuthenticated) {
      dispatch(getCartItems());
    }
  }, [isAuthenticated, dispatch]);

  const toggleMobileMenu = () => {
    setMobileMenuOpen(!mobileMenuOpen);
  };

  const handleLogout = () => {
    dispatch(logout());
    setMobileMenuOpen(false); // Close mobile menu after logout
  };

  return (
    <HeaderContainer>
      <Nav>
        <Logo to="/">E-Shop</Logo>
        
        <MenuIcon onClick={toggleMobileMenu}>
          <span></span>
          <span></span>
          <span></span>
        </MenuIcon>
        
        <NavLinks isOpen={mobileMenuOpen}>
          <NavLink to="/" onClick={() => setMobileMenuOpen(false)}>Home</NavLink>
          <NavLink to="/products" onClick={() => setMobileMenuOpen(false)}>Products</NavLink>
          
          {isAuthenticated && user && user.role === 'admin' && (
            <NavLink to="/admin" onClick={() => setMobileMenuOpen(false)}>Admin</NavLink>
          )}
          
          {isAuthenticated ? (
            <AuthLinks>
              <NavLink to="/profile" onClick={() => setMobileMenuOpen(false)}>Profile</NavLink>
              <NavLink to="/orders" onClick={() => setMobileMenuOpen(false)}>Orders</NavLink>
              <CartIcon onClick={() => navigate('/cart')}>
                <i className="fas fa-shopping-cart"></i>
                {totalItems > 0 && <span>{totalItems}</span>}
              </CartIcon>
              <button onClick={handleLogout}>Logout</button>
            </AuthLinks>
          ) : (
            <AuthLinks>
              <NavLink to="/login" onClick={() => setMobileMenuOpen(false)}>Login</NavLink>
              <NavLink to="/register" onClick={() => setMobileMenuOpen(false)}>Register</NavLink>
              <CartIcon onClick={() => navigate('/cart')}>
                <i className="fas fa-shopping-cart"></i>
                {totalItems > 0 && <span>{totalItems}</span>}
              </CartIcon>
            </AuthLinks>
          )}
        </NavLinks>
      </Nav>
    </HeaderContainer>
  );
}

export default Header;