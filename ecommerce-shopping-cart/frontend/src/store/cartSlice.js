import { createSlice, createAsyncThunk } from '@reduxjs/toolkit';
import axios from 'axios';

const API_URL = process.env.REACT_APP_API_URL || 'http://localhost:5000/api/v1';

// Load cart from localStorage if needed
const loadCartFromStorage = () => {
  if (typeof window !== 'undefined') {
    const cart = localStorage.getItem('cart');
    return cart ? JSON.parse(cart) : [];
  }
  return [];
};

// Get cart items
export const getCartItems = createAsyncThunk(
  'cart/getItems',
  async (_, { rejectWithValue }) => {
    try {
      const token = localStorage.getItem('token');
      if (!token) {
        // If not logged in, use localStorage cart
        return { items: loadCartFromStorage(), total: 0 };
      }
      
      const config = {
        headers: {
          'Authorization': `Bearer ${token}`
        }
      };
      
      const response = await axios.get('/cart', config);
      return response.data;
    } catch (error) {
      return rejectWithValue(error.response.data.error);
    }
  }
);

// Add to cart
export const addToCart = createAsyncThunk(
  'cart/addItem',
  async ({ productId, quantity }, { rejectWithValue }) => {
    try {
      const token = localStorage.getItem('token');
      if (!token) {
        // If not logged in, use localStorage cart
        const cart = loadCartFromStorage();
        const existingItem = cart.find(item => item.productId === productId);
        
        if (existingItem) {
          existingItem.quantity += quantity;
        } else {
          cart.push({ productId, quantity, price: 0 }); // Price will be set after fetching product
        }
        
        localStorage.setItem('cart', JSON.stringify(cart));
        return { items: cart, total: 0 }; // Total will be calculated after fetching product
      }
      
      const config = {
        headers: {
          'Authorization': `Bearer ${token}`
        }
      };
      
      const response = await axios.post('/cart', { productId, quantity }, config);
      return response.data;
    } catch (error) {
      return rejectWithValue(error.response.data.error);
    }
  }
);

// Update cart item
export const updateCartItem = createAsyncThunk(
  'cart/updateItem',
  async ({ id, quantity }, { rejectWithValue }) => {
    try {
      const token = localStorage.getItem('token');
      if (!token) {
        // If not logged in, update localStorage cart
        const cart = loadCartFromStorage();
        const itemIndex = cart.findIndex(item => item.productId === id);
        if (itemIndex !== -1) {
          if (quantity <= 0) {
            cart.splice(itemIndex, 1);
          } else {
            cart[itemIndex].quantity = quantity;
          }
          localStorage.setItem('cart', JSON.stringify(cart));
        }
        return { items: cart, total: 0 };
      }
      
      const config = {
        headers: {
          'Authorization': `Bearer ${token}`
        }
      };
      
      const response = await axios.put(`/cart/${id}`, { quantity }, config);
      return response.data;
    } catch (error) {
      return rejectWithValue(error.response.data.error);
    }
  }
);

// Remove from cart
export const removeFromCart = createAsyncThunk(
  'cart/removeItem',
  async (id, { rejectWithValue }) => {
    try {
      const token = localStorage.getItem('token');
      if (!token) {
        // If not logged in, update localStorage cart
        let cart = loadCartFromStorage();
        cart = cart.filter(item => item.productId !== id);
        localStorage.setItem('cart', JSON.stringify(cart));
        return { items: cart };
      }
      
      const config = {
        headers: {
          'Authorization': `Bearer ${token}`
        }
      };
      
      const response = await axios.delete(`/cart/${id}`, config);
      return response.data;
    } catch (error) {
      return rejectWithValue(error.response.data.error);
    }
  }
);

// Clear cart
export const clearCart = createAsyncThunk(
  'cart/clear',
  async (_, { rejectWithValue }) => {
    try {
      const token = localStorage.getItem('token');
      if (!token) {
        // If not logged in, clear localStorage cart
        localStorage.removeItem('cart');
        return { items: [] };
      }
      
      const config = {
        headers: {
          'Authorization': `Bearer ${token}`
        }
      };
      
      const response = await axios.delete('/cart', config);
      return response.data;
    } catch (error) {
      return rejectWithValue(error.response.data.error);
    }
  }
);

const cartSlice = createSlice({
  name: 'cart',
  initialState: {
    items: loadCartFromStorage(),
    total: 0,
    loading: false,
    error: null
  },
  reducers: {
    clearCartError: (state) => {
      state.error = null;
    }
  },
  extraReducers: (builder) => {
    builder
      // Get cart items
      .addCase(getCartItems.pending, (state) => {
        state.loading = true;
        state.error = null;
      })
      .addCase(getCartItems.fulfilled, (state, action) => {
        state.loading = false;
        state.items = action.payload.data;
        state.total = action.payload.total;
      })
      .addCase(getCartItems.rejected, (state, action) => {
        state.loading = false;
        state.error = action.payload;
      })
      // Add to cart
      .addCase(addToCart.fulfilled, (state, action) => {
        state.loading = false;
        state.items = action.payload.items;
      })
      .addCase(addToCart.rejected, (state, action) => {
        state.loading = false;
        state.error = action.payload;
      })
      // Update cart item
      .addCase(updateCartItem.fulfilled, (state, action) => {
        state.loading = false;
        state.items = action.payload.items;
      })
      .addCase(updateCartItem.rejected, (state, action) => {
        state.loading = false;
        state.error = action.payload;
      })
      // Remove from cart
      .addCase(removeFromCart.fulfilled, (state, action) => {
        state.loading = false;
        state.items = action.payload.items;
      })
      .addCase(removeFromCart.rejected, (state, action) => {
        state.loading = false;
        state.error = action.payload;
      })
      // Clear cart
      .addCase(clearCart.fulfilled, (state, action) => {
        state.loading = false;
        state.items = [];
        state.total = 0;
      })
      .addCase(clearCart.rejected, (state, action) => {
        state.loading = false;
        state.error = action.payload;
      });
  }
});

export const { clearCartError } = cartSlice.actions;

export default cartSlice.reducer;