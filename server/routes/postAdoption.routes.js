const express = require('express');
const router = express.Router();
const postAdoptionController = require('../controllers/postAdoptionController');
const { authenticateToken } = require('../middleware/auth');

router.get('/resources', postAdoptionController.getResources);
router.post('/survey', authenticateToken, postAdoptionController.submitSurvey);

module.exports = router;
