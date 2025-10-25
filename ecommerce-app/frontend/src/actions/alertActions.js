// Action types
export const SET_ALERT = 'SET_ALERT';
export const REMOVE_ALERT = 'REMOVE_ALERT';

let alertId = 0;

// Set alert
export const setAlert = (msg, alertType, timeout = 5000) => dispatch => {
  alertId += 1;
  const id = alertId;

  dispatch({
    type: SET_ALERT,
    payload: { msg, alertType, id }
  });

  if (timeout) {
    setTimeout(() => dispatch({ type: REMOVE_ALERT, payload: id }), timeout);
  }
};