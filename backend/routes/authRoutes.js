/**
 * AdoptMatch - Enterprise Authentication Routes
 * Implements Google OAuth verification, Account Linking, JWT Issuance,
 * User Session Management, and Me/Logout Endpoints.
 */

const express = require('express');
const router = express.Router();
const jwt = require('jsonwebtoken');
const { OAuth2Client } = require('google-auth-library');
const https = require('https');

const {
  findByEmail,
  findByGoogleId,
  findById,
  createUser,
  updateUser,
} = require('../models/userStore');

const {
  authenticateToken,
  blacklistToken,
  JWT_SECRET,
} = require('../middleware/rbacMiddleware');

// One audience allow-list for every environment. A dev-only default silently
// mismatched the Flutter Web client ID and produced unverifiable tokens.
// GOOGLE_CLIENT_ID must be the same Web client ID the app uses as serverClientId;
// GOOGLE_CLIENT_IDS may add further platform audiences (comma separated).
const getGoogleClientIds = () => [
  process.env.GOOGLE_CLIENT_ID,
  ...(process.env.GOOGLE_CLIENT_IDS || '').split(','),
].map((v) => (v || '').trim()).filter(Boolean);
const getGoogleClientId = () => getGoogleClientIds()[0] || '';
const googleClient = new OAuth2Client();

/**
 * Helper to verify Google ID token with Google Cloud OAuth2
 * Falls back to Google tokeninfo HTTP endpoint if library encounters local config quirks.
 */
async function verifyGoogleToken(idToken) {
  const allowedAudiences = getGoogleClientIds();
  try {
    const ticket = await googleClient.verifyIdToken({
      idToken,
      audience: allowedAudiences,
    });
    const payload = ticket.getPayload();
    const issuerOk = ['accounts.google.com', 'https://accounts.google.com'].includes(payload.iss);
    if (!issuerOk || !payload.sub || !payload.exp || payload.exp * 1000 <= Date.now()) {
      throw new Error('Google token issuer, subject or expiry is invalid.');
    }
    if (!payload.email_verified) {
      throw new Error('Google account email is not verified.');
    }
    return payload;
  } catch (libErr) {
    // Fallback: Verify directly against Google's public tokeninfo endpoint
    return new Promise((resolve, reject) => {
      const url = `https://oauth2.googleapis.com/tokeninfo?id_token=${encodeURIComponent(idToken)}`;
      https.get(url, (res) => {
        let raw = '';
        res.on('data', (chunk) => (raw += chunk));
        res.on('end', () => {
          try {
            const data = JSON.parse(raw);
            if (data.error_description || data.error) {
              return reject(new Error(data.error_description || data.error));
            }
            // Cryptographic audience and verification checks
            if (!allowedAudiences.includes(data.aud)) {
              return reject(new Error(`Invalid token audience: ${data.aud}. Expected one of ${allowedAudiences.join(', ')}`));
            }
            if (!['accounts.google.com', 'https://accounts.google.com'].includes(data.iss) ||
                !data.sub || !data.exp || Number(data.exp) * 1000 <= Date.now()) {
              return reject(new Error('Google token issuer, subject or expiry is invalid.'));
            }
            if (data.email_verified !== 'true' && data.email_verified !== true) {
              return reject(new Error('Google email is not verified.'));
            }
            if (!data.email) {
              return reject(new Error('Google token does not contain a valid email.'));
            }
            resolve(data);
          } catch (e) {
            reject(new Error(`Failed to parse Google tokeninfo response: ${e.message}`));
          }
        });
      }).on('error', (err) => {
        reject(err);
      });
    });
  }
}

/**
 * Helper to generate JWT access & refresh tokens
 */
function generateTokens(user) {
  const payload = {
    id: user.id,
    sub: user.id,
    email: user.email,
    role: user.role,
    name: user.name,
    avatarUrl: user.avatarUrl,
    permissions: user.permissions || [],
  };

  const accessToken = jwt.sign(payload, JWT_SECRET, { expiresIn: '7d' });
  const refreshToken = jwt.sign({ id: user.id, type: 'refresh' }, JWT_SECRET, { expiresIn: '30d' });

  return { accessToken, refreshToken, expiresIn: '7d' };
}

/**
 * POST /api/v1/auth/google
 * Receives Google credentials (idToken or profile data)
 * Handles token verification, auto-signup, account linking, and JWT issuance.
 */
router.post('/google', async (req, res) => {
  try {
    const idToken = req.body.idToken || req.body.id_token;
    if (!getGoogleClientId()) {
      return res.status(503).json({ success: false, code: 'GOOGLE_AUTH_NOT_CONFIGURED',
        error: 'Google sign-in is not configured on this server.' });
    }
    if (!idToken) {
      return res.status(400).json({
        success: false,
        error: 'Bad Request',
        code: 'MISSING_GOOGLE_CREDENTIALS',
        message: 'A cryptographically valid Google idToken is required for authentication.',
      });
    }

    let googlePayload = null;
    try {
      googlePayload = await verifyGoogleToken(idToken);
    } catch (err) {
      console.warn('[AUTH] Google idToken verification failed:', err.message);
      return res.status(401).json({
        success: false,
        error: 'Unauthorized',
        code: 'INVALID_GOOGLE_TOKEN',
        message: `Google ID token could not be verified: ${err.message}`,
      });
    }

    if (!googlePayload || !googlePayload.email) {
      return res.status(400).json({
        success: false,
        error: 'Bad Request',
        code: 'MISSING_EMAIL_IN_TOKEN',
        message: 'Could not obtain a valid email from the Google account.',
      });
    }

    const googleId = googlePayload.sub;
    const email = googlePayload.email.toLowerCase().trim();
    const name = googlePayload.name || email.split('@')[0];
    const picture = googlePayload.picture || '';

    // Step 1: Check if user already exists by googleId
    let user = findByGoogleId(googleId);

    if (user) {
      // Existing Google user -> Update last login time and refresh profile photo if needed
      user = updateUser(user.id, {
        lastLoginAt: new Date().toISOString(),
        name: name || user.name,
        avatarUrl: picture || user.avatarUrl,
        emailVerified: true,
      });
    } else {
      // Step 2: Check if user exists with the same email (e.g. from standard signup) -> Account Linking
      const existingUserByEmail = findByEmail(email);

      if (existingUserByEmail) {
        if (['ADMIN', 'SUPER_ADMIN', 'MODERATOR'].includes(existingUserByEmail.role) ||
            (existingUserByEmail.googleId && existingUserByEmail.googleId !== googleId)) {
          return res.status(409).json({ success: false, code: 'ACCOUNT_LINKING_DENIED',
            error: 'This account cannot be linked automatically. Contact support.' });
        }
        // Only ordinary, previously unlinked accounts may link by verified email.
        console.log(`[AUTH] Linking Google account (${googleId}) to existing user: ${existingUserByEmail.email}`);
        user = updateUser(existingUserByEmail.id, {
          googleId,
          provider: 'google',
          avatarUrl: existingUserByEmail.avatarUrl || picture,
          emailVerified: true,
          lastLoginAt: new Date().toISOString(),
        });
      } else {
        // Step 3: First-time signup via Google
        console.log(`[AUTH] Creating new user for Google login: ${email}`);
        user = createUser({
          name,
          email,
          googleId,
          avatarUrl: picture,
          provider: 'google',
          emailVerified: true,
          role: 'USER',
          status: 'Active',
          permissions: [],
        });
      }
    }

    // Check if user has been banned
    if (String(user.status || '').toUpperCase() === 'BANNED') {
      return res.status(403).json({
        success: false,
        error: 'Forbidden',
        code: 'USER_BANNED',
        message: 'Your account has been suspended by an administrator. Please contact support.',
      });
    }

    // Step 4: Issue JWT Access & Refresh Tokens
    const tokens = generateTokens(user);

    return res.status(200).json({
      success: true,
      message: 'Google authentication successful',
      user: {
        id: user.id,
        name: user.name,
        email: user.email,
        phone: user.phone,
        role: user.role,
        status: user.status,
        avatarUrl: user.avatarUrl,
        provider: user.provider,
        permissions: user.permissions || [],
        preferredPetType: user.preferredPetType || 'All Pets',
        location: user.location,
        bio: user.bio,
      },
      tokens: {
        accessToken: tokens.accessToken,
        refreshToken: tokens.refreshToken,
        expiresIn: tokens.expiresIn,
      },
    });
  } catch (error) {
    console.error('[AUTH ERROR] Google login exception:', error);
    return res.status(500).json({
      success: false,
      error: 'Internal Server Error',
      message: error.message || 'An unexpected error occurred during Google authentication.',
    });
  }
});

/**
 * GET /api/v1/auth/me
 * Returns current authenticated user profile
 */
router.get('/me', authenticateToken, (req, res) => {
  const user = findById(req.user.id) || findByEmail(req.user.email);

  if (!user) {
    return res.status(404).json({
      success: false,
      error: 'Not Found',
      code: 'USER_NOT_FOUND',
      message: 'The requested user profile was not found.',
    });
  }

  return res.json({
    success: true,
    user: {
      id: user.id,
      name: user.name,
      email: user.email,
      phone: user.phone,
      role: user.role,
      status: user.status,
      avatarUrl: user.avatarUrl,
      provider: user.provider,
      permissions: user.permissions || [],
      preferredPetType: user.preferredPetType,
      location: user.location,
      bio: user.bio,
      joinedAt: user.joinedAt,
      lastLoginAt: user.lastLoginAt,
    },
  });
});

/**
 * POST /api/v1/auth/logout
 * Invalidates the current user's session token
 */
router.post('/logout', authenticateToken, (req, res) => {
  const authHeader = req.headers['authorization'];
  const token = authHeader && authHeader.split(' ')[1];

  if (token) {
    blacklistToken(token);
  }

  return res.json({
    success: true,
    message: 'User logged out and session revoked successfully.',
  });
});

module.exports = router;

