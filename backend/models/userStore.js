/**
 * AdoptMatch - Enterprise User Data Store
 * In-memory unified user persistence with Google OAuth linking support.
 */

let usersDb = [
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

const findByEmail = (email) => {
  if (!email) return null;
  const normalized = email.toLowerCase().trim();
  return usersDb.find((u) => u.email.toLowerCase().trim() === normalized) || null;
};

const findByGoogleId = (googleId) => {
  if (!googleId) return null;
  return usersDb.find((u) => u.googleId === googleId) || null;
};

const findById = (id) => {
  if (!id) return null;
  return usersDb.find((u) => u.id === id) || null;
};

const createUser = (userData) => {
  const newUser = {
    id: userData.id || `usr-${Date.now()}-${Math.floor(Math.random() * 1000)}`,
    name: userData.name || 'Anonymous User',
    email: userData.email.toLowerCase().trim(),
    phone: userData.phone || '',
    role: userData.role || 'USER',
    status: userData.status || 'Active',
    avatarUrl: userData.avatarUrl || '',
    googleId: userData.googleId || null,
    provider: userData.provider || 'local',
    emailVerified: userData.emailVerified !== undefined ? userData.emailVerified : false,
    permissions: userData.permissions || [],
    adoptionsCount: 0,
    joinedAt: new Date().toISOString(),
    lastLoginAt: new Date().toISOString(),
    preferredPetType: userData.preferredPetType || 'All Pets',
    location: userData.location || 'Dhaka, Bangladesh',
    bio: userData.bio || 'Animal advocate & pet rescuer',
    isPremium: userData.isPremium || false,
    premiumPlanId: userData.premiumPlanId || null,
    subscriptionExpiresAt: userData.subscriptionExpiresAt || null,
    subscriptionStartedAt: userData.subscriptionStartedAt || null,
    subscriptionStatus: userData.subscriptionStatus || 'NONE',
  };

  usersDb.push(newUser);
  return newUser;
};

const activateUserSubscription = (userId, planId, durationDays = 30, tranId = '') => {
  let user = findById(userId);
  if (!user) {
    // Fallback: search by email if userId was an email
    user = findByEmail(userId);
  }
  if (!user) return null;

  const now = new Date();
  let baseDate = now;

  // If user already has an active subscription, extend from the current expiry date
  if (user.isPremium && user.subscriptionExpiresAt) {
    const existingExpiry = new Date(user.subscriptionExpiresAt);
    if (existingExpiry > now) {
      baseDate = existingExpiry;
    }
  }

  const newExpiry = new Date(baseDate.getTime() + durationDays * 24 * 60 * 60 * 1000);

  const updated = updateUser(user.id, {
    isPremium: true,
    premiumPlanId: planId,
    subscriptionStartedAt: user.subscriptionStartedAt || now.toISOString(),
    subscriptionExpiresAt: newExpiry.toISOString(),
    subscriptionStatus: 'ACTIVE',
    lastPaymentTranId: tranId,
  });

  return updated;
};

const getUserSubscription = (userId) => {
  let user = findById(userId) || findByEmail(userId);
  if (!user) return null;

  const now = new Date();
  let isCurrentlyPremium = Boolean(user.isPremium);
  let status = user.subscriptionStatus || 'NONE';

  // Check automated expiry
  if (user.subscriptionExpiresAt) {
    const expiry = new Date(user.subscriptionExpiresAt);
    if (expiry <= now) {
      isCurrentlyPremium = false;
      status = 'EXPIRED';
      updateUser(user.id, {
        isPremium: false,
        subscriptionStatus: 'EXPIRED',
      });
    }
  }

  const remainingDays = user.subscriptionExpiresAt
    ? Math.max(0, Math.ceil((new Date(user.subscriptionExpiresAt) - now) / (1000 * 60 * 60 * 24)))
    : 0;

  return {
    userId: user.id,
    userName: user.name,
    userEmail: user.email,
    isPremium: isCurrentlyPremium,
    premiumPlanId: user.premiumPlanId || null,
    subscriptionStatus: status,
    subscriptionStartedAt: user.subscriptionStartedAt || null,
    subscriptionExpiresAt: user.subscriptionExpiresAt || null,
    remainingDays,
  };
};

const updateUser = (id, updates) => {
  const index = usersDb.findIndex((u) => u.id === id);
  if (index === -1) return null;

  usersDb[index] = {
    ...usersDb[index],
    ...updates,
    id: usersDb[index].id, // Prevent overriding primary ID
  };

  return usersDb[index];
};

const getAllUsers = () => {
  return [...usersDb];
};

module.exports = {
  usersDb,
  findByEmail,
  findByGoogleId,
  findById,
  createUser,
  updateUser,
  getAllUsers,
  activateUserSubscription,
  getUserSubscription,
};

