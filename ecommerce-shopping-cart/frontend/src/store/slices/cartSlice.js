import { createSlice, createAsyncThunk } from '@reduxjs/toolkit';
import axios from 'axios';

// Async thunks for cart operations
export const addToCart = createAsyncThunk(
  'cart/addToCart',
  async ({ productId, qty }, { rejectWithValue }) => {
    try {
      const config = {
        headers: {
          'Content-Type': 'application/json',
        },
      };

      const { data } = await axios.post(
        '/api/cart/add',
        { productId, qty },
        config
      );

      return data;
    } catch (error) {
      return rejectWithValue(
        error.response && error.response.data.message
          ? error.response.data.message
          : error.message
      );
    }
  }
);

export const removeFromCart = createAsyncThunk(
  'cart/removeFromCart',
  async (id, { rejectWithValue }) => {
    try {
      const { data } = await axios.delete(`/api/cart/remove/${id}`);

      return data;
    } catch (error) {
      return rejectWithValue(
        error.response && error.response.data.message
          ? error.response.data.message
          : error.message
      );
    }
  }
);

export const getCartItems = createAsyncThunk(
  'cart/getCartItems',
  async (_, { rejectWithValue }) => {
    try {
      const { data } = await axios.get('/api/cart');

      return data;
    } catch (error) {
      return rejectWithValue(
        error.response && error.response.data.message
          ? error.response.data.message
          : error.message
      );
    }
  }
);

const cartSlice = createSlice({
  name: 'cart',
  initialState: {
    cartItems: [],
    shippingAddress: {},
    paymentMethod: 'PayPal',
    currency: 'USD', // Default currency
    itemsPrice: 0,
    shippingPrice: 0,
    taxPrice: 0,
    totalPrice: 0,
    loading: false,
    error: null
  },
  reducers: {
    saveShippingAddress: (state, action) => {
      state.shippingAddress = action.payload;
      localStorage.setItem('shippingAddress', JSON.stringify(action.payload));
    },
    savePaymentMethod: (state, action) => {
      state.paymentMethod = action.payload;
      localStorage.setItem('paymentMethod', JSON.stringify(action.payload));
    },
    setCurrency: (state, action) => {
      state.currency = action.payload;
      localStorage.setItem('currency', JSON.stringify(action.payload));
    },
    clearCart: (state) => {
      state.cartItems = [];
      localStorage.removeItem('cartItems');
    }
  },
  extraReducers: (builder) => {
    builder
      .addCase(addToCart.fulfilled, (state, action) => {
        state.loading = false;
        state.cartItems = action.payload.items;
        localStorage.setItem('cartItems', JSON.stringify(action.payload.items));
        
        // Calculate totals
        let itemsPrice = 0;
        action.payload.items.forEach(item => {
          itemsPrice += item.qty * parseFloat(item.product.price);
        });
        
        state.itemsPrice = itemsPrice;
        state.shippingPrice = action.payload.shippingPrice;
        state.taxPrice = action.payload.taxPrice;
        state.totalPrice = action.payload.totalPrice;
      })
      .addCase(removeFromCart.fulfilled, (state, action) => {
        state.loading = false;
        state.cartItems = action.payload.items;
        localStorage.setItem('cartItems', JSON.stringify(action.payload.items));
        
        // Calculate totals
        let itemsPrice = 0;
        action.payload.items.forEach(item => {
          itemsPrice += item.qty * parseFloat(item.product.price);
        });
        
        state.itemsPrice = itemsPrice;
        state.shippingPrice = action.payload.shippingPrice || 0;
        state.taxPrice = action.payload.taxPrice || 0;
        state.totalPrice = action.payload.totalPrice || 0;
      })
      .addCase(getCartItems.fulfilled, (state, action) => {
        state.loading = false;
        state.cartItems = action.payload.items;
        localStorage.setItem('cartItems', JSON.stringify(action.payload.items));
        
        // Calculate totals
        let itemsPrice = 0;
        action.payload.items.forEach(item => {
          itemsPrice += item.qty * parseFloat(item.product.price);
        });
        
        state.itemsPrice = itemsPrice;
        state.shippingPrice = action.payload.shippingPrice || 0;
        state.taxPrice = action.payload.taxPrice || 0;
        state.totalPrice = action.payload.totalPrice || 0;
      })
      .addMatcher(
        (action) => action.type.endsWith('/pending'),
        (state) => {
          state.loading = true;
          state.error = null;
        }
      )
      .addMatcher(
        (action) => action.type.endsWith('/rejected'),
        (state, action) => {
          state.loading = false;
          state.error = action.payload;
        }
      );
  }
});

export const { saveShippingAddress, savePaymentMethod, clearCart } = cartSlice.actions;
export default cartSlice.reducer;