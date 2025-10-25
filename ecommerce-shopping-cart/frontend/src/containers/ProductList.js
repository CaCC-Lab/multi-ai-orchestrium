import React, { useEffect, useState } from 'react';
import { Container, Row, Col, Pagination } from 'react-bootstrap';
import { useDispatch, useSelector } from 'react-redux';
import { fetchProducts, searchProducts } from '../store/productSlice';
import ProductCard from '../components/ProductCard';

const ProductList = () => {
  const dispatch = useDispatch();
  const { items: products, loading, error, pagination } = useSelector(state => state.products);
  
  const [currentPage, setCurrentPage] = useState(1);
  const [searchQuery, setSearchQuery] = useState('');
  const [searchCategory, setSearchCategory] = useState('');

  useEffect(() => {
    if (searchQuery || searchCategory) {
      // Perform search
      dispatch(searchProducts({ 
        query: searchQuery, 
        category: searchCategory 
      }));
    } else {
      // Fetch all products
      dispatch(fetchProducts({ page: currentPage, limit: 12 }));
    }
  }, [dispatch, currentPage, searchQuery, searchCategory]);

  const handlePageChange = (pageNumber) => {
    setCurrentPage(pageNumber);
  };

  const handleSearch = (e) => {
    e.preventDefault();
    setCurrentPage(1); // Reset to first page when searching
    dispatch(searchProducts({ 
      query: searchQuery, 
      category: searchCategory 
    }));
  };

  // Generate pagination items
  const renderPagination = () => {
    const items = [];
    for (let number = 1; number <= pagination.pages; number++) {
      items.push(
        <Pagination.Item 
          key={number} 
          active={number === currentPage}
          onClick={() => handlePageChange(number)}
        >
          {number}
        </Pagination.Item>
      );
    }
    return items;
  };

  return (
    <Container>
      <h1 className="my-4">Products</h1>
      
      {/* Search and filter form */}
      <form onSubmit={handleSearch} className="mb-4">
        <Row>
          <Col md={8}>
            <input
              type="text"
              className="form-control"
              placeholder="Search products..."
              value={searchQuery}
              onChange={(e) => setSearchQuery(e.target.value)}
            />
          </Col>
          <Col md={3}>
            <select 
              className="form-control"
              value={searchCategory}
              onChange={(e) => setSearchCategory(e.target.value)}
            >
              <option value="">All Categories</option>
              <option value="Electronics">Electronics</option>
              <option value="Clothing">Clothing</option>
              <option value="Books">Books</option>
              <option value="Home & Kitchen">Home & Kitchen</option>
            </select>
          </Col>
          <Col md={1}>
            <button type="submit" className="btn btn-primary">Search</button>
          </Col>
        </Row>
      </form>
      
      {loading ? (
        <p>Loading products...</p>
      ) : error ? (
        <p className="text-danger">Error: {error}</p>
      ) : (
        <>
          <Row>
            {products && products.length > 0 ? (
              products.map(product => (
                <Col key={product.id} sm={12} md={6} lg={4} xl={3} className="mb-4">
                  <ProductCard product={product} />
                </Col>
              ))
            ) : (
              <Col>
                <p>No products available.</p>
              </Col>
            )}
          </Row>
          
          {pagination.pages > 1 && (
            <div className="d-flex justify-content-center mt-4">
              <Pagination>{renderPagination()}</Pagination>
            </div>
          )}
        </>
      )}
    </Container>
  );
};

export default ProductList;