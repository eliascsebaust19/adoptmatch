const express = require('express');
const router = express.Router();
const applicationController = require('../controllers/applicationController');
const { authenticateToken, authorizeRoles } = require('../middleware/auth');

router.post('/', authenticateToken, applicationController.createApplication);
router.get('/', authenticateToken, applicationController.getApplications);
router.patch('/:id/status', authenticateToken, authorizeRoles('ADMIN', 'SHELTER_STAFF'), applicationController.updateApplicationStatus);

module.exports = router;
