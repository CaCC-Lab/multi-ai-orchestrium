import React from 'react';
import styled from 'styled-components';

const FooterContainer = styled.footer`
  background-color: #333;
  color: white;
  padding: 2rem 0;
  margin-top: auto;
`;

const FooterContent = styled.div`
  max-width: 1400px;
  margin: 0 auto;
  padding: 0 2rem;
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
  gap: 2rem;

  @media (max-width: 768px) {
    grid-template-columns: 1fr;
    padding: 0 1rem;
  }
`;

const FooterSection = styled.div`
  h3 {
    margin-bottom: 1rem;
    font-size: 1.2rem;
  }

  ul {
    list-style: none;
    padding: 0;

    li {
      margin-bottom: 0.5rem;

      a {
        color: #ccc;
        text-decoration: none;
        transition: color 0.3s;

        &:hover {
          color: white;
        }
      }
    }
  }
`;

const ContactInfo = styled.div`
  p {
    margin-bottom: 0.5rem;
  }
`;

const SocialLinks = styled.div`
  display: flex;
  gap: 1rem;
  margin-top: 1rem;

  a {
    display: inline-block;
    width: 40px;
    height: 40px;
    background-color: #555;
    border-radius: 50%;
    display: flex;
    align-items: center;
    justify-content: center;
    transition: background-color 0.3s;

    &:hover {
      background-color: #007bff;
    }
  }
`;

const Copyright = styled.div`
  text-align: center;
  padding-top: 2rem;
  margin-top: 2rem;
  border-top: 1px solid #555;
  color: #aaa;
  font-size: 0.9rem;

  @media (max-width: 768px) {
    padding: 1rem;
  }
`;

function Footer() {
  return (
    <FooterContainer>
      <FooterContent>
        <FooterSection>
          <h3>Shop</h3>
          <ul>
            <li><a href="/products">All Products</a></li>
            <li><a href="/categories">Categories</a></li>
            <li><a href="/brands">Brands</a></li>
            <li><a href="/deals">Special Offers</a></li>
          </ul>
        </FooterSection>

        <FooterSection>
          <h3>Customer Service</h3>
          <ul>
            <li><a href="/contact">Contact Us</a></li>
            <li><a href="/shipping">Shipping Policy</a></li>
            <li><a href="/returns">Returns & Exchanges</a></li>
            <li><a href="/faq">FAQs</a></li>
          </ul>
        </FooterSection>

        <FooterSection>
          <h3>About Us</h3>
          <ul>
            <li><a href="/about">Our Story</a></li>
            <li><a href="/careers">Careers</a></li>
            <li><a href="/press">Press</a></li>
            <li><a href="/sustainability">Sustainability</a></li>
          </ul>
        </FooterSection>

        <FooterSection>
          <h3>Contact Info</h3>
          <ContactInfo>
            <p>123 E-Commerce Street</p>
            <p>San Francisco, CA 94107</p>
            <p>Email: info@ecommerce.com</p>
            <p>Phone: (123) 456-7890</p>
            <SocialLinks>
              <a href="#"><i className="fab fa-facebook-f">f</i></a>
              <a href="#"><i className="fab fa-twitter">t</i></a>
              <a href="#"><i className="fab fa-instagram">i</i></a>
              <a href="#"><i className="fab fa-pinterest">p</i></a>
            </SocialLinks>
          </ContactInfo>
        </FooterSection>
      </FooterContent>

      <Copyright>
        <p>&copy; {new Date().getFullYear()} E-Shop. All rights reserved.</p>
      </Copyright>
    </FooterContainer>
  );
}

export default Footer;