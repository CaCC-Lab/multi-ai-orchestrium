const express = require('express');
const { register, login, getMe, logout, forgotPassword, resetPassword, updateDetails, updatePassword } = require('../controllers/auth');
const { protect } = require('../middleware/auth');
const { validateRegisterInput, validateLoginInput, handleValidationErrors, authRateLimiter } = require('../middleware/security');

const router = express.Router();

router.post('/register', authRateLimiter, validateRegisterInput, handleValidationErrors, register);
router.post('/login', authRateLimiter, validateLoginInput, handleValidationErrors, login);
router.get('/me', protect, getMe);
router.get('/logout', protect, logout);
router.post('/forgotpassword', authRateLimiter, forgotPassword);
router.put('/resetpassword/:resettoken', resetPassword);
router.put('/updatedetails', protect, updateDetails);
router.put('/updatepassword', protect, updatePassword);

module.exports = router;