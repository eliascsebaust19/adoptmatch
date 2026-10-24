const { getPool, isMemory, memoryStore } = require('../config/db');

async function getFosterProfiles(req, res) {
  try {
    if (isMemory()) {
      return res.json(memoryStore.fosters);
    }
    const pool = getPool();
    const [rows] = await pool.query(`
      SELECT f.*, u.name, u.email, u.phone
      FROM foster_profiles f
      JOIN users u ON f.user_id = u.id
    `);
    res.json(rows);
  } catch (err) {
    res.status(500).json({ error: 'Failed to fetch foster profiles' });
  }
}

async function createFosterAssignment(req, res) {
  try {
    const { pet_id, foster_user_id, start_date, notes } = req.body;
    const shelter_id = 1;

    if (isMemory()) {
      const pet = memoryStore.pets.find(p => p.id === parseInt(pet_id));
      if (pet) pet.adoption_status = 'Fostered';
      return res.status(201).json({ message: 'Foster assigned successfully' });
    }

    const pool = getPool();
    await pool.query(
      'INSERT INTO foster_assignments (pet_id, foster_user_id, shelter_id, start_date, status, notes) VALUES (?, ?, ?, ?, "Active", ?)',
      [pet_id, foster_user_id, shelter_id, start_date || new Date().toISOString().split('T')[0], notes || '']
    );
    await pool.query('UPDATE pets SET adoption_status = "Fostered" WHERE id = ?', [pet_id]);

    res.status(201).json({ message: 'Foster assigned successfully' });
  } catch (err) {
    res.status(500).json({ error: 'Failed to assign foster' });
  }
}

module.exports = {
  getFosterProfiles,
  createFosterAssignment
};
