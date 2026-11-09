const { getPool, isMemory, memoryStore } = require('../config/db');

async function getMedicalRecords(req, res) {
  try {
    const petId = parseInt(req.params.petId);
    if (isMemory()) {
      const records = memoryStore.medicalRecords.filter(m => m.pet_id === petId);
      return res.json(records);
    }
    const pool = getPool();
    const [rows] = await pool.query('SELECT * FROM pet_medical_records WHERE pet_id = ? ORDER BY record_date DESC', [petId]);
    res.json(rows);
  } catch (err) {
    res.status(500).json({ error: 'Failed to fetch medical records' });
  }
}

async function addMedicalRecord(req, res) {
  try {
    const petId = parseInt(req.params.petId);
    const { condition_title, treatment_notes, medication, allergies, next_due_date } = req.body;
    const vet_user_id = req.user.id;

    if (isMemory()) {
      const newRec = {
        id: memoryStore.medicalRecords.length + 1,
        pet_id: petId,
        vet_user_id,
        record_date: new Date().toISOString().split('T')[0],
        condition_title,
        treatment_notes,
        medication,
        allergies,
        next_due_date
      };
      memoryStore.medicalRecords.unshift(newRec);
      return res.status(201).json(newRec);
    }

    const pool = getPool();
    const [result] = await pool.query(
      `INSERT INTO pet_medical_records (pet_id, vet_user_id, record_date, condition_title, treatment_notes, medication, allergies, next_due_date)
       VALUES (?, ?, CURDATE(), ?, ?, ?, ?, ?)`,
      [petId, vet_user_id, condition_title, treatment_notes, medication || '', allergies || '', next_due_date || null]
    );

    res.status(201).json({ id: result.insertId, pet_id: petId, condition_title });
  } catch (err) {
    res.status(500).json({ error: 'Failed to add medical record' });
  }
}

module.exports = {
  getMedicalRecords,
  addMedicalRecord
};
