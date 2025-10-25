import axios from 'axios';
import { setAlert } from './alertActions';

// Action types
export const ADD_TO_CART = 'ADD_TO_CART';
export const REMOVE_FROM_CART = 'REMOVE_FROM_CART';
export const UPDATE_CART_ITEM = 'UPDATE_CART_ITEM';
export const CLEAR_CART = 'CLEAR_CART';
export const SET_CART = 'SET_CART';

// Add to cart
export const addToCart = (productId, quantity = 1) => async (dispatch) => {
  try {
    const res = await axios.post('/api/cart/add', { productId, quantity });
    
    dispatch({
      type: ADD_TO_CART,
      payload: res.data.cartItem
    });

    dispatch(setAlert('Item added to cart', 'success'));
  } catch (err) {
    dispatch(setAlert(err.response.data.message, 'danger'));
  }
};

// Get cart items
export const getCartItems = () => async (dispatch) => {
  try {
    const res = await axios.get('/api/cart');
    
    dispatch({
      type: SET_CART,
      payload: res.data
    });
  } catch (err) {
    dispatch(setAlert(err.response.data.message, 'danger'));
  }
};

// Update cart item
export const updateCartItem = (cartItemId, quantity) => async (dispatch) => {
  try {
    const res = await axios.put(`/api/cart/${cartItemId}`, { quantity });
    
    dispatch({
      type: UPDATE_CART_ITEM,
      payload: res.data.cartItem
    });

    dispatch(setAlert('Cart updated', 'success'));
  } catch (err) {
    dispatch(setAlert(err.response.data.message, 'danger'));
  }
};

// Remove from cart
export const removeFromCart = (cartItemId) => async (dispatch) => {
  try {
    await axios.delete(`/api/cart/${cartItemId}`);
    
    dispatch({
      type: REMOVE_FROM_CART,
      payload: cartItemId
    });

    dispatch(setAlert('Item removed from cart', 'success'));
  } catch (err) {
    dispatch(setAlert(err.response.data.message, 'danger'));
  }
};

// Clear cart
export const clearCart = () => async (dispatch) => {
  try {
    await axios.delete('/api/cart/clear');
    
    dispatch({
      type: CLEAR_CART
    });

    dispatch(setAlert('Cart cleared', 'success'));
  } catch (err) {
    dispatch(setAlert(err.response.data.message, 'danger'));
  }
};