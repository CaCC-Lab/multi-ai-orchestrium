import React, { useEffect } from 'react';
import { Container, Table, Button } from 'react-bootstrap';
import { useDispatch, useSelector } from 'react-redux';
import { getUserOrders } from '../store/orderSlice';

const OrderHistory = () => {
  const dispatch = useDispatch();
  const { orders, loading, error } = useSelector(state => state.orders);

  useEffect(() => {
    dispatch(getUserOrders());
  }, [dispatch]);

  return (
    <Container className="my-4">
      <h2>Order History</h2>
      
      {loading ? (
        <p>Loading orders...</p>
      ) : error ? (
        <p className="text-danger">Error: {error}</p>
      ) : (
        <Table striped hover responsive className="my-4">
          <thead>
            <tr>
              <th>ID</th>
              <th>DATE</th>
              <th>TOTAL</th>
              <th>STATUS</th>
              <th>ACTIONS</th>
            </tr>
          </thead>
          <tbody>
            {orders && orders.length > 0 ? (
              orders.map(order => (
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
                  <td>
                    <Button variant="light" size="sm">
                      Details
                    </Button>
                  </td>
                </tr>
              ))
            ) : (
              <tr>
                <td colSpan="5">No orders found</td>
              </tr>
            )}
          </tbody>
        </Table>
      )}
    </Container>
  );
};

export default OrderHistory;