const express = require('express');
const router = express.Router();
const medicalController = require('../controllers/medicalController');
const { authenticateToken, authorizeRoles } = require('../middleware/auth');

router.get('/:petId', authenticateToken, medicalController.getMedicalRecords);
router.post('/:petId', authenticateToken, authorizeRoles('ADMIN', 'SHELTER_STAFF', 'VETERINARIAN'), medicalController.addMedicalRecord);

module.exports = router;
