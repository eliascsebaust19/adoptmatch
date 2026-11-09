const express = require('express');
const router = express.Router();
const fosterController = require('../controllers/fosterController');
const { authenticateToken, authorizeRoles } = require('../middleware/auth');

router.get('/', authenticateToken, fosterController.getFosterProfiles);
router.post('/assign', authenticateToken, authorizeRoles('ADMIN', 'SHELTER_STAFF'), fosterController.createFosterAssignment);

module.exports = router;
