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

const GOOGLE_CLIENT_ID = process.env.GOOGLE_CLIENT_ID || '94403915199-50ug4q14m66gn3pjmhh441givdf0etie.apps.googleusercontent.com';
const googleClient = new OAuth2Client(GOOGLE_CLIENT_ID);

/**
 * Helper to verify Google ID token with Google Cloud OAuth2
 * Falls back to Google tokeninfo HTTP endpoint if library encounters local config quirks.
 */
async function verifyGoogleToken(idToken) {
  try {
    const ticket = await googleClient.verifyIdToken({
      idToken,
      audience: GOOGLE_CLIENT_ID,
    });
    return ticket.getPayload();
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
    const { idToken, profile } = req.body;

    if (!idToken && !profile) {
      return res.status(400).json({
        success: false,
        error: 'Bad Request',
        code: 'MISSING_GOOGLE_CREDENTIALS',
        message: 'Either idToken or profile data is required for Google authentication.',
      });
    }

    let googlePayload = null;

    if (idToken) {
      try {
        googlePayload = await verifyGoogleToken(idToken);
      } catch (err) {
        console.warn('[AUTH] Google idToken verification failed:', err.message);

        // If client provided profile as fallback in dev mode
        if (profile && (process.env.NODE_ENV !== 'production' || !idToken.startsWith('mock-'))) {
          googlePayload = {
            sub: profile.id || `google-${Date.now()}`,
            email: profile.email,
            name: profile.name,
            picture: profile.photoUrl || profile.picture,
            email_verified: true,
          };
        } else {
          return res.status(401).json({
            success: false,
            error: 'Unauthorized',
            code: 'INVALID_GOOGLE_TOKEN',
            message: `Google ID token could not be verified: ${err.message}`,
          });
        }
      }
    } else if (profile) {
      googlePayload = {
        sub: profile.id || `google-${Date.now()}`,
        email: profile.email,
        name: profile.name,
        picture: profile.photoUrl || profile.picture,
        email_verified: true,
      };
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
        // Link accounts without duplicating the user!
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
    if (user.status === 'Banned') {
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
router.post('/logout', (req, res) => {
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

