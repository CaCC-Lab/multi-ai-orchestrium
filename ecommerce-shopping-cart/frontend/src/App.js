import React from 'react';
import { Container } from 'react-bootstrap';
import { Routes, Route } from 'react-router-dom';
import Header from './components/Header';
import Footer from './components/Footer';
import Home from './containers/Home';
import ProductList from './containers/ProductList';
import ProductDetail from './containers/ProductDetail';
import Cart from './containers/Cart';
import Login from './containers/Login';
import Register from './containers/Register';
import Profile from './containers/Profile';
import Checkout from './containers/Checkout';
import OrderHistory from './containers/OrderHistory';
import AdminDashboard from './containers/AdminDashboard';
import './styles/App.css';

function App() {
  return (
    <div className="App">
      <Header />
      <main className="py-3">
        <Container>
          <Routes>
            <Route path="/" element={<Home />} />
            <Route path="/products" element={<ProductList />} />
            <Route path="/product/:id" element={<ProductDetail />} />
            <Route path="/cart" element={<Cart />} />
            <Route path="/login" element={<Login />} />
            <Route path="/register" element={<Register />} />
            <Route path="/profile" element={<Profile />} />
            <Route path="/checkout" element={<Checkout />} />
            <Route path="/order-history" element={<OrderHistory />} />
            <Route path="/admin" element={<AdminDashboard />} />
          </Routes>
        </Container>
      </main>
      <Footer />
    </div>
  );
}

export default App;