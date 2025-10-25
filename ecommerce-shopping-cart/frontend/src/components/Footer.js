import React from 'react';
import { Container, Row, Col } from 'react-bootstrap';

const Footer = () => {
  const currentYear = new Date().getFullYear();

  return (
    <footer className="bg-light text-dark mt-5 py-4">
      <Container>
        <Row>
          <Col className="text-center">
            <p>&copy; {currentYear} E-Commerce Store. All Rights Reserved.</p>
          </Col>
        </Row>
      </Container>
    </footer>
  );
};

export default Footer;