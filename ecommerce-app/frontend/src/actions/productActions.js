import axios from 'axios';
import { setAlert } from './alertActions';

// Action types
export const GET_PRODUCTS_SUCCESS = 'GET_PRODUCTS_SUCCESS';
export const GET_PRODUCT_SUCCESS = 'GET_PRODUCT_SUCCESS';
export const GET_CATEGORIES_SUCCESS = 'GET_CATEGORIES_SUCCESS';
export const GET_BRANDS_SUCCESS = 'GET_BRANDS_SUCCESS';
export const PRODUCT_ERROR = 'PRODUCT_ERROR';
export const SET_FILTERS = 'SET_FILTERS';
export const SET_LOADING = 'SET_LOADING';

// Get products
export const getProducts = (filters = {}) => async (dispatch) => {
  dispatch({ type: SET_LOADING, payload: true });
  
  try {
    const queryString = new URLSearchParams(filters).toString();
    const res = await axios.get(`/api/products?${queryString}`);
    
    dispatch({
      type: GET_PRODUCTS_SUCCESS,
      payload: res.data
    });
  } catch (err) {
    dispatch({
      type: PRODUCT_ERROR,
      payload: err.response.data.message
    });
  }
};

// Get a single product
export const getProduct = (id) => async (dispatch) => {
  dispatch({ type: SET_LOADING, payload: true });
  
  try {
    const res = await axios.get(`/api/products/${id}`);
    
    dispatch({
      type: GET_PRODUCT_SUCCESS,
      payload: res.data.product
    });
  } catch (err) {
    dispatch({
      type: PRODUCT_ERROR,
      payload: err.response.data.message
    });
  }
};

// Get product categories
export const getCategories = () => async (dispatch) => {
  try {
    const res = await axios.get('/api/products/categories');
    
    dispatch({
      type: GET_CATEGORIES_SUCCESS,
      payload: res.data
    });
  } catch (err) {
    dispatch({
      type: PRODUCT_ERROR,
      payload: err.response.data.message
    });
  }
};

// Get product brands
export const getBrands = () => async (dispatch) => {
  try {
    const res = await axios.get('/api/products/brands');
    
    dispatch({
      type: GET_BRANDS_SUCCESS,
      payload: res.data
    });
  } catch (err) {
    dispatch({
      type: PRODUCT_ERROR,
      payload: err.response.data.message
    });
  }
};

// Set filters
export const setFilters = (filters) => (dispatch) => {
  dispatch({
    type: SET_FILTERS,
    payload: filters
  });
};