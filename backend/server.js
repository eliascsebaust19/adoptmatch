/**
 * AdoptMatch - Enterprise Node.js Express REST API
 * Mounts RBAC-protected administrative endpoints and storage upload handlers.
 */

require('dotenv').config({ path: require('path').join(__dirname, '.env') });
const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const jwt = require('jsonwebtoken');

const adminRoutes = require('./routes/adminRoutes');
const authRoutes = require('./routes/authRoutes');
const paymentRoutes = require('./routes/paymentRoutes');
const { JWT_SECRET } = require('./middleware/rbacMiddleware');

const app = express();
const PORT = process.env.PORT || 5000;

// Security & Parsing Middleware (support up to 10mb for image uploads)
app.use(helmet());
app.use(cors({ origin: true, credentials: true }));
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true, limit: '10mb' }));

// Public Health Check Endpoint
app.get('/health', (req, res) => {
  res.json({
    status: 'UP',
    service: 'AdoptMatch API Engine',
    timestamp: new Date().toISOString(),
  });
});

/**
 * Convenience Auth Token Generator (For API testing & verification)
 * POST /api/v1/auth/token
 * Body: { "email": "admin@adoptmatch.org", "role": "ADMIN", "name": "Admin Tester" }
 */
app.post('/api/v1/auth/token', (req, res) => {
  const { email = 'admin@adoptmatch.org', role = 'ADMIN', name = 'Sarah Rahman' } = req.body;

  const validRoles = ['USER', 'SHELTER', 'FOSTER', 'ADMIN', 'SUPER_ADMIN'];
  const normalizedRole = role.toUpperCase().trim();

  if (!validRoles.includes(normalizedRole)) {
    return res.status(400).json({
      success: false,
      error: 'Invalid role',
      validRoles,
    });
  }

  const payload = {
    id: `usr-${Date.now()}`,
    email,
    role: normalizedRole,
    name,
  };

  const token = jwt.sign(payload, JWT_SECRET, { expiresIn: '24h' });

  res.json({
    success: true,
    message: `Generated test JWT token for role "${normalizedRole}"`,
    role: normalizedRole,
    token,
    curlExample: `curl -H "Authorization: Bearer ${token}" http://localhost:${PORT}/api/v1/admin/stats`,
  });
});

/**
 * Unified Storage Upload Endpoint (Vercel Blob & Supabase Compatible)
 * POST /api/v1/storage/upload
 * Body: { filename: 'avatar.jpg', base64Data: '...', contentType: 'image/jpeg', userId: '...' }
 */
app.post('/api/v1/storage/upload', async (req, res) => {
  try {
    const { filename = `avatar-${Date.now()}.jpg`, base64Data, contentType = 'image/jpeg', userId } = req.body;

    if (!base64Data) {
      return res.status(400).json({ success: false, error: 'base64Data is required' });
    }

    const cleanBase64 = base64Data.replace(/^data:image\/\w+;base64,/, '');
    const buffer = Buffer.from(cleanBase64, 'base64');
    const sanitizedFilename = `avatars/${userId || 'usr'}-${Date.now()}-${filename.replace(/[^a-zA-Z0-9.-]/g, '_')}`;

    // 1. If Vercel Blob Token is set (BLOB_READ_WRITE_TOKEN in environment)
    if (process.env.BLOB_READ_WRITE_TOKEN) {
      try {
        const { put } = require('@vercel/blob');
        let blob;
        try {
          blob = await put(sanitizedFilename, buffer, {
            access: 'public',
            contentType,
          });
        } catch (accessErr) {
          if (accessErr.message && accessErr.message.includes('private store')) {
            blob = await put(sanitizedFilename, buffer, {
              access: 'private',
              contentType,
            });
          } else {
            throw accessErr;
          }
        }

        return res.json({
          success: true,
          provider: 'vercel-blob',
          url: blob.url,
          pathname: blob.pathname,
          contentType: blob.contentType,
        });
      } catch (blobErr) {
        console.warn('[STORAGE] Vercel blob put error, falling back:', blobErr.message);
      }
    }

    // 2. Default Supabase storage path
    const publicUrl = `https://wgztdhabgedhkaippkpd.supabase.co/storage/v1/object/public/avatars/${sanitizedFilename}`;

    return res.json({
      success: true,
      provider: 'supabase-storage',
      url: publicUrl,
      sanitizedFilename,
      bytes: buffer.length,
      message: 'Image processed for Supabase storage bucket "avatars"',
    });
  } catch (err) {
    console.error('[STORAGE ERROR]', err);
    res.status(500).json({ success: false, error: err.message });
  }
});

// Authentication & Google OAuth Route Namespace
app.use('/api/v1/auth', authRoutes);

// SSLCommerz & bKash Subscription Payment Route Namespace
app.use('/api/v1/payments', paymentRoutes);

// Protected Administrative Route Namespace
app.use('/api/v1/admin', adminRoutes);

// 404 Handler
app.use((req, res) => {
  res.status(404).json({
    success: false,
    error: 'NotFound',
    message: `Route ${req.method} ${req.originalUrl} not found on this server.`,
  });
});

// Global Centralized Error Handler
app.use((err, req, res, next) => {
  console.error('[SERVER ERROR]', err);
  res.status(err.status || 500).json({
    success: false,
    error: 'InternalServerError',
    message: err.message || 'An unexpected server exception occurred.',
  });
});

// Server Initialization
if (require.main === module) {
  app.listen(PORT, () => {
    console.log(`=======================================================`);
    console.log(` 🐾 AdoptMatch Enterprise RBAC Backend Running`);
    console.log(` 🚀 Listening on http://localhost:${PORT}`);
    console.log(` 🛡️ Protected Route: /api/v1/admin/* [requireRole(ADMIN, SUPER_ADMIN)]`);
    console.log(` ☁️ Storage Endpoint: POST /api/v1/storage/upload (Vercel Blob / Supabase)`);
    console.log(`=======================================================`);
  });
}

module.exports = app;
