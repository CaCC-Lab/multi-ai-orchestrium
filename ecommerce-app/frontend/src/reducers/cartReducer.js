const initialState = {
  items: [],
  total: 0,
  totalItems: 0
};

export default function cartReducer(state = initialState, action) {
  const { type, payload } = action;

  switch (type) {
    case 'ADD_TO_CART':
      // Check if item already exists in cart
      const existingItemIndex = state.items.findIndex(item => item.productId === payload.productId);
      
      if (existingItemIndex >= 0) {
        // Update quantity if item exists
        const updatedItems = [...state.items];
        updatedItems[existingItemIndex] = {
          ...updatedItems[existingItemIndex],
          quantity: updatedItems[existingItemIndex].quantity + payload.quantity
        };
        
        // Recalculate total
        const newTotal = updatedItems.reduce((sum, item) => sum + (item.priceAtTime * item.quantity), 0);
        const newTotalItems = updatedItems.reduce((sum, item) => sum + item.quantity, 0);
        
        return {
          ...state,
          items: updatedItems,
          total: parseFloat(newTotal.toFixed(2)),
          totalItems: newTotalItems
        };
      } else {
        // Add new item to cart
        const newItems = [...state.items, payload];
        
        // Recalculate total
        const newTotal = newItems.reduce((sum, item) => sum + (item.priceAtTime * item.quantity), 0);
        const newTotalItems = newItems.reduce((sum, item) => sum + item.quantity, 0);
        
        return {
          ...state,
          items: newItems,
          total: parseFloat(newTotal.toFixed(2)),
          totalItems: newTotalItems
        };
      }
    
    case 'REMOVE_FROM_CART':
      const filteredItems = state.items.filter(item => item.id !== payload);
      
      // Recalculate total
      const updatedTotal = filteredItems.reduce((sum, item) => sum + (item.priceAtTime * item.quantity), 0);
      const updatedTotalItems = filteredItems.reduce((sum, item) => sum + item.quantity, 0);
      
      return {
        ...state,
        items: filteredItems,
        total: parseFloat(updatedTotal.toFixed(2)),
        totalItems: updatedTotalItems
      };
    
    case 'UPDATE_CART_ITEM':
      const updatedItems = state.items.map(item => 
        item.id === payload.id 
          ? { ...item, quantity: payload.quantity } 
          : item
      );
      
      // Recalculate total
      const newTotal = updatedItems.reduce((sum, item) => sum + (item.priceAtTime * item.quantity), 0);
      const newTotalItems = updatedItems.reduce((sum, item) => sum + item.quantity, 0);
      
      return {
        ...state,
        items: updatedItems,
        total: parseFloat(newTotal.toFixed(2)),
        totalItems: newTotalItems
      };
    
    case 'CLEAR_CART':
      return {
        ...state,
        items: [],
        total: 0,
        totalItems: 0
      };
    
    case 'SET_CART':
      // Set cart from server response
      return {
        ...state,
        items: payload.cartItems,
        total: payload.totalPrice,
        totalItems: payload.totalItems
      };

    default:
      return state;
  }
}