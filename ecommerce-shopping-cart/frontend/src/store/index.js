import { configureStore } from '@reduxjs/toolkit';
import authReducer from './store/authSlice';
import cartReducer from './store/cartSlice';
import productReducer from './store/productSlice';
import orderReducer from './store/orderSlice';

export const store = configureStore({
  reducer: {
    auth: authReducer,
    cart: cartReducer,
    products: productReducer,
    orders: orderReducer
  },
  middleware: (getDefaultMiddleware) =>
    getDefaultMiddleware({
      serializableCheck: {
        ignoredActions: ['persist/PERSIST', 'persist/REHYDRATE'],
      },
    }),
});