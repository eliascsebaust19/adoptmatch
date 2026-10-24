const { getPool, isMemory, memoryStore } = require('../config/db');

async function getResources(req, res) {
  try {
    if (isMemory()) {
      return res.json(memoryStore.supportResources || [
        { id: 1, title: 'Welcome Home: The 3-3-3 Rule for Pet Adoption', category: 'SETTLING_IN', target_period: 'WEEK_1', content: 'In the first 3 days, your pet may feel overwhelmed. Give them space and a safe corner.' },
        { id: 2, title: 'Establishing a Healthy Feeding & Exercise Routine', category: 'FEEDING', target_period: 'WEEK_1', content: 'Maintain the shelter feeding schedule for the first week to avoid stomach upset.' },
        { id: 3, title: 'Positive Reinforcement & House Rules', category: 'TRAINING', target_period: 'WEEK_2', content: 'Reward good behavior with small treats and gentle verbal praise.' }
      ]);
    }
    const pool = getPool();
    const [rows] = await pool.query('SELECT * FROM support_resources ORDER BY id ASC');
    res.json(rows);
  } catch (err) {
    res.status(500).json({ error: 'Failed to fetch support resources' });
  }
}

async function submitSurvey(req, res) {
  try {
    const { adoption_id = 1, survey_period, adapting_well, eating_normally, sleeping_normally, behavior_issues, aggression_noted, facing_difficulties, notes } = req.body;

    // Calculate Return-Risk Level
    let risk_level = 'LOW_CONCERN';
    if (aggression_noted || (facing_difficulties && behavior_issues)) {
      risk_level = 'HIGH_CONCERN';
    } else if (behavior_issues || facing_difficulties || !adapting_well || !eating_normally) {
      risk_level = 'NEEDS_ATTENTION';
    }

    if (isMemory()) {
      const survey = {
        id: memoryStore.postAdoptionSurveys.length + 1,
        adoption_id,
        survey_period: survey_period || 'WEEK_1',
        adapting_well,
        eating_normally,
        sleeping_normally,
        behavior_issues,
        aggression_noted,
        facing_difficulties,
        notes: notes || '',
        risk_level,
        created_at: new Date().toISOString()
      };
      memoryStore.postAdoptionSurveys.unshift(survey);
      return res.status(201).json(survey);
    }

    const pool = getPool();
    const [result] = await pool.query(
      `INSERT INTO post_adoption_surveys (adoption_id, survey_period, adapting_well, eating_normally, sleeping_normally, behavior_issues, aggression_noted, facing_difficulties, notes, risk_level)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
      [adoption_id, survey_period || 'WEEK_1', adapting_well, eating_normally, sleeping_normally, behavior_issues, aggression_noted, facing_difficulties, notes || '', risk_level]
    );

    res.status(201).json({ id: result.insertId, risk_level });
  } catch (err) {
    res.status(500).json({ error: 'Failed to submit post-adoption survey' });
  }
}

module.exports = {
  getResources,
  submitSurvey
};
