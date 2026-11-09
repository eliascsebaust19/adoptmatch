const express = require('express');
const router = express.Router();
const matchingController = require('../controllers/matchingController');
const { authenticateToken } = require('../middleware/auth');

router.post('/assess', authenticateToken, matchingController.submitAssessment);
router.get('/recommendations', authenticateToken, matchingController.getRecommendations);

module.exports = router;
