import { configureStore } from '@reduxjs/toolkit'
import { 
  persistStore, 
  persistReducer, 
  FLUSH,
  REHYDRATE,
  PAUSE,
  PERSIST,
  PURGE,
  REGISTER 
} from 'redux-persist'
import storage from 'redux-persist/lib/storage'

import cartReducer from './slices/cartSlice'
import userReducer from './slices/userSlice'
import orderReducer from './slices/orderSlice'
import productReducer from './slices/productSlice'

const persistConfig = {
  key: 'root',
  version: 1,
  storage,
}

const persistedCartReducer = persistReducer(persistConfig, cartReducer)
const persistedUserReducer = persistReducer(persistConfig, userReducer)
const persistedOrderReducer = persistReducer(persistConfig, orderReducer)
const persistedProductReducer = persistReducer(persistConfig, productReducer)

export const store = configureStore({
  reducer: {
    cart: persistedCartReducer,
    user: persistedUserReducer,
    order: persistedOrderReducer,
    product: persistedProductReducer,
  },
  middleware: (getDefaultMiddleware) =>
    getDefaultMiddleware({
      serializableCheck: {
        ignoredActions: [FLUSH, REHYDRATE, PAUSE, PERSIST, PURGE, REGISTER],
      },
    }),
})

export let persistor = persistStore(store)