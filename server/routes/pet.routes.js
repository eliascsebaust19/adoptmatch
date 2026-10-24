const express = require('express');
const router = express.Router();
const petController = require('../controllers/petController');
const { authenticateToken, authorizeRoles } = require('../middleware/auth');

router.get('/', petController.getPets);
router.get('/:id', petController.getPetById);
router.post('/', authenticateToken, authorizeRoles('ADMIN', 'SHELTER_STAFF'), petController.createPet);
router.put('/:id', authenticateToken, authorizeRoles('ADMIN', 'SHELTER_STAFF'), petController.updatePet);
router.post('/:id/favorite', authenticateToken, petController.toggleFavorite);

module.exports = router;
