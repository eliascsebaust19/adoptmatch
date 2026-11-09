const { getPool, isMemory, memoryStore } = require('../config/db');

async function createApplication(req, res) {
  try {
    const adopter_user_id = req.user.id;
    const { pet_id, housing_details, experience_details, reason_for_adoption, care_plan, agreement_consent = true } = req.body;

    if (!pet_id || !housing_details || !reason_for_adoption) {
      return res.status(400).json({ error: 'Pet ID, housing details, and adoption reason are required' });
    }

    if (isMemory()) {
      const newApp = {
        id: memoryStore.applications.length + 1,
        pet_id: parseInt(pet_id),
        adopter_user_id,
        status: 'Submitted',
        housing_details,
        experience_details: experience_details || 'N/A',
        reason_for_adoption,
        care_plan: care_plan || 'Standard daily care',
        agreement_consent,
        shelter_notes: 'New application received.',
        created_at: new Date().toISOString()
      };
      memoryStore.applications.unshift(newApp);

      // Update pet status to Pending
      const pet = memoryStore.pets.find(p => p.id === parseInt(pet_id));
      if (pet) pet.adoption_status = 'Pending';

      return res.status(201).json(newApp);
    }

    const pool = getPool();
    const [result] = await pool.query(
      `INSERT INTO adoption_applications (pet_id, adopter_user_id, status, housing_details, experience_details, reason_for_adoption, care_plan, agreement_consent)
       VALUES (?, ?, 'Submitted', ?, ?, ?, ?, ?)`,
      [pet_id, adopter_user_id, housing_details, experience_details || '', reason_for_adoption, care_plan || '', agreement_consent]
    );

    const appId = result.insertId;

    // Log history
    await pool.query(
      'INSERT INTO application_status_history (application_id, previous_status, new_status, changed_by_user_id, notes) VALUES (?, NULL, "Submitted", ?, "Application submitted")',
      [appId, adopter_user_id]
    );

    // Update pet status
    await pool.query('UPDATE pets SET adoption_status = "Pending" WHERE id = ?', [pet_id]);

    res.status(201).json({ id: appId, status: 'Submitted' });
  } catch (err) {
    console.error('Create application error:', err);
    res.status(500).json({ error: 'Failed to submit application' });
  }
}

async function getApplications(req, res) {
  try {
    const userId = req.user.id;
    const userRole = req.user.role;

    if (isMemory()) {
      let apps = [...memoryStore.applications];
      if (userRole === 'ADOPTER') {
        apps = apps.filter(a => a.adopter_user_id === userId);
      }
      const detailed = apps.map(app => {
        const pet = memoryStore.pets.find(p => p.id === app.pet_id);
        const adopter = memoryStore.users.find(u => u.id === app.adopter_user_id);
        return {
          ...app,
          pet_name: pet ? pet.name : 'Unknown Pet',
          pet_breed: pet ? pet.breed : '',
          pet_photo: pet && pet.photos ? pet.photos[0] : '',
          adopter_name: adopter ? adopter.name : 'Applicant',
          adopter_email: adopter ? adopter.email : ''
        };
      });
      return res.json(detailed);
    }

    const pool = getPool();
    let sql = `
      SELECT a.*, p.name as pet_name, p.breed as pet_breed, u.name as adopter_name, u.email as adopter_email,
        (SELECT photo_url FROM pet_photos WHERE pet_id = p.id LIMIT 1) as pet_photo
      FROM adoption_applications a
      JOIN pets p ON a.pet_id = p.id
      JOIN users u ON a.adopter_user_id = u.id
    `;
    const params = [];

    if (userRole === 'ADOPTER') {
      sql += ' WHERE a.adopter_user_id = ?';
      params.push(userId);
    } else if (userRole === 'SHELTER_STAFF') {
      // Find shelter
      const [staff] = await pool.query('SELECT shelter_id FROM shelter_staff WHERE user_id = ?', [userId]);
      if (staff.length > 0) {
        sql += ' WHERE p.shelter_id = ?';
        params.push(staff[0].shelter_id);
      }
    }

    sql += ' ORDER BY a.id DESC';
    const [rows] = await pool.query(sql, params);
    res.json(rows);
  } catch (err) {
    console.error('Fetch applications error:', err);
    res.status(500).json({ error: 'Failed to fetch applications' });
  }
}

async function updateApplicationStatus(req, res) {
  try {
    const appId = parseInt(req.params.id);
    const { status, shelter_notes } = req.body;
    const userId = req.user.id;

    if (isMemory()) {
      const app = memoryStore.applications.find(a => a.id === appId);
      if (!app) return res.status(404).json({ error: 'Application not found' });
      app.status = status;
      if (shelter_notes) app.shelter_notes = shelter_notes;

      // If approved, complete adoption
      if (status === 'Approved' || status === 'Completed') {
        const pet = memoryStore.pets.find(p => p.id === app.pet_id);
        if (pet) pet.adoption_status = 'Adopted';
      }

      return res.json(app);
    }

    const pool = getPool();
    const [existing] = await pool.query('SELECT * FROM adoption_applications WHERE id = ?', [appId]);
    if (existing.length === 0) return res.status(404).json({ error: 'Application not found' });

    const prevStatus = existing[0].status;

    await pool.query(
      'UPDATE adoption_applications SET status = ?, shelter_notes = COALESCE(?, shelter_notes) WHERE id = ?',
      [status, shelter_notes, appId]
    );

    // Insert history
    await pool.query(
      'INSERT INTO application_status_history (application_id, previous_status, new_status, changed_by_user_id, notes) VALUES (?, ?, ?, ?, ?)',
      [appId, prevStatus, status, userId, shelter_notes || `Status updated to ${status}`]
    );

    // If Approved / Completed
    if (status === 'Approved' || status === 'Completed') {
      const petId = existing[0].pet_id;
      const adopterId = existing[0].adopter_user_id;

      await pool.query('UPDATE pets SET adoption_status = "Adopted" WHERE id = ?', [petId]);
      
      // Create adoption record if not present
      const [shelterRes] = await pool.query('SELECT shelter_id FROM pets WHERE id = ?', [petId]);
      const shelterId = shelterRes.length > 0 ? shelterRes[0].shelter_id : 1;

      await pool.query(
        'INSERT INTO adoptions (pet_id, application_id, adopter_user_id, shelter_id, adoption_date) VALUES (?, ?, ?, ?, CURDATE()) ON DUPLICATE KEY UPDATE adoption_date = CURDATE()',
        [petId, appId, adopterId, shelterId]
      );
    }

    res.json({ message: `Application status updated to ${status}` });
  } catch (err) {
    console.error('Update status error:', err);
    res.status(500).json({ error: 'Failed to update application status' });
  }
}

module.exports = {
  createApplication,
  getApplications,
  updateApplicationStatus
};
