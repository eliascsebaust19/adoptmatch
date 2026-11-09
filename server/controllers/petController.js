const { getPool, isMemory, memoryStore } = require('../config/db');

async function getPets(req, res) {
  try {
    const { species, age, size, energy, status = 'Available', search } = req.query;

    if (isMemory()) {
      let filtered = [...memoryStore.pets];
      if (status !== 'All') {
        filtered = filtered.filter(p => p.adoption_status.toLowerCase() === status.toLowerCase());
      }
      if (species && species !== 'All') {
        filtered = filtered.filter(p => p.species.toLowerCase() === species.toLowerCase());
      }
      if (size && size !== 'All') {
        filtered = filtered.filter(p => p.size.toLowerCase() === size.toLowerCase());
      }
      if (energy && energy !== 'All') {
        filtered = filtered.filter(p => p.energy_level.toLowerCase() === energy.toLowerCase());
      }
      if (search) {
        const query = search.toLowerCase();
        filtered = filtered.filter(p => 
          p.name.toLowerCase().includes(query) || 
          p.breed.toLowerCase().includes(query) ||
          p.location.toLowerCase().includes(query)
        );
      }
      return res.json(filtered);
    }

    const pool = getPool();
    let sql = `
      SELECT p.*, s.name as shelter_name,
        COALESCE(
          (SELECT JSON_ARRAYAGG(photo_url) FROM pet_photos WHERE pet_id = p.id),
          JSON_ARRAY('https://images.unsplash.com/photo-1552053831-71594a27632d?w=800')
        ) as photos
      FROM pets p
      JOIN shelters s ON p.shelter_id = s.id
      WHERE 1=1
    `;
    const params = [];

    if (status !== 'All') {
      sql += ' AND p.adoption_status = ?';
      params.push(status);
    }
    if (species && species !== 'All') {
      sql += ' AND p.species = ?';
      params.push(species);
    }
    if (size && size !== 'All') {
      sql += ' AND p.size = ?';
      params.push(size);
    }
    if (energy && energy !== 'All') {
      sql += ' AND p.energy_level = ?';
      params.push(energy);
    }
    if (search) {
      sql += ' AND (p.name LIKE ? OR p.breed LIKE ? OR p.location LIKE ?)';
      const queryStr = `%${search}%`;
      params.push(queryStr, queryStr, queryStr);
    }

    sql += ' ORDER BY p.id DESC';
    const [rows] = await pool.query(sql, params);
    res.json(rows);
  } catch (err) {
    console.error('Fetch pets error:', err);
    res.status(500).json({ error: 'Failed to fetch pets' });
  }
}

async function getPetById(req, res) {
  try {
    const petId = parseInt(req.params.id);

    if (isMemory()) {
      const pet = memoryStore.pets.find(p => p.id === petId);
      if (!pet) return res.status(404).json({ error: 'Pet not found' });
      const shelter = memoryStore.shelters.find(s => s.id === pet.shelter_id) || memoryStore.shelters[0];
      const medical = memoryStore.medicalRecords.filter(m => m.pet_id === petId);
      const behavior = memoryStore.behaviorRecords.filter(b => b.pet_id === petId);
      return res.json({ ...pet, shelter, medical, behavior });
    }

    const pool = getPool();
    const [rows] = await pool.query(`
      SELECT p.*, s.name as shelter_name, s.phone as shelter_phone, s.email as shelter_email, s.address as shelter_address,
        COALESCE(
          (SELECT JSON_ARRAYAGG(photo_url) FROM pet_photos WHERE pet_id = p.id),
          JSON_ARRAY('https://images.unsplash.com/photo-1552053831-71594a27632d?w=800')
        ) as photos
      FROM pets p
      JOIN shelters s ON p.shelter_id = s.id
      WHERE p.id = ?
    `, [petId]);

    if (rows.length === 0) return res.status(404).json({ error: 'Pet not found' });

    const pet = rows[0];
    const [medical] = await pool.query('SELECT * FROM pet_medical_records WHERE pet_id = ?', [petId]);
    const [behavior] = await pool.query('SELECT * FROM pet_behavior_records WHERE pet_id = ?', [petId]);
    const [vaccinations] = await pool.query('SELECT * FROM pet_vaccinations WHERE pet_id = ?', [petId]);

    res.json({
      ...pet,
      medical,
      behavior,
      vaccinations,
      shelter: {
        id: pet.shelter_id,
        name: pet.shelter_name,
        phone: pet.shelter_phone,
        email: pet.shelter_email,
        address: pet.shelter_address
      }
    });
  } catch (err) {
    console.error('Fetch pet details error:', err);
    res.status(500).json({ error: 'Failed to fetch pet details' });
  }
}

async function createPet(req, res) {
  try {
    const { name, species, breed, age_months, gender, size, weight_lbs, energy_level, temperament, description, photos, location, shelter_id = 1 } = req.body;

    if (!name || !species || !breed) {
      return res.status(400).json({ error: 'Name, species, and breed are required' });
    }

    if (isMemory()) {
      const newPet = {
        id: memoryStore.pets.length + 1,
        shelter_id,
        name,
        species,
        breed,
        age_months: parseInt(age_months || 12),
        gender: gender || 'Male',
        size: size || 'Medium',
        weight_lbs: parseFloat(weight_lbs || 25),
        energy_level: energy_level || 'Moderate',
        temperament: temperament || 'Friendly',
        description: description || 'No description provided.',
        child_friendly: 1,
        dog_friendly: 1,
        cat_friendly: 1,
        apartment_friendly: 1,
        house_trained: 1,
        leash_trained: 1,
        grooming_requirement: 'Moderate',
        exercise_requirement: 'Moderate',
        special_needs: 0,
        medical_status: 'Healthy',
        adoption_status: 'Available',
        location: location || 'Seattle, WA',
        photos: photos && photos.length > 0 ? photos : ['https://images.unsplash.com/photo-1552053831-71594a27632d?w=800']
      };
      memoryStore.pets.unshift(newPet);
      return res.status(201).json(newPet);
    }

    const pool = getPool();
    const [result] = await pool.query(
      `INSERT INTO pets (shelter_id, name, species, breed, age_months, gender, size, weight_lbs, energy_level, temperament, description, location)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
      [shelter_id, name, species, breed, age_months || 12, gender || 'Male', size || 'Medium', weight_lbs || 25, energy_level || 'Moderate', temperament || 'Friendly', description || '', location || 'Seattle, WA']
    );

    const petId = result.insertId;
    if (photos && Array.isArray(photos)) {
      for (let i = 0; i < photos.length; i++) {
        await pool.query('INSERT INTO pet_photos (pet_id, photo_url, is_primary) VALUES (?, ?, ?)', [petId, photos[i], i === 0]);
      }
    }

    res.status(201).json({ id: petId, name, species, breed, adoption_status: 'Available' });
  } catch (err) {
    console.error('Create pet error:', err);
    res.status(500).json({ error: 'Failed to create pet' });
  }
}

async function updatePet(req, res) {
  try {
    const petId = parseInt(req.params.id);
    if (isMemory()) {
      const idx = memoryStore.pets.findIndex(p => p.id === petId);
      if (idx === -1) return res.status(404).json({ error: 'Pet not found' });
      memoryStore.pets[idx] = { ...memoryStore.pets[idx], ...req.body };
      return res.json(memoryStore.pets[idx]);
    }

    const pool = getPool();
    const { name, adoption_status, description, medical_status } = req.body;
    await pool.query(
      'UPDATE pets SET name = COALESCE(?, name), adoption_status = COALESCE(?, adoption_status), description = COALESCE(?, description), medical_status = COALESCE(?, medical_status) WHERE id = ?',
      [name, adoption_status, description, medical_status, petId]
    );

    res.json({ message: 'Pet updated successfully' });
  } catch (err) {
    res.status(500).json({ error: 'Failed to update pet' });
  }
}

async function toggleFavorite(req, res) {
  try {
    const userId = req.user.id;
    const petId = parseInt(req.params.id);

    if (isMemory()) {
      const existingIdx = memoryStore.favorites.findIndex(f => f.user_id === userId && f.pet_id === petId);
      if (existingIdx >= 0) {
        memoryStore.favorites.splice(existingIdx, 1);
        return res.json({ favorited: false });
      } else {
        memoryStore.favorites.push({ id: memoryStore.favorites.length + 1, user_id: userId, pet_id: petId });
        return res.json({ favorited: true });
      }
    }

    const pool = getPool();
    const [existing] = await pool.query('SELECT id FROM favorites WHERE user_id = ? AND pet_id = ?', [userId, petId]);
    if (existing.length > 0) {
      await pool.query('DELETE FROM favorites WHERE user_id = ? AND pet_id = ?', [userId, petId]);
      return res.json({ favorited: false });
    } else {
      await pool.query('INSERT INTO favorites (user_id, pet_id) VALUES (?, ?)', [userId, petId]);
      return res.json({ favorited: true });
    }
  } catch (err) {
    res.status(500).json({ error: 'Failed to toggle favorite' });
  }
}

module.exports = {
  getPets,
  getPetById,
  createPet,
  updatePet,
  toggleFavorite
};
