/**
 * AdoptMatch - Enterprise User Data Store
 * SQLite-backed unified user persistence with Google OAuth linking support.
 */

const demoUsers = [
  {
    id: 'u-101',
    name: 'Elias Ahmed',
    email: 'elias3224@gmail.com',
    phone: '+880 1711 234567',
    role: 'USER',
    status: 'Active',
    avatarUrl: '',
    googleId: null,
    provider: 'local',
    emailVerified: true,
    permissions: [],
    adoptionsCount: 1,
    joinedAt: '2026-06-15T00:00:00.000Z',
    lastLoginAt: '2026-10-28T18:00:00.000Z',
  },
  {
    id: 'u-102',
    name: 'Care For Paws Staff',
    email: 'info@careforpaws.bd',
    phone: '+880 1712 345678',
    role: 'SHELTER',
    status: 'Active',
    avatarUrl: '',
    googleId: null,
    provider: 'local',
    emailVerified: true,
    permissions: ['APPROVE_PETS'],
    adoptionsCount: 38,
    joinedAt: '2026-01-10T00:00:00.000Z',
    lastLoginAt: '2026-10-27T10:00:00.000Z',
  },
  {
    id: 'u-103',
    name: 'Sarah Rahman',
    email: 'superadmin@adoptmatch.org',
    phone: '+880 1819 000001',
    role: 'SUPER_ADMIN',
    status: 'Active',
    avatarUrl: '',
    googleId: null,
    provider: 'local',
    emailVerified: true,
    permissions: ['APPROVE_PETS', 'FLAG_CONTENT', 'REVIEW_APPLICATIONS', 'MANAGE_USERS', 'AUDIT_LOGS'],
    adoptionsCount: 0,
    joinedAt: '2025-08-01T00:00:00.000Z',
    lastLoginAt: '2026-10-28T17:50:00.000Z',
  },
  {
    id: 'u-103b',
    name: 'Kamrul Hasan (System Admin)',
    email: 'admin@adoptmatch.com',
    phone: '+880 1819 000002',
    role: 'ADMIN',
    status: 'Active',
    avatarUrl: '',
    googleId: null,
    provider: 'local',
    emailVerified: true,
    permissions: ['APPROVE_PETS', 'FLAG_CONTENT', 'REVIEW_APPLICATIONS', 'MANAGE_USERS'],
    adoptionsCount: 0,
    joinedAt: '2025-09-01T00:00:00.000Z',
    lastLoginAt: '2026-10-29T10:00:00.000Z',
  },
  {
    id: 'u-104',
    name: 'Suspicious Lister 99',
    email: 'petshopdhaka@fake.com',
    phone: '+880 1911 000099',
    role: 'USER',
    status: 'Banned',
    avatarUrl: '',
    googleId: null,
    provider: 'local',
    emailVerified: false,
    permissions: [],
    adoptionsCount: 0,
    joinedAt: '2026-10-14T00:00:00.000Z',
    lastLoginAt: '2026-10-14T00:00:00.000Z',
  },
  {
    id: 'u-105',
    name: 'Tanvir Hossain (Volunteer Lead)',
    email: 'tanvir.mod@adoptmatch.org',
    phone: '+880 1713 999888',
    role: 'MODERATOR',
    status: 'Active',
    avatarUrl: '',
    googleId: null,
    provider: 'local',
    emailVerified: true,
    permissions: ['APPROVE_PETS', 'FLAG_CONTENT', 'REVIEW_APPLICATIONS'],
    adoptionsCount: 4,
    joinedAt: '2026-03-20T00:00:00.000Z',
    lastLoginAt: '2026-10-28T12:00:00.000Z',
  },
];

const store = require('./recordStore')('users', process.env.NODE_ENV === 'production' ? [] : demoUsers);
const getAllUsers = () => store.all();
const findByEmail = (email) => !email ? null : getAllUsers().find(u => u.email.toLowerCase().trim() === String(email).toLowerCase().trim()) || null;
const findByGoogleId = (googleId) => !googleId ? null : getAllUsers().find(u => u.googleId === googleId) || null;
const findById = (id) => id ? store.find(id) : null;
const createUser = (userData) => {
  if (findByEmail(userData.email)) throw new Error('An account with this email already exists.');
  return store.insert({
    id: userData.id || `u-${require('node:crypto').randomUUID()}`,
    name: userData.name || 'Adopter', email: userData.email.toLowerCase().trim(),
    phone: userData.phone || '', role: userData.role || 'USER', status: userData.status || 'Active',
    avatarUrl: userData.avatarUrl || '', googleId: userData.googleId || null,
    provider: userData.provider || 'local', emailVerified: userData.emailVerified === true,
    permissions: userData.permissions || [], adoptionsCount: 0,
    joinedAt: new Date().toISOString(), lastLoginAt: new Date().toISOString(),
    preferredPetType: 'All Pets', location: 'Dhaka, Bangladesh', bio: '',
    isPremium: false, premiumPlanId: null, subscriptionExpiresAt: null,
    subscriptionStartedAt: null, subscriptionStatus: 'NONE',
  });
};
const updateUser = (id, updates) => store.update(id, updates);
const activateUserSubscription = (userId, planId, durationDays, tranId) => {
  const { db, transaction } = require('./database');
  return transaction(() => {
    const user = findById(userId);
    if (!user) throw new Error('Cannot grant a subscription to a missing account.');
    if (!Number.isInteger(durationDays) || durationDays < 1 || durationDays > 3660) throw new Error('Invalid purchased duration.');
    if (db.prepare('SELECT tran_id FROM subscription_grants WHERE tran_id = ?').get(tranId)) return user;
    const now = new Date();
    const expiry = new Date(user.subscriptionExpiresAt);
    const base = user.isPremium && expiry > now ? expiry : now;
    const updated = updateUser(user.id, {
      isPremium: true, premiumPlanId: planId,
      subscriptionStartedAt: user.subscriptionStartedAt || now.toISOString(),
      subscriptionExpiresAt: new Date(base.getTime() + durationDays * 86400000).toISOString(),
      subscriptionStatus: 'ACTIVE', lastPaymentTranId: tranId,
    });
    db.prepare('INSERT INTO subscription_grants(tran_id, user_id, granted_at) VALUES (?, ?, ?)')
      .run(tranId, user.id, now.toISOString());
    return updated;
  });
};
const getUserSubscription = (userId) => {
  const user = findById(userId);
  if (!user) return null;
  const now = new Date();
  const expiry = user.subscriptionExpiresAt ? new Date(user.subscriptionExpiresAt) : null;
  const active = Boolean(user.isPremium && expiry && expiry > now);
  const status = active ? 'ACTIVE' : expiry ? 'EXPIRED' : 'NONE';
  if (user.subscriptionStatus !== status || user.isPremium !== active) updateUser(user.id, { subscriptionStatus: status, isPremium: active });
  return { userId: user.id, userName: user.name, userEmail: user.email,
    isPremium: active, premiumPlanId: user.premiumPlanId || null, subscriptionStatus: status,
    subscriptionStartedAt: user.subscriptionStartedAt || null, subscriptionExpiresAt: user.subscriptionExpiresAt || null,
    remainingDays: active ? Math.max(0, Math.ceil((expiry - now) / 86400000)) : 0 };
};
module.exports = { findByEmail, findByGoogleId, findById, createUser, updateUser, getAllUsers, activateUserSubscription, getUserSubscription };
