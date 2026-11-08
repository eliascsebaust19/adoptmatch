/**
 * AdoptMatch - Enterprise Node.js Express REST API
 * Mounts RBAC-protected administrative endpoints and storage upload handlers.
 */

require('dotenv').config({ path: require('path').join(__dirname, '.env') });
const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const jwt = require('jsonwebtoken');
const crypto = require('node:crypto');
const userStore = require('./models/userStore');

const adminRoutes = require('./routes/adminRoutes');
const authRoutes = require('./routes/authRoutes');
const paymentRoutes = require('./routes/paymentRoutes');
const { JWT_SECRET, authenticateToken } = require('./middleware/rbacMiddleware');

const MAX_UPLOAD_BYTES = 5 * 1024 * 1024; // 5 MB decoded
const ALLOWED_IMAGE_TYPES = {
  'image/jpeg': (b) => b.length > 3 && b[0] === 0xff && b[1] === 0xd8 && b[2] === 0xff,
  'image/png': (b) => b.length > 8 && b.subarray(0, 8).equals(Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a])),
  'image/webp': (b) => b.length > 12 && b.subarray(0, 4).toString('ascii') === 'RIFF' && b.subarray(8, 12).toString('ascii') === 'WEBP',
  'image/gif': (b) => b.length > 6 && ['GIF87a', 'GIF89a'].includes(b.subarray(0, 6).toString('ascii')),
};

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
 * Test Auth Token Generator (Disabled in production; restricted to non-admin roles in development)
 * POST /api/v1/auth/token
 */
app.post('/api/v1/auth/token', (req, res) => {
  if (process.env.NODE_ENV === 'production') {
    return res.status(403).json({
      success: false,
      error: 'Forbidden: Test token generation endpoint is permanently disabled in production builds.',
    });
  }

  const { email = 'dev@adoptmatch.org', role = 'USER', name = 'Test User', testSecret } = req.body;

  // Every minted token requires the shared test secret, not just privileged roles.
  const expectedSecret = process.env.TEST_AUTH_SECRET;
  if (!expectedSecret || testSecret !== expectedSecret) {
    return res.status(403).json({
      success: false,
      error: 'Forbidden: Test token generation requires a valid testSecret and TEST_AUTH_SECRET configured on the server.',
    });
  }

  const validRoles = ['USER', 'SHELTER', 'FOSTER'];
  const privilegedRoles = ['ADMIN', 'SUPER_ADMIN'];
  const normalizedRole = String(role).toUpperCase().trim();

  if (![...validRoles, ...privilegedRoles].includes(normalizedRole)) {
    return res.status(400).json({
      success: false,
      error: 'Invalid role',
      validRoles: [...validRoles, ...privilegedRoles],
    });
  }

  // Test identities are isolated: knowing a real email never grants its account.
  const account = userStore.createUser({ id: `test-${crypto.randomUUID()}`, email: `${crypto.randomUUID()}@test.invalid`,
    role: normalizedRole, name, provider: 'test', emailVerified: false });
  const payload = { id: account.id, email: account.email, role: account.role, name: account.name };

  const token = jwt.sign(payload, JWT_SECRET, { expiresIn: '24h' });

  res.json({
    success: true,
    message: `Generated test JWT token for role "${normalizedRole}"`,
    role: normalizedRole,
    token,
  });
});

/**
 * Unified Storage Upload Endpoint (Vercel Blob & Supabase Compatible)
 * POST /api/v1/storage/upload
 * Body: { filename: 'avatar.jpg', base64Data: '...', contentType: 'image/jpeg', userId: '...' }
 */
app.post('/api/v1/storage/upload', authenticateToken, async (req, res) => {
  try {
    const { filename = `avatar-${Date.now()}.jpg`, base64Data, contentType = 'image/jpeg' } = req.body;

    if (typeof base64Data !== 'string' || base64Data.length === 0) {
      return res.status(400).json({ success: false, error: 'base64Data is required' });
    }

    const declaredType = String(contentType).toLowerCase();
    const matchesSignature = ALLOWED_IMAGE_TYPES[declaredType];
    if (!matchesSignature) {
      return res.status(415).json({
        success: false,
        error: `Unsupported content type "${declaredType}". Allowed: ${Object.keys(ALLOWED_IMAGE_TYPES).join(', ')}`,
      });
    }

    const cleanBase64 = base64Data.replace(/^data:image\/\w+;base64,/, '');
    const buffer = Buffer.from(cleanBase64, 'base64');

    if (buffer.length === 0) {
      return res.status(400).json({ success: false, error: 'Decoded file is empty' });
    }
    if (buffer.length > MAX_UPLOAD_BYTES) {
      return res.status(413).json({
        success: false,
        error: `File exceeds the ${MAX_UPLOAD_BYTES / (1024 * 1024)} MB limit`,
      });
    }
    if (!matchesSignature(buffer)) {
      return res.status(415).json({
        success: false,
        error: 'File contents do not match the declared image type',
      });
    }

    // The storage path is derived from the authenticated caller, never the request body.
    const sanitizedFilename = `avatars/${req.user.id}-${Date.now()}-${String(filename).replace(/[^a-zA-Z0-9.-]/g, '_')}`;

    // 1. If Vercel Blob Token is set (BLOB_READ_WRITE_TOKEN in environment)
    if (process.env.BLOB_READ_WRITE_TOKEN) {
      try {
        const { put } = require('@vercel/blob');
        let blob;
        try {
          blob = await put(sanitizedFilename, buffer, {
            access: 'public',
            contentType: declaredType,
          });
        } catch (accessErr) {
          if (accessErr.message && accessErr.message.includes('private store')) {
            blob = await put(sanitizedFilename, buffer, {
              access: 'private',
              contentType: declaredType,
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

    // 2. Fallback: If Supabase Service Key is configured, perform actual storage upload
    if (process.env.SUPABASE_URL && process.env.SUPABASE_SERVICE_ROLE_KEY) {
      try {
        const { createClient } = require('@supabase/supabase-js');
        const supabase = createClient(process.env.SUPABASE_URL, process.env.SUPABASE_SERVICE_ROLE_KEY);
        const { data, error } = await supabase.storage.from('avatars').upload(sanitizedFilename, buffer, {
          contentType: declaredType,
          upsert: true,
        });
        if (error) throw error;

        const { data: urlData } = supabase.storage.from('avatars').getPublicUrl(sanitizedFilename);
        return res.json({
          success: true,
          provider: 'supabase-storage',
          url: urlData.publicUrl,
          sanitizedFilename,
          bytes: buffer.length,
        });
      } catch (sbErr) {
        console.warn('[STORAGE] Supabase upload failed:', sbErr.message);
      }
    }

    // Fail closed: Do not fabricate a successful URL without actually storing bytes
    return res.status(503).json({
      success: false,
      error: 'Storage service unavailable: Neither Vercel Blob nor Supabase Storage could persist the file.',
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
