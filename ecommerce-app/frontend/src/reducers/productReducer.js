const initialState = {
  products: [],
  product: null,
  loading: true,
  error: null,
  categories: [],
  brands: [],
  filteredProducts: [],
  filters: {
    search: '',
    category: '',
    brand: '',
    minPrice: 0,
    maxPrice: 0,
    inStock: false
  },
  pagination: {
    currentPage: 1,
    totalPages: 1,
    hasNextPage: false,
    hasPrevPage: false,
    count: 0
  }
};

export default function productReducer(state = initialState, action) {
  const { type, payload } = action;

  switch (type) {
    case 'GET_PRODUCTS_SUCCESS':
      return {
        ...state,
        products: payload.products,
        loading: false,
        pagination: {
          currentPage: payload.currentPage,
          totalPages: payload.totalPages,
          hasNextPage: payload.hasNextPage,
          hasPrevPage: payload.hasPrevPage,
          count: payload.count
        }
      };
    
    case 'GET_PRODUCT_SUCCESS':
      return {
        ...state,
        product: payload.product,
        loading: false
      };
    
    case 'GET_CATEGORIES_SUCCESS':
      return {
        ...state,
        categories: payload.categories
      };
    
    case 'GET_BRANDS_SUCCESS':
      return {
        ...state,
        brands: payload.brands
      };
    
    case 'SET_FILTERS':
      return {
        ...state,
        filters: {
          ...state.filters,
          ...payload
        }
      };
    
    case 'PRODUCT_ERROR':
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