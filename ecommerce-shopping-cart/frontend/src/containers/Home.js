import React, { useEffect } from 'react';
import { Container, Row, Col } from 'react-bootstrap';
import { useDispatch, useSelector } from 'react-redux';
import { fetchProducts } from '../store/productSlice';
import ProductCard from '../components/ProductCard';

const Home = () => {
  const dispatch = useDispatch();
  const { items: products, loading, error } = useSelector(state => state.products);

  useEffect(() => {
    dispatch(fetchProducts({ page: 1, limit: 8 })); // Get 8 featured products
  }, [dispatch]);

  return (
    <Container>
      <h1 className="my-4">Featured Products</h1>
      
      {loading ? (
        <p>Loading products...</p>
      ) : error ? (
        <p className="text-danger">Error: {error}</p>
      ) : (
        <Row>
          {products && products.length > 0 ? (
            products.map(product => (
              <Col key={product.id} sm={12} md={6} lg={3} className="mb-4">
                <ProductCard product={product} />
              </Col>
            ))
          ) : (
            <Col>
              <p>No products available.</p>
            </Col>
          )}
        </Row>
      )}
    </Container>
  );
};

export default Home;