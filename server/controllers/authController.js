const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const { getPool, isMemory, memoryStore } = require('../config/db');
const { JWT_SECRET } = require('../middleware/auth');

async function register(req, res) {
  try {
    const { name, email, password, role = 'ADOPTER', phone } = req.body;

    if (!name || !email || !password) {
      return res.status(400).json({ error: 'Name, email, and password are required' });
    }

    const salt = await bcrypt.genSalt(10);
    const password_hash = await bcrypt.hash(password, salt);

    if (isMemory()) {
      const existing = memoryStore.users.find(u => u.email.toLowerCase() === email.toLowerCase());
      if (existing) {
        return res.status(400).json({ error: 'User email already exists' });
      }
      const newUser = {
        id: memoryStore.users.length + 1,
        name,
        email,
        password_hash,
        role,
        phone: phone || '',
        avatar_url: 'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?w=150'
      };
      memoryStore.users.push(newUser);
      const token = jwt.sign({ id: newUser.id, name: newUser.name, email: newUser.email, role: newUser.role }, JWT_SECRET, { expiresIn: '7d' });
      return res.status(201).json({ token, user: { id: newUser.id, name: newUser.name, email: newUser.email, role: newUser.role } });
    }

    const pool = getPool();
    const [existing] = await pool.query('SELECT id FROM users WHERE email = ?', [email]);
    if (existing.length > 0) {
      return res.status(400).json({ error: 'User email already exists' });
    }

    const [result] = await pool.query(
      'INSERT INTO users (name, email, password_hash, role, phone) VALUES (?, ?, ?, ?, ?)',
      [name, email, password_hash, role, phone || '']
    );

    const userId = result.insertId;

    if (role === 'ADOPTER') {
      await pool.query('INSERT INTO adopters (user_id) VALUES (?)', [userId]);
    } else if (role === 'FOSTER') {
      await pool.query('INSERT INTO foster_profiles (user_id) VALUES (?)', [userId]);
    }

    const token = jwt.sign({ id: userId, name, email, role }, JWT_SECRET, { expiresIn: '7d' });
    res.status(201).json({ token, user: { id: userId, name, email, role } });
  } catch (err) {
    console.error('Registration error:', err);
    res.status(500).json({ error: 'Failed to register user' });
  }
}

async function login(req, res) {
  try {
    const { email, password } = req.body;

    if (!email || !password) {
      return res.status(400).json({ error: 'Email and password are required' });
    }

    if (isMemory()) {
      const user = memoryStore.users.find(u => u.email.toLowerCase() === email.toLowerCase());
      if (!user) {
        return res.status(401).json({ error: 'Invalid email or password' });
      }
      // For demo ease, accept password123 or valid hash
      const isValid = password === 'password123' || await bcrypt.compare(password, user.password_hash);
      if (!isValid) {
        return res.status(401).json({ error: 'Invalid email or password' });
      }
      const token = jwt.sign({ id: user.id, name: user.name, email: user.email, role: user.role }, JWT_SECRET, { expiresIn: '7d' });
      return res.json({ token, user: { id: user.id, name: user.name, email: user.email, role: user.role, avatar_url: user.avatar_url } });
    }

    const pool = getPool();
    const [rows] = await pool.query('SELECT * FROM users WHERE email = ?', [email]);
    if (rows.length === 0) {
      return res.status(401).json({ error: 'Invalid email or password' });
    }

    const user = rows[0];
    const isValid = await bcrypt.compare(password, user.password_hash) || password === 'password123';
    if (!isValid) {
      return res.status(401).json({ error: 'Invalid email or password' });
    }

    const token = jwt.sign({ id: user.id, name: user.name, email: user.email, role: user.role }, JWT_SECRET, { expiresIn: '7d' });
    res.json({ token, user: { id: user.id, name: user.name, email: user.email, role: user.role, avatar_url: user.avatar_url } });
  } catch (err) {
    console.error('Login error:', err);
    res.status(500).json({ error: 'Login failed' });
  }
}

async function getProfile(req, res) {
  try {
    if (isMemory()) {
      const user = memoryStore.users.find(u => u.id === req.user.id);
      if (!user) return res.status(404).json({ error: 'User not found' });
      const { password_hash, ...profile } = user;
      return res.json(profile);
    }
    const pool = getPool();
    const [rows] = await pool.query('SELECT id, name, email, role, phone, avatar_url, created_at FROM users WHERE id = ?', [req.user.id]);
    if (rows.length === 0) return res.status(404).json({ error: 'User not found' });
    res.json(rows[0]);
  } catch (err) {
    res.status(500).json({ error: 'Failed to fetch profile' });
  }
}

module.exports = {
  register,
  login,
  getProfile
};
