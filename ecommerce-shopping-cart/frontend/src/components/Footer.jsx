import React from 'react';
import { Container, Row, Col } from 'react-bootstrap';

function Footer() {
  return (
    <footer>
      <Container>
        <Row>
          <Col className="text-center py-3">
            <h4>E-Commerce Store</h4>
            <p>Copyright &copy; 2025</p>
          </Col>
        </Row>
      </Container>
    </footer>
  );
}

export default Footer;