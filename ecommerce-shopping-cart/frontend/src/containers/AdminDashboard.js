import React, { useEffect } from 'react';
import { Container, Row, Col, Card, Table } from 'react-bootstrap';
import { useDispatch, useSelector } from 'react-redux';
import { getAllOrders } from '../store/orderSlice';
import { fetchProducts } from '../store/productSlice';

const AdminDashboard = () => {
  const dispatch = useDispatch();
  const { orders } = useSelector(state => state.orders);
  const { items: products } = useSelector(state => state.products);

  useEffect(() => {
    dispatch(getAllOrders());
    dispatch(fetchProducts({ page: 1, limit: 5 })); // Get 5 latest products
  }, [dispatch]);

  // Sample summary data
  const totalOrders = orders ? orders.length : 0;
  const totalProducts = products ? products.length : 0;
  const totalRevenue = orders 
    ? orders.reduce((sum, order) => sum + parseFloat(order.totalAmount), 0) 
    : 0;

  return (
    <Container className="my-4">
      <h2>Admin Dashboard</h2>
      
      {/* Summary cards */}
      <Row className="mb-4">
        <Col md={4} className="mb-3">
          <Card>
            <Card.Body>
              <Card.Title>Total Orders</Card.Title>
              <Card.Text className="display-4">{totalOrders}</Card.Text>
            </Card.Body>
          </Card>
        </Col>
        <Col md={4} className="mb-3">
          <Card>
            <Card.Body>
              <Card.Title>Total Products</Card.Title>
              <Card.Text className="display-4">{totalProducts}</Card.Text>
            </Card.Body>
          </Card>
        </Col>
        <Col md={4} className="mb-3">
          <Card>
            <Card.Body>
              <Card.Title>Total Revenue</Card.Title>
              <Card.Text className="display-4">${totalRevenue.toFixed(2)}</Card.Text>
            </Card.Body>
          </Card>
        </Col>
      </Row>
      
      {/* Recent Orders */}
      <Row>
        <Col md={8}>
          <Card>
            <Card.Body>
              <Card.Title>Recent Orders</Card.Title>
              <Table striped hover responsive>
                <thead>
                  <tr>
                    <th>Order ID</th>
                    <th>Date</th>
                    <th>Total</th>
                    <th>Status</th>
                  </tr>
                </thead>
                <tbody>
                  {orders && orders.slice(0, 5).map(order => (
                    <tr key={order.id}>
                      <td>{order.orderNumber}</td>
                      <td>{new Date(order.createdAt).toLocaleDateString()}</td>
                      <td>${order.totalAmount}</td>
                      <td>
                        <span className={`badge ${
                          order.status === 'delivered' ? 'bg-success' :
                          order.status === 'cancelled' ? 'bg-danger' :
                          order.status === 'shipped' ? 'bg-warning' : 'bg-info'
                        }`}>
                          {order.status}
                        </span>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </Table>
            </Card.Body>
          </Card>
        </Col>
        
        <Col md={4}>
          <Card>
            <Card.Body>
              <Card.Title>Quick Actions</Card.Title>
              <div className="d-grid gap-2">
                <button className="btn btn-primary">Manage Products</button>
                <button className="btn btn-outline-primary">Manage Orders</button>
                <button className="btn btn-outline-primary">Manage Users</button>
                <button className="btn btn-outline-primary">View Reports</button>
              </div>
            </Card.Body>
          </Card>
        </Col>
      </Row>
    </Container>
  );
};

export default AdminDashboard;