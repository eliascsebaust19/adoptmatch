/**
 * AdoptMatch - Enterprise Role-Based Access Control (RBAC) & Token Invalidation Middleware
 * Enforces strict authorization policies, user session revocation, and fine-grained permissions.
 */

const jwt = require('jsonwebtoken');
const userStore = require('../models/userStore');
const { db } = require('../models/database');
const crypto = require('node:crypto');

const isBanned = (status) => String(status || '').toUpperCase() === 'BANNED';

if (process.env.NODE_ENV === 'production' && (process.env.JWT_SECRET || '').length < 32) {
  throw new Error('FATAL SECURITY ERROR: JWT_SECRET must contain at least 32 characters in production!');
}

const JWT_SECRET = process.env.JWT_SECRET || 'adoptmatch-dev-only-secret-2026';

// Durable token revocation registry
// Maps userId -> timestamp (ms) after which previous tokens are deemed invalidated
const metaGet = key => db.prepare('SELECT value FROM metadata WHERE key = ?').get(key)?.value;
const metaSet = (key, value) => db.prepare('INSERT INTO metadata(key,value) VALUES (?,?) ON CONFLICT(key) DO UPDATE SET value=excluded.value').run(key, String(value));

/**
 * Revokes all active JWT sessions and refresh tokens for a user immediately.
 * @param {string} userId
 */
const revokeUserTokens = (userId) => {
  // Strictly increase the cutoff even when actions occur in the same millisecond.
  const timestamp = Math.max(Date.now(), Number(metaGet(`revoked:${userId}`) || 0) + 1);
  metaSet(`revoked:${userId}`, timestamp);
  return timestamp;
};

/**
 * Clears revocation status for a user upon unblocking.
 * @param {string} userId
 */
const clearUserRevocation = (userId) => {
  // Unbanning never resurrects previously revoked sessions; a fresh login is required.
  metaSet(`revoked:${userId}`, Math.max(Date.now(), Number(metaGet(`revoked:${userId}`) || 0) + 1));
};

/**
 * Checks whether a given userId has an active revocation timestamp that postdates the token issue time.
 * @param {string} userId
 * @param {number} tokenIatSeconds
 */
const isUserRevoked = (userId, tokenIatSeconds) => {
  const cutoff = Number(metaGet(`revoked:${userId}`) || 0);
  return Boolean(cutoff && tokenIatSeconds * 1000 < cutoff);
};

/**
 * Blacklists a specific JWT token signature (e.g. upon user logout).
 * @param {string} token
 */
const blacklistToken = (token) => {
  try {
    const decoded = jwt.decode(token);
    const hash = crypto.createHash('sha256').update(token).digest('hex');
    metaSet(`logout:${hash}`, decoded?.exp || Math.floor(Date.now() / 1000) + 86400);
  } catch (_) {}
};

/**
 * Extracts and verifies JWT authorization token from request headers.
 * Attaches decoded user profile to req.user: { id, email, role, name, permissions }
 */
const authenticateToken = (req, res, next) => {
  const authHeader = req.headers['authorization'];
  const token = authHeader && authHeader.split(' ')[1]; // Format: Bearer <token>

  if (!token) {
    return res.status(401).json({
      success: false,
      error: 'Unauthorized',
      code: 'AUTH_TOKEN_MISSING',
      message: 'Access denied. No authentication token provided in Authorization header.',
    });
  }

  // 1. Check if token itself was blacklisted
  const tokenHash = crypto.createHash('sha256').update(token).digest('hex');
  if (metaGet(`logout:${tokenHash}`)) {
    return res.status(401).json({
      success: false,
      error: 'Unauthorized',
      code: 'TOKEN_BLACKLISTED',
      message: 'This session token has been logged out and blacklisted.',
    });
  }

  try {
    const decoded = jwt.verify(token, JWT_SECRET, { algorithms: ['HS256'] });
    const userId = decoded.id || decoded.sub;

    // 2. Check if user's sessions were revoked (e.g. user banned by admin)
    if (isUserRevoked(userId, decoded.iat)) {
      return res.status(401).json({
        success: false,
        error: 'Unauthorized',
        code: 'TOKEN_REVOKED',
        message: 'Your active sessions have been revoked by an administrator. Please log in again.',
      });
    }

    // 3. Re-read the authoritative account record so bans, role changes and
    //    permission changes take effect on the very next request.
    const account = userStore.findById(userId);
    if (!account) return res.status(401).json({ success: false, code: 'ACCOUNT_NOT_FOUND',
      error: 'The account for this session no longer exists.' });
    if (account && isBanned(account.status)) {
      return res.status(403).json({
        success: false,
        error: 'Forbidden',
        code: 'USER_BANNED',
        message: 'Your account has been suspended by an administrator. Please contact support.',
      });
    }

    req.user = {
      id: account ? account.id : userId,
      email: account ? account.email : decoded.email,
      role: String((account ? account.role : decoded.role) || 'USER').toUpperCase().trim(),
      name: (account ? account.name : decoded.name) || decoded.user_metadata?.full_name || 'User',
      permissions: Array.isArray(account ? account.permissions : decoded.permissions)
        ? (account ? account.permissions : decoded.permissions)
        : [],
    };
    next();
  } catch (err) {
    return res.status(401).json({
      success: false,
      error: 'Unauthorized',
      code: 'AUTH_TOKEN_INVALID',
      message: 'Invalid or expired session token. Please re-authenticate.',
      details: err.message,
    });
  }
};

/**
 * Higher-Order RBAC Middleware generator.
 * Strictly verifies that req.user.role matches one of the specified allowedRoles.
 * 
 * @param {Array<string>} allowedRoles - e.g. ['ADMIN', 'SUPER_ADMIN']
 */
const requireRole = (allowedRoles) => {
  if (!Array.isArray(allowedRoles) || allowedRoles.length === 0) {
    throw new Error('requireRole middleware requires a non-empty array of allowed roles.');
  }

  const normalizedAllowedRoles = allowedRoles.map((r) => r.toUpperCase().trim());

  return (req, res, next) => {
    // 1. Ensure user has passed authentication first
    if (!req.user || !req.user.role) {
      return res.status(401).json({
        success: false,
        error: 'Unauthorized',
        code: 'UNAUTHENTICATED_SESSION',
        message: 'Authentication is required before role evaluation.',
      });
    }

    const userRole = req.user.role.toUpperCase().trim();

    // 2. Check role authorization
    if (!normalizedAllowedRoles.includes(userRole)) {
      console.warn(`[SECURITY AUDIT] Unauthorized access attempt by user "${req.user.email}" (Role: ${userRole}) to path "${req.originalUrl}". Required: [${normalizedAllowedRoles.join(', ')}]`);

      return res.status(403).json({
        success: false,
        error: 'Forbidden',
        code: 'INSUFFICIENT_PERMISSIONS',
        message: 'Access Denied: You do not have the required administrative privileges to perform this operation.',
        requiredRoles: normalizedAllowedRoles,
        currentRole: userRole,
      });
    }

    // Role authorized, continue to controller
    next();
  };
};

/**
 * Fine-Grained Permissions Middleware.
 * Allows access if req.user has the specified permission OR is ADMIN / SUPER_ADMIN.
 * 
 * @param {string|Array<string>} requiredPermissions - e.g. 'APPROVE_PETS' or ['APPROVE_PETS', 'FLAG_CONTENT']
 */
const requirePermission = (requiredPermissions) => {
  const perms = Array.isArray(requiredPermissions) ? requiredPermissions : [requiredPermissions];

  return (req, res, next) => {
    if (!req.user) {
      return res.status(401).json({ success: false, code: 'UNAUTHENTICATED' });
    }

    // Super Admin and Admin bypass granular permission checks
    if (req.user.role === 'SUPER_ADMIN' || req.user.role === 'ADMIN') {
      return next();
    }

    // Check if user has at least one of the required permissions
    const userPerms = req.user.permissions || [];
    const hasPermission = perms.some((p) => userPerms.includes(p));

    if (!hasPermission) {
      return res.status(403).json({
        success: false,
        error: 'Forbidden',
        code: 'PERMISSION_DENIED',
        message: `Missing required moderation permission: [${perms.join(', ')}]`,
        requiredPermissions: perms,
        userPermissions: userPerms,
      });
    }

    next();
  };
};

const requireAdmin = requireRole(['ADMIN', 'SUPER_ADMIN']);
const requireSuperAdmin = requireRole(['SUPER_ADMIN']);

module.exports = {
  authenticateToken,
  requireRole,
  requirePermission,
  requireAdmin,
  requireSuperAdmin,
  revokeUserTokens,
  clearUserRevocation,
  isUserRevoked,
  blacklistToken,
  JWT_SECRET,
};
