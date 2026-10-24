const express = require('express');
const cors = require('cors');
const dotenv = require('dotenv');
const { initDB } = require('./config/db');

dotenv.config({ path: '../.env' });
dotenv.config();

const app = express();
const PORT = process.env.PORT || 5000;

// Middleware
app.use(cors({
  origin: '*',
  credentials: true
}));
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true }));

// Health Check
app.get('/', (req, res) => {
  res.json({
    service: 'AdoptMatch Express API Server',
    status: 'online',
    version: '1.0.0'
  });
});

app.get('/api/health', (req, res) => {
  res.json({ status: 'healthy', timestamp: new Date().toISOString() });
});

// Import Routes
const authRoutes = require('./routes/auth.routes');
const petRoutes = require('./routes/pet.routes');
const matchingRoutes = require('./routes/matching.routes');
const applicationRoutes = require('./routes/application.routes');
const fosterRoutes = require('./routes/foster.routes');
const medicalRoutes = require('./routes/medical.routes');
const postAdoptionRoutes = require('./routes/postAdoption.routes');
const analyticsRoutes = require('./routes/analytics.routes');

// Register API Routes
app.use('/api/auth', authRoutes);
app.use('/api/pets', petRoutes);
app.use('/api/matching', matchingRoutes);
app.use('/api/applications', applicationRoutes);
app.use('/api/fosters', fosterRoutes);
app.use('/api/medical', medicalRoutes);
app.use('/api/post-adoption', postAdoptionRoutes);
app.use('/api/analytics', analyticsRoutes);

// Global Error Handler
app.use((err, req, res, next) => {
  console.error('Unhandled Global Server Error:', err);
  res.status(err.status || 500).json({
    error: err.message || 'Internal Server Error',
    code: err.code || 'INTERNAL_ERROR'
  });
});

// Start Server & Init DB
async function startServer() {
  await initDB();
  app.listen(PORT, () => {
    console.log(`🚀 AdoptMatch Node Server running on http://localhost:${PORT}`);
  });
}

startServer();
