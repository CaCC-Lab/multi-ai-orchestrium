const initialState = {
  user: null,
  isAuthenticated: false,
  loading: true,
  error: null
};

export default function authReducer(state = initialState, action) {
  const { type, payload } = action;

  switch (type) {
    case 'REGISTER_SUCCESS':
    case 'LOGIN_SUCCESS':
      localStorage.setItem('token', payload.token);
      return {
        ...state,
        ...payload,
        isAuthenticated: true,
        loading: false
      };
    
    case 'AUTH_ERROR':
    case 'LOGIN_FAIL':
    case 'LOGOUT':
      localStorage.removeItem('token');
      return {
        ...state,
        user: null,
        isAuthenticated: false,
        loading: false,
        error: payload
      };
    
    case 'USER_LOADED':
      return {
        ...state,
        user: payload,
        isAuthenticated: true,
        loading: false
      };
    
    case 'UPDATE_PROFILE':
      return {
        ...state,
        user: payload
      };

    default:
      return state;
  }
}