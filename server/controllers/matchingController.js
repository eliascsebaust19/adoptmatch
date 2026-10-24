const axios = require('axios');
const { getPool, isMemory, memoryStore } = require('../config/db');

const AI_SERVICE_URL = process.env.AI_SERVICE_URL || 'http://localhost:8000';

async function submitAssessment(req, res) {
  try {
    const userId = req.user.id;
    const assessmentData = req.body;

    if (isMemory()) {
      memoryStore.assessments[userId] = { ...assessmentData, user_id: userId, updated_at: new Date().toISOString() };
    } else {
      const pool = getPool();
      const fields = [
        'user_id', 'daily_free_time_hours', 'working_schedule', 'activity_level', 'travel_frequency',
        'pet_experience', 'housing_type', 'has_yard', 'yard_fenced', 'living_space_sqft',
        'landlord_allows_pets', 'has_children', 'has_elderly', 'has_other_pets', 'preferred_species',
        'preferred_age_min', 'preferred_age_max', 'preferred_size', 'preferred_gender',
        'training_willingness', 'grooming_willingness', 'special_needs_willingness'
      ];
      const placeholders = fields.map(() => '?').join(', ');
      const values = fields.map(f => assessmentData[f] !== undefined ? assessmentData[f] : null);
      values[0] = userId;

      await pool.query(
        `INSERT INTO adopter_assessments (${fields.join(', ')}) VALUES (${placeholders})
         ON DUPLICATE KEY UPDATE ${fields.map(f => `${f} = VALUES(${f})`).join(', ')}`,
        values
      );
    }

    res.json({ message: 'Assessment saved successfully', assessment: assessmentData });
  } catch (err) {
    console.error('Submit assessment error:', err);
    res.status(500).json({ error: 'Failed to save lifestyle assessment' });
  }
}

async function getRecommendations(req, res) {
  try {
    const userId = req.user.id;
    let assessment = null;
    let petsList = [];

    if (isMemory()) {
      assessment = memoryStore.assessments[userId] || {
        daily_free_time_hours: 4, working_schedule: 'HYBRID', activity_level: 'MODERATE',
        travel_frequency: 'SELDOM', pet_experience: 'INTERMEDIATE', housing_type: 'HOUSE',
        has_yard: true, yard_fenced: true, living_space_sqft: 1800, landlord_allows_pets: true,
        has_children: true, has_elderly: false, has_other_pets: false, preferred_species: 'Dog',
        preferred_age_min: 0, preferred_age_max: 180, preferred_size: 'Medium', preferred_gender: 'Any',
        training_willingness: 'MODERATE', grooming_willingness: 'MODERATE', special_needs_willingness: false
      };
      petsList = memoryStore.pets.filter(p => p.adoption_status === 'Available' || p.adoption_status === 'Pending');
    } else {
      const pool = getPool();
      const [assRows] = await pool.query('SELECT * FROM adopter_assessments WHERE user_id = ?', [userId]);
      if (assRows.length > 0) {
        assessment = assRows[0];
      } else {
        assessment = {
          daily_free_time_hours: 4, working_schedule: 'HYBRID', activity_level: 'MODERATE',
          travel_frequency: 'SELDOM', pet_experience: 'INTERMEDIATE', housing_type: 'HOUSE',
          has_yard: true, yard_fenced: true, living_space_sqft: 1800, landlord_allows_pets: true,
          has_children: true, has_elderly: false, has_other_pets: false, preferred_species: 'Dog',
          preferred_age_min: 0, preferred_age_max: 180, preferred_size: 'Medium', preferred_gender: 'Any',
          training_willingness: 'MODERATE', grooming_willingness: 'MODERATE', special_needs_willingness: false
        };
      }
      const [petRows] = await pool.query(`
        SELECT p.*, s.name as shelter_name,
          COALESCE(
            (SELECT JSON_ARRAYAGG(photo_url) FROM pet_photos WHERE pet_id = p.id),
            JSON_ARRAY('https://images.unsplash.com/photo-1552053831-71594a27632d?w=800')
          ) as photos
        FROM pets p
        JOIN shelters s ON p.shelter_id = s.id
        WHERE p.adoption_status IN ('Available', 'Pending')
      `);
      petsList = petRows;
    }

    // Call Python FastAPI microservice
    let recommendations = [];
    try {
      const aiResponse = await axios.post(`${AI_SERVICE_URL}/api/v1/match`, {
        assessment,
        pets: petsList
      }, { timeout: 3000 });

      if (aiResponse.data && aiResponse.data.results) {
        recommendations = aiResponse.data.results;
      }
    } catch (aiErr) {
      console.warn('⚠️ Python AI service unreachable, fallback to internal match calculator.');
      // Internal calculation fallback
      recommendations = petsList.map(pet => calculateInternalScore(assessment, pet));
      recommendations.sort((a, b) => b.score - a.score);
    }

    // Combine pet details with match score results
    const combined = recommendations.map(rec => {
      const pet = petsList.find(p => p.id === rec.pet_id);
      return {
        ...pet,
        matchScore: rec.score,
        classification: rec.classification,
        reasons: rec.reasons,
        considerations: rec.considerations
      };
    });

    res.json({
      total: combined.length,
      assessment,
      recommendations: combined
    });
  } catch (err) {
    console.error('Fetch recommendations error:', err);
    res.status(500).json({ error: 'Failed to generate recommendations' });
  }
}

function calculateInternalScore(assessment, pet) {
  let score = 70;
  const reasons = [];
  const considerations = [];

  if (assessment.housing_type === 'APARTMENT' && pet.apartment_friendly) {
    score += 10;
    reasons.push('Great apartment companion');
  } else if (assessment.housing_type === 'HOUSE') {
    score += 10;
    reasons.push('House provides adequate space');
  }

  if (assessment.has_children && pet.child_friendly) {
    score += 10;
    reasons.push('Child friendly & patient');
  }

  if (assessment.activity_level === 'MODERATE' && pet.energy_level === 'Moderate') {
    score += 10;
    reasons.push('Matches your moderate daily activity');
  }

  if (pet.grooming_requirement === 'High' && assessment.grooming_willingness === 'LOW') {
    score -= 10;
    considerations.push('Requires regular professional grooming');
  }

  score = Math.min(100, Math.max(0, score));

  return {
    pet_id: pet.id,
    score,
    classification: score >= 85 ? 'Excellent Match' : score >= 70 ? 'Good Match' : 'Fair Match',
    reasons,
    considerations
  };
}

module.exports = {
  submitAssessment,
  getRecommendations
};
