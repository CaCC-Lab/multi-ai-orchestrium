import React, { useEffect } from 'react';
import { useSelector, useDispatch } from 'react-redux';
import styled from 'styled-components';
import { getProducts } from '../actions/productActions';

// Styled components for responsive home page
const HomePageContainer = styled.div`
  max-width: 1400px;
  margin: 0 auto;
  padding: 2rem;

  @media (max-width: 768px) {
    padding: 1rem;
  }
`;

const HeroSection = styled.div`
  background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
  color: white;
  padding: 4rem 2rem;
  text-align: center;
  margin-bottom: 3rem;
  border-radius: 8px;

  h1 {
    font-size: 2.5rem;
    margin-bottom: 1rem;

    @media (max-width: 768px) {
      font-size: 2rem;
    }
  }

  p {
    font-size: 1.2rem;
    max-width: 600px;
    margin: 0 auto;

    @media (max-width: 768px) {
      font-size: 1rem;
    }
  }
`;

const SectionTitle = styled.h2`
  text-align: center;
  margin-bottom: 2rem;
  font-size: 2rem;
  color: #333;

  @media (max-width: 768px) {
    font-size: 1.5rem;
  }
`;

const ProductGrid = styled.div`
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(250px, 1fr));
  gap: 1.5rem;
  margin-bottom: 3rem;

  @media (max-width: 768px) {
    grid-template-columns: repeat(auto-fill, minmax(200px, 1fr));
    gap: 1rem;
  }

  @media (max-width: 480px) {
    grid-template-columns: 1fr;
  }
`;

const ProductCard = styled.div`
  background: white;
  border-radius: 8px;
  overflow: hidden;
  box-shadow: 0 4px 6px rgba(0,0,0,0.1);
  transition: transform 0.3s, box-shadow 0.3s;

  &:hover {
    transform: translateY(-5px);
    box-shadow: 0 8px 15px rgba(0,0,0,0.2);
  }
`;

const ProductImage = styled.div`
  height: 200px;
  background-color: #f0f0f0;
  display: flex;
  align-items: center;
  justify-content: center;
  overflow: hidden;

  img {
    width: 100%;
    height: 100%;
    object-fit: cover;
  }
`;

const ProductInfo = styled.div`
  padding: 1rem;
`;

const ProductName = styled.h3`
  margin-bottom: 0.5rem;
  font-size: 1.1rem;
  color: #333;
`;

const ProductPrice = styled.p`
  font-weight: bold;
  color: #007bff;
  font-size: 1.2rem;
  margin-bottom: 0.5rem;
`;

const ProductCategory = styled.p`
  color: #666;
  font-size: 0.9rem;
`;

const CtaSection = styled.div`
  background-color: #f8f9fa;
  padding: 3rem 2rem;
  text-align: center;
  border-radius: 8px;
  margin-bottom: 3rem;

  h2 {
    margin-bottom: 1rem;
    font-size: 2rem;
    color: #333;

    @media (max-width: 768px) {
      font-size: 1.5rem;
    }
  }

  p {
    margin-bottom: 1.5rem;
    font-size: 1.1rem;
    color: #666;

    @media (max-width: 768px) {
      font-size: 1rem;
    }
  }

  button {
    background-color: #007bff;
    color: white;
    border: none;
    padding: 0.75rem 2rem;
    font-size: 1.1rem;
    border-radius: 4px;
    cursor: pointer;
    transition: background-color 0.3s;

    &:hover {
      background-color: #0056b3;
    }
  }
`;

function Home() {
  const dispatch = useDispatch();
  const { products, loading } = useSelector(state => state.products);

  useEffect(() => {
    dispatch(getProducts());
  }, [dispatch]);

  return (
    <HomePageContainer>
      <HeroSection>
        <h1>Welcome to E-Shop</h1>
        <p>Discover amazing products at unbeatable prices. Shop with confidence and convenience.</p>
      </HeroSection>

      <SectionTitle>Featured Products</SectionTitle>
      {loading ? (
        <p>Loading products...</p>
      ) : (
        <ProductGrid>
          {products.slice(0, 8).map(product => (
            <ProductCard key={product.id}>
              <ProductImage>
                {product.imageUrls && product.imageUrls.length > 0 ? (
                  <img src={product.imageUrls[0]} alt={product.name} />
                ) : (
                  <div>No Image</div>
                )}
              </ProductImage>
              <ProductInfo>
                <ProductName>{product.name}</ProductName>
                <ProductPrice>${product.price}</ProductPrice>
                <ProductCategory>{product.category}</ProductCategory>
              </ProductInfo>
            </ProductCard>
          ))}
        </ProductGrid>
      )}

      <CtaSection>
        <h2>Join Our Community</h2>
        <p>Sign up today to receive exclusive deals, product updates, and special offers.</p>
        <button>Sign Up Now</button>
      </CtaSection>
    </HomePageContainer>
  );
}

export default Home;