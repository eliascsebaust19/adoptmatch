const express = require('express');
const router = express.Router();
const analyticsController = require('../controllers/analyticsController');
const { authenticateToken, authorizeRoles } = require('../middleware/auth');

router.get('/', authenticateToken, authorizeRoles('ADMIN', 'SHELTER_STAFF'), analyticsController.getAnalytics);

module.exports = router;
