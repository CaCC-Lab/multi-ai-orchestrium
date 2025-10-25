const initialState = {
  orders: [],
  order: null,
  loading: true,
  error: null,
  pagination: {
    currentPage: 1,
    totalPages: 1,
    hasNextPage: false,
    hasPrevPage: false,
    count: 0
  }
};

export default function orderReducer(state = initialState, action) {
  const { type, payload } = action;

  switch (type) {
    case 'GET_ORDERS_SUCCESS':
      return {
        ...state,
        orders: payload.orders,
        loading: false,
        pagination: {
          currentPage: payload.currentPage,
          totalPages: payload.totalPages,
          hasNextPage: payload.hasNextPage,
          hasPrevPage: payload.hasPrevPage,
          count: payload.count
        }
      };
    
    case 'GET_ORDER_SUCCESS':
      return {
        ...state,
        order: payload.order,
        loading: false
      };
    
    case 'CREATE_ORDER_SUCCESS':
      return {
        ...state,
        order: payload.order,
        loading: false
      };
    
    case 'ORDER_ERROR':
      return {
        ...state,
        error: payload,
        loading: false
      };
    
    case 'SET_LOADING':
      return {
        ...state,
        loading: payload
      };

    default:
      return state;
  }
}