/**
 * AdoptMatch - Enterprise Admin API Routes
 * Endpoints for User Banning & Token Invalidation, Role Delegation,
 * and Full Pet Listing CRUD & Image Override (Anytime Edit).
 */

const express = require('express');
const router = express.Router();
const planStore = require('../models/planStore');
const paymentStore = require('../models/paymentStore');
const userStore = require('../models/userStore');
const {
  authenticateToken,
  requireRole,
  requirePermission,
  requireAdmin,
  requireSuperAdmin,
  revokeUserTokens,
  clearUserRevocation,
} = require('../middleware/rbacMiddleware');

// Apply JWT authentication & Admin RBAC globally to all admin routes
router.use(authenticateToken);
router.use(requireRole(['ADMIN', 'SUPER_ADMIN', 'MODERATOR']));

// Available fine-grained moderation permissions
const VALID_PERMISSIONS = [
  'APPROVE_PETS',
  'FLAG_CONTENT',
  'REVIEW_APPLICATIONS',
  'MANAGE_USERS',
  'AUDIT_LOGS',
];

/* ==========================================================================
   IN-MEMORY ENTERPRISE DATA STORES (Mock Database)
   ========================================================================== */

let usersDb = [
  {
    id: 'u-101',
    name: 'Elias Ahmed',
    email: 'elias3224@gmail.com',
    phone: '+880 1711 234567',
    role: 'USER',
    status: 'Active',
    permissions: [],
    adoptionsCount: 1,
    joinedAt: '2026-06-15T00:00:00.000Z',
  },
  {
    id: 'u-102',
    name: 'Care For Paws Staff',
    email: 'info@careforpaws.bd',
    phone: '+880 1712 345678',
    role: 'SHELTER',
    status: 'Active',
    permissions: ['APPROVE_PETS'],
    adoptionsCount: 38,
    joinedAt: '2026-01-10T00:00:00.000Z',
  },
  {
    id: 'u-103',
    name: 'Sarah Rahman',
    email: 'superadmin@adoptmatch.org',
    phone: '+880 1819 000001',
    role: 'SUPER_ADMIN',
    status: 'Active',
    permissions: ['APPROVE_PETS', 'FLAG_CONTENT', 'REVIEW_APPLICATIONS', 'MANAGE_USERS', 'AUDIT_LOGS'],
    adoptionsCount: 0,
    joinedAt: '2025-08-01T00:00:00.000Z',
  },
  {
    id: 'u-104',
    name: 'Suspicious Lister 99',
    email: 'petshopdhaka@fake.com',
    phone: '+880 1911 000099',
    role: 'USER',
    status: 'Banned',
    permissions: [],
    adoptionsCount: 0,
    joinedAt: '2026-10-14T00:00:00.000Z',
  },
  {
    id: 'u-105',
    name: 'Tanvir Hossain (Volunteer Lead)',
    email: 'tanvir.mod@adoptmatch.org',
    phone: '+880 1713 999888',
    role: 'MODERATOR',
    status: 'Active',
    permissions: ['APPROVE_PETS', 'FLAG_CONTENT', 'REVIEW_APPLICATIONS'],
    adoptionsCount: 4,
    joinedAt: '2026-03-20T00:00:00.000Z',
  },
];

let petsDb = [
  {
    id: 'p1',
    name: 'Luna',
    species: 'Dog',
    breed: 'Lab Mix',
    ageDisplay: '2 yrs',
    ageMonths: 24,
    gender: 'Female',
    weightKg: 18.5,
    distanceKm: 2.4,
    matchScore: 95,
    imageUrl: 'https://images.unsplash.com/photo-1552053831-71594a27632d?auto=format&fit=crop&w=800&q=80',
    galleryUrls: [
      'https://images.unsplash.com/photo-1552053831-71594a27632d?auto=format&fit=crop&w=800&q=80',
      'https://images.unsplash.com/photo-1537151625747-768eb6cf92b2?auto=format&fit=crop&w=800&q=80',
      'https://images.unsplash.com/photo-1583511655857-d19b40a7a54e?auto=format&fit=crop&w=800&q=80',
    ],
    isFavorite: false,
    isUrgent: false,
    isFeatured: true,
    isFoster: false,
    isVaccinated: true,
    isNeutered: true,
    isHouseTrained: true,
    isKidSafe: true,
    isApartmentFriendly: true,
    shelterName: 'Dhaka Animal Rescue',
    shelterPhone: '+880 1712 345678',
    shelterAddress: 'Dhanmondi 27, Dhaka',
    shelterRating: 4.9,
    story: 'Luna was found near Dhanmondi Lake and nurtured by loving volunteers. She is gentle, loves belly rubs, and is completely house-trained!',
    medicalHistory: 'DHPP Core Vaccines (Done Dec 2025), Rabies booster due Nov 2026, Dewormed monthly.',
    qrHash: 'ADOPT-PET-LUNA-DHAKA-2026-X99',
    status: 'AVAILABLE',
    isBanned: false,
    reportsCount: 0,
    reportReasons: [],
    submittedBy: 'info@careforpaws.bd',
    lastModifiedByAdmin: null,
  },
  {
    id: 'p2',
    name: 'Mochi',
    species: 'Cat',
    breed: 'Calico',
    ageDisplay: '1 yr',
    ageMonths: 12,
    gender: 'Female',
    weightKg: 3.8,
    distanceKm: 4.1,
    matchScore: 88,
    imageUrl: 'https://images.unsplash.com/photo-1514888286974-6c03e2ca1dba?auto=format&fit=crop&w=800&q=80',
    galleryUrls: [
      'https://images.unsplash.com/photo-1514888286974-6c03e2ca1dba?auto=format&fit=crop&w=800&q=80',
      'https://images.unsplash.com/photo-1573865526739-10659fec78a5?auto=format&fit=crop&w=800&q=80',
    ],
    isFavorite: false,
    isUrgent: true,
    isFeatured: false,
    isFoster: true,
    isVaccinated: true,
    isNeutered: true,
    isHouseTrained: true,
    isKidSafe: true,
    isApartmentFriendly: true,
    shelterName: 'Care For Paws BD',
    shelterPhone: '+880 1819 876543',
    shelterAddress: 'Banani Road 11, Dhaka',
    shelterRating: 4.8,
    story: 'Mochi is a sweet, quiet calico girl who loves curling up on sunny window sills. Perfect companion for an apartment!',
    medicalHistory: 'FVRCP vaccinated, spayed in Jan 2026, negative for FIV/FeLV.',
    qrHash: 'ADOPT-PET-MOCHI-BANANI-2026-M44',
    status: 'AVAILABLE',
    isBanned: false,
    reportsCount: 1,
    reportReasons: ['Urgent medical surgery fund required'],
    submittedBy: 'info@careforpaws.bd',
    lastModifiedByAdmin: null,
  },
  {
    id: 'p-fl-1',
    name: 'Rocky',
    species: 'Dog',
    breed: 'Golden Retriever',
    ageDisplay: '4 mos',
    ageMonths: 4,
    gender: 'Male',
    weightKg: 8.2,
    distanceKm: 5.0,
    matchScore: 70,
    imageUrl: 'https://images.unsplash.com/photo-1558788353-f76d92427f16?auto=format&fit=crop&w=800&q=80',
    galleryUrls: [
      'https://images.unsplash.com/photo-1558788353-f76d92427f16?auto=format&fit=crop&w=800&q=80',
    ],
    isFavorite: false,
    isUrgent: false,
    isFeatured: false,
    isFoster: false,
    isVaccinated: false,
    isNeutered: false,
    isHouseTrained: false,
    isKidSafe: true,
    isApartmentFriendly: false,
    shelterName: 'Individual Lister',
    shelterPhone: '+880 1911 000099',
    shelterAddress: 'Mirpur, Dhaka',
    shelterRating: 2.1,
    story: 'Pure breed puppy, adoption fee ৳25,000 negotiable.',
    medicalHistory: 'No veterinary passport provided.',
    qrHash: 'ADOPT-PET-ROCKY-FLAG-2026-F99',
    status: 'AVAILABLE',
    isBanned: false,
    reportsCount: 6,
    reportReasons: ['Demanding ৳25,000 adoption fee (Commercial breeding violation)'],
    submittedBy: 'petshopdhaka@fake.com',
    lastModifiedByAdmin: null,
  },
];

let sheltersDb = [
  {
    id: 'SH-801',
    shelterName: 'Care For Paws Foundation (Dhaka)',
    registrationNumber: 'REG-DHK-2022-8901',
    contactPerson: 'Zahirul Islam',
    email: 'info@careforpaws.bd',
    phone: '+880 1712 345678',
    city: 'Dhaka',
    address: 'House 42, Road 11, Banani, Dhaka',
    nidNumber: '19892694582910384',
    tradeLicenseNumber: 'TRAD/DNCC/019283/2023',
    vetAffiliation: 'Central Veterinary Hospital, Dhaka',
    status: 'PENDING',
    capacity: 45,
    submittedAt: '2026-10-27T10:00:00.000Z',
  },
  {
    id: 'SH-802',
    shelterName: 'Paw Haven Chittagong Animal Sanctuary',
    registrationNumber: 'REG-CTG-2021-4412',
    contactPerson: 'Farhana Kabir',
    email: 'contact@pawhavenctg.org',
    phone: '+880 1819 876543',
    city: 'Chittagong',
    address: '102 Nasirabad Housing Society, Chattogram',
    nidNumber: '19921598432109847',
    tradeLicenseNumber: 'TRAD/CCC/044812/2022',
    vetAffiliation: 'Chittagong Vet & Animal Sciences University',
    status: 'PENDING',
    capacity: 35,
    submittedAt: '2026-10-26T14:30:00.000Z',
  },
];

let auditLogsDb = [
  {
    id: 'LOG-9001',
    timestamp: new Date().toISOString(),
    actorName: 'Sarah Rahman',
    actorRole: 'SUPER_ADMIN',
    action: 'SYSTEM_BOOT',
    target: 'Express RBAC Server',
    ipAddress: '127.0.0.1',
    details: 'Node.js RBAC server initialized with strict route policies and token invalidation.',
  },
];

// Helper to record audit logs
const logAdminAction = (req, action, target, details) => {
  const logEntry = {
    id: `LOG-${Date.now()}`,
    timestamp: new Date().toISOString(),
    actorName: req.user.name,
    actorRole: req.user.role,
    action,
    target,
    ipAddress: req.ip || req.connection?.remoteAddress || '127.0.0.1',
    details,
  };
  auditLogsDb.unshift(logEntry);
  return logEntry;
};

/* ==========================================================================
   1. KPI & OVERVIEW DASHBOARD
   ========================================================================== */
router.get('/stats', (req, res) => {
  const pendingShelters = sheltersDb.filter((s) => s.status === 'PENDING').length;
  const flaggedListings = petsDb.filter((p) => p.reportsCount > 0 && !p.isBanned).length;

  res.json({
    success: true,
    data: {
      totalAdoptions: 1284,
      pendingShelters,
      activeRescues: petsDb.filter((p) => !p.isBanned).length,
      totalDonationsBDT: 248500,
      flaggedListings,
      activeDisputes: 1,
      totalUsers: usersDb.length,
      bannedUsers: usersDb.filter((u) => u.status === 'BANNED' || u.status === 'Banned').length,
      generatedAt: new Date().toISOString(),
      requestedBy: req.user,
    },
  });
});

/* ==========================================================================
   2. USER BANNING & IMMEDIATE TOKEN INVALIDATION
   ========================================================================== */

/**
 * PATCH /api/v1/admin/users/:userId/block
 * Sets user.status = 'BANNED' and immediately revokes all active JWT refresh tokens.
 */
router.patch('/users/:userId/block', requirePermission('MANAGE_USERS'), (req, res) => {
  const { userId } = req.params;
  const { reason = 'Policy breach or commercial activity' } = req.body;

  const user = usersDb.find((u) => u.id === userId);
  if (!user) {
    return res.status(404).json({ success: false, error: 'User not found' });
  }

  // Prevent banning super admins
  if (user.role === 'SUPER_ADMIN') {
    return res.status(403).json({
      success: false,
      error: 'Cannot ban a Super Administrator account.',
    });
  }

  // 1. Update user record
  user.status = 'BANNED';
  user.bannedAt = new Date().toISOString();
  user.bannedBy = req.user.email;
  user.banReason = reason;

  // 2. Immediately revoke all active tokens / refresh tokens for this user
  const revocationTimestamp = revokeUserTokens(userId);

  // 3. Log security action
  logAdminAction(
    req,
    'USER_BANNED_TOKENS_REVOKED',
    `${user.name} (${user.id})`,
    `User banned. Active JWT tokens revoked at ${revocationTimestamp}. Reason: ${reason}`
  );

  res.json({
    success: true,
    message: `User ${user.name} (${user.id}) has been banned and all active JWT sessions revoked.`,
    data: {
      userId: user.id,
      status: user.status,
      revokedAt: revocationTimestamp,
      bannedBy: req.user.email,
    },
  });
});

/**
 * PATCH /api/v1/admin/users/:userId/unblock
 * Unblocks a banned user and restores Active status.
 */
router.patch('/users/:userId/unblock', requirePermission('MANAGE_USERS'), (req, res) => {
  const { userId } = req.params;

  const user = usersDb.find((u) => u.id === userId);
  if (!user) {
    return res.status(404).json({ success: false, error: 'User not found' });
  }

  user.status = 'Active';
  user.unblockedAt = new Date().toISOString();
  user.unblockedBy = req.user.email;
  delete user.banReason;

  // Clear revocation entry so future tokens can be authorized
  clearUserRevocation(userId);

  logAdminAction(
    req,
    'USER_UNBLOCKED',
    `${user.name} (${user.id})`,
    `Account status restored to Active. Future login sessions allowed.`
  );

  res.json({
    success: true,
    message: `User ${user.name} has been unblocked.`,
    data: user,
  });
});

/* ==========================================================================
   3. ROLE DELEGATION & MODERATION PERMISSIONS
   ========================================================================== */

/**
 * PATCH /api/v1/admin/users/:userId/role
 * Admin updates a user's role (e.g. USER -> MODERATOR).
 */
router.patch('/users/:userId/role', (req, res) => {
  const { userId } = req.params;
  const { role, permissions } = req.body;

  const validRoles = ['USER', 'SHELTER', 'FOSTER', 'MODERATOR', 'ADMIN', 'SUPER_ADMIN'];
  const targetRole = (role || '').toUpperCase().trim();

  if (!validRoles.includes(targetRole)) {
    return res.status(400).json({
      success: false,
      error: `Invalid role specified. Must be one of: [${validRoles.join(', ')}]`,
    });
  }

  // Promoting someone to ADMIN or SUPER_ADMIN requires the requester to be SUPER_ADMIN
  if ((targetRole === 'ADMIN' || targetRole === 'SUPER_ADMIN') && req.user.role !== 'SUPER_ADMIN') {
    return res.status(403).json({
      success: false,
      error: 'Only Super Administrators can delegate Admin or Super Admin roles.',
    });
  }

  const user = usersDb.find((u) => u.id === userId);
  if (!user) {
    return res.status(404).json({ success: false, error: 'User not found' });
  }

  const previousRole = user.role;
  user.role = targetRole;

  // Set default moderation permissions if transitioning to MODERATOR and none provided
  if (targetRole === 'MODERATOR') {
    user.permissions = Array.isArray(permissions) && permissions.length > 0
      ? permissions
      : ['APPROVE_PETS', 'FLAG_CONTENT', 'REVIEW_APPLICATIONS'];
  } else if (Array.isArray(permissions)) {
    user.permissions = permissions;
  }

  // Revoke previous tokens so new role / claims take effect on next login
  revokeUserTokens(userId);

  logAdminAction(
    req,
    'DELEGATED_USER_ROLE',
    `${user.name} (${user.id})`,
    `Role changed from ${previousRole} to ${targetRole}. Permissions: [${(user.permissions || []).join(', ')}]`
  );

  res.json({
    success: true,
    message: `User ${user.name} role successfully updated to ${targetRole}.`,
    data: user,
  });
});

/**
 * PATCH /api/v1/admin/users/:userId/permissions
 * Dedicated endpoint allowing admins to grant specific moderation powers to trusted users/volunteers.
 */
router.patch('/users/:userId/permissions', (req, res) => {
  const { userId } = req.params;
  const { permissions } = req.body;

  if (!Array.isArray(permissions)) {
    return res.status(400).json({
      success: false,
      error: 'permissions field must be an array of strings.',
      validPermissions: VALID_PERMISSIONS,
    });
  }

  // Validate permission codes
  const invalidPerms = permissions.filter((p) => !VALID_PERMISSIONS.includes(p));
  if (invalidPerms.length > 0) {
    return res.status(400).json({
      success: false,
      error: `Invalid permissions detected: [${invalidPerms.join(', ')}]`,
      validPermissions: VALID_PERMISSIONS,
    });
  }

  const user = usersDb.find((u) => u.id === userId);
  if (!user) {
    return res.status(404).json({ success: false, error: 'User not found' });
  }

  user.permissions = permissions;
  revokeUserTokens(userId);

  logAdminAction(
    req,
    'UPDATED_USER_PERMISSIONS',
    `${user.name} (${user.id})`,
    `Assigned permissions: [${permissions.join(', ')}]`
  );

  res.json({
    success: true,
    message: `Permissions updated for ${user.name}.`,
    data: {
      userId: user.id,
      role: user.role,
      permissions: user.permissions,
    },
  });
});

/**
 * GET /api/v1/admin/users
 * Returns list of users with roles, statuses, and permissions.
 */
router.get('/users', (req, res) => {
  const { role, status, q } = req.query;
  let results = [...usersDb];

  if (role) {
    results = results.filter((u) => u.role.toUpperCase() === role.toUpperCase());
  }
  if (status) {
    results = results.filter((u) => u.status.toUpperCase() === status.toUpperCase());
  }
  if (q) {
    const query = q.toLowerCase();
    results = results.filter(
      (u) =>
        u.name.toLowerCase().includes(query) ||
        u.email.toLowerCase().includes(query) ||
        u.phone.includes(query)
    );
  }

  res.json({
    success: true,
    count: results.length,
    availablePermissions: VALID_PERMISSIONS,
    data: results,
  });
});

/* ==========================================================================
   4. FULL PET LISTING CRUD & IMAGE OVERRIDE (ANYTIME EDIT)
   ========================================================================== */

/**
 * GET /api/v1/admin/pets
 * List all pet listings, with query filters for species, status, flagged listings.
 */
router.get('/pets', (req, res) => {
  const { species, flaggedOnly, q } = req.query;
  let results = [...petsDb];

  if (flaggedOnly === 'true') {
    results = results.filter((p) => p.reportsCount > 0);
  }
  if (species) {
    results = results.filter((p) => p.species.toLowerCase() === species.toLowerCase());
  }
  if (q) {
    const query = q.toLowerCase();
    results = results.filter(
      (p) =>
        p.name.toLowerCase().includes(query) ||
        p.breed.toLowerCase().includes(query) ||
        p.shelterName.toLowerCase().includes(query)
    );
  }

  res.json({
    success: true,
    count: results.length,
    data: results,
  });
});

/**
 * GET /api/v1/admin/pets/:id
 * Retrieve a single pet listing in full detail.
 */
router.get('/pets/:id', (req, res) => {
  const pet = petsDb.find((p) => p.id === req.params.id);
  if (!pet) {
    return res.status(404).json({ success: false, error: 'Pet listing not found' });
  }
  res.json({ success: true, data: pet });
});

/**
 * POST /api/v1/admin/pets
 * Admin creates a new pet profile directly with multi-image carousel.
 */
router.post('/pets', requirePermission('APPROVE_PETS'), (req, res) => {
  const {
    name,
    species,
    breed,
    ageDisplay,
    ageMonths,
    gender,
    weightKg,
    images = [],
    imageUrl,
    description,
    medicalHistory,
    shelterName,
    shelterPhone,
    shelterAddress,
    isVaccinated = true,
    isNeutered = true,
    isHouseTrained = true,
    isKidSafe = true,
    isApartmentFriendly = true,
    isUrgent = false,
    isFeatured = false,
  } = req.body;

  if (!name || !species || !breed) {
    return res.status(400).json({
      success: false,
      error: 'Missing mandatory pet fields: name, species, and breed are required.',
    });
  }

  const gallery = Array.isArray(images) && images.length > 0
    ? images
    : [imageUrl || 'https://images.unsplash.com/photo-1552053831-71594a27632d?auto=format&fit=crop&w=800&q=80'];

  const newPet = {
    id: `p-admin-${Date.now()}`,
    name,
    species,
    breed,
    ageDisplay: ageDisplay || `${Math.round((ageMonths || 12) / 12)} yrs`,
    ageMonths: ageMonths || 12,
    gender: gender || 'Male',
    weightKg: weightKg || 10.0,
    distanceKm: 0.0,
    matchScore: 90,
    imageUrl: imageUrl || gallery[0],
    galleryUrls: gallery,
    isFavorite: false,
    isUrgent: Boolean(isUrgent),
    isFeatured: Boolean(isFeatured),
    isFoster: false,
    isVaccinated: Boolean(isVaccinated),
    isNeutered: Boolean(isNeutered),
    isHouseTrained: Boolean(isHouseTrained),
    isKidSafe: Boolean(isKidSafe),
    isApartmentFriendly: Boolean(isApartmentFriendly),
    shelterName: shelterName || 'AdoptMatch Verified Rescue',
    shelterPhone: shelterPhone || '+880 1700 000000',
    shelterAddress: shelterAddress || 'Dhaka, Bangladesh',
    shelterRating: 5.0,
    story: description || 'Rescued and medically checked by official AdoptMatch administrators.',
    medicalHistory: medicalHistory || 'Full clinical examination complete, vaccines updated.',
    qrHash: `ADOPT-PET-ADMIN-${Date.now()}`,
    status: 'AVAILABLE',
    isBanned: false,
    reportsCount: 0,
    reportReasons: [],
    submittedBy: req.user.email,
    createdByAdmin: true,
    createdAt: new Date().toISOString(),
    lastModifiedByAdmin: {
      at: new Date().toISOString(),
      by: req.user.email,
      action: 'INITIAL_CREATION',
    },
  };

  petsDb.unshift(newPet);

  logAdminAction(
    req,
    'ADMIN_CREATED_PET_LISTING',
    `${newPet.name} (${newPet.id})`,
    `Created new ${newPet.species} listing with ${newPet.galleryUrls.length} photos.`
  );

  res.status(201).json({
    success: true,
    message: 'New pet profile successfully created by Administrator.',
    data: newPet,
  });
});

/**
 * PUT /api/v1/admin/pets/:id
 * Admin anytime edit or override of ANY user/shelter-submitted pet listing.
 * Updates multi-image carousel, description, medical records, or badges anytime.
 */
router.put('/pets/:id', requirePermission('APPROVE_PETS'), (req, res) => {
  const { id } = req.params;
  const pet = petsDb.find((p) => p.id === id);

  if (!pet) {
    return res.status(404).json({ success: false, error: 'Pet listing not found' });
  }

  const {
    name,
    species,
    breed,
    ageDisplay,
    ageMonths,
    gender,
    weightKg,
    images,
    imageUrl,
    description,
    story,
    medicalHistory,
    isVaccinated,
    isNeutered,
    isHouseTrained,
    isKidSafe,
    isApartmentFriendly,
    isUrgent,
    isFeatured,
    status,
    adminOverrideNotes,
  } = req.body;

  // Apply edits / overrides anytime
  if (name !== undefined) pet.name = name;
  if (species !== undefined) pet.species = species;
  if (breed !== undefined) pet.breed = breed;
  if (ageDisplay !== undefined) pet.ageDisplay = ageDisplay;
  if (ageMonths !== undefined) pet.ageMonths = ageMonths;
  if (gender !== undefined) pet.gender = gender;
  if (weightKg !== undefined) pet.weightKg = weightKg;

  // Multi-image carousel update
  if (Array.isArray(images) && images.length > 0) {
    pet.galleryUrls = images;
    pet.imageUrl = imageUrl || images[0];
  } else if (imageUrl !== undefined) {
    pet.imageUrl = imageUrl;
    if (!pet.galleryUrls.includes(imageUrl)) {
      pet.galleryUrls.unshift(imageUrl);
    }
  }

  if (description !== undefined) pet.story = description;
  if (story !== undefined) pet.story = story;
  if (medicalHistory !== undefined) pet.medicalHistory = medicalHistory;

  if (isVaccinated !== undefined) pet.isVaccinated = Boolean(isVaccinated);
  if (isNeutered !== undefined) pet.isNeutered = Boolean(isNeutered);
  if (isHouseTrained !== undefined) pet.isHouseTrained = Boolean(isHouseTrained);
  if (isKidSafe !== undefined) pet.isKidSafe = Boolean(isKidSafe);
  if (isApartmentFriendly !== undefined) pet.isApartmentFriendly = Boolean(isApartmentFriendly);

  if (isUrgent !== undefined) pet.isUrgent = Boolean(isUrgent);
  if (isFeatured !== undefined) pet.isFeatured = Boolean(isFeatured);
  if (status !== undefined) pet.status = status;

  // Record administrative override audit stamp
  pet.lastModifiedByAdmin = {
    at: new Date().toISOString(),
    by: req.user.email,
    notes: adminOverrideNotes || 'Admin anytime override',
  };

  logAdminAction(
    req,
    'ADMIN_OVERRIDE_PET_LISTING',
    `${pet.name} (${pet.id})`,
    `Listing details and medical history modified by administrator. Notes: ${adminOverrideNotes || 'None'}`
  );

  res.json({
    success: true,
    message: `Pet listing for "${pet.name}" successfully updated & overridden.`,
    data: pet,
  });
});

/**
 * PATCH /api/v1/admin/pets/:id/images
 * Dedicated multi-image carousel replacement endpoint.
 */
router.patch('/pets/:id/images', requirePermission('APPROVE_PETS'), (req, res) => {
  const { id } = req.params;
  const { images, primaryImageUrl } = req.body;

  if (!Array.isArray(images) || images.length === 0) {
    return res.status(400).json({
      success: false,
      error: 'images array must contain at least one valid image URL.',
    });
  }

  const pet = petsDb.find((p) => p.id === id);
  if (!pet) {
    return res.status(404).json({ success: false, error: 'Pet listing not found' });
  }

  pet.galleryUrls = images;
  pet.imageUrl = primaryImageUrl || images[0];
  pet.lastModifiedByAdmin = {
    at: new Date().toISOString(),
    by: req.user.email,
    action: 'IMAGE_CAROUSEL_REPLACED',
  };

  logAdminAction(
    req,
    'ADMIN_REPLACED_PET_CAROUSEL',
    `${pet.name} (${pet.id})`,
    `Image carousel replaced with ${images.length} photos.`
  );

  res.json({
    success: true,
    message: `Carousel photos for "${pet.name}" updated.`,
    data: {
      id: pet.id,
      imageUrl: pet.imageUrl,
      galleryUrls: pet.galleryUrls,
    },
  });
});

/**
 * DELETE /api/v1/admin/pets/:id
 * Deletes any pet listing permanently.
 */
router.delete('/pets/:id', requirePermission('APPROVE_PETS'), (req, res) => {
  const { id } = req.params;
  const petIndex = petsDb.findIndex((p) => p.id === id);

  if (petIndex === -1) {
    return res.status(404).json({ success: false, error: 'Pet listing not found' });
  }

  const deletedPet = petsDb.splice(petIndex, 1)[0];

  logAdminAction(
    req,
    'ADMIN_DELETED_PET_LISTING',
    `${deletedPet.name} (${deletedPet.id})`,
    'Listing deleted permanently by administrator.'
  );

  res.json({
    success: true,
    message: `Pet listing "${deletedPet.name}" deleted successfully.`,
  });
});

/**
 * PATCH /api/v1/admin/pets/:id/ban
 * Ban listing from public discovery due to policy breach.
 */
router.patch('/pets/:id/ban', requirePermission('FLAG_CONTENT'), (req, res) => {
  const { id } = req.params;
  const pet = petsDb.find((p) => p.id === id);

  if (!pet) {
    return res.status(404).json({ success: false, error: 'Pet listing not found' });
  }

  pet.isBanned = true;

  logAdminAction(req, 'BANNED_PET_LISTING', `${pet.name} (${pet.id})`, 'Listing banned from discovery.');

  res.json({
    success: true,
    message: `Pet listing ${pet.name} (${id}) has been banned from public discovery.`,
    data: pet,
  });
});

/**
 * PATCH /api/v1/admin/pets/:id/badge
 * Toggle Urgent / Featured badge on any listing.
 */
router.patch('/pets/:id/badge', requirePermission('APPROVE_PETS'), (req, res) => {
  const { id } = req.params;
  const { isUrgent, isFeatured } = req.body;

  const pet = petsDb.find((p) => p.id === id);
  if (!pet) {
    return res.status(404).json({ success: false, error: 'Pet listing not found' });
  }

  if (isUrgent !== undefined) pet.isUrgent = Boolean(isUrgent);
  if (isFeatured !== undefined) pet.isFeatured = Boolean(isFeatured);

  logAdminAction(
    req,
    'UPDATED_PET_BADGES',
    `${pet.name} (${pet.id})`,
    `Flags updated: urgent=${pet.isUrgent}, featured=${pet.isFeatured}`
  );

  res.json({
    success: true,
    message: `Badges updated for "${pet.name}".`,
    data: pet,
  });
});

/* ==========================================================================
   5. SHELTER APPROVAL QUEUE
   ========================================================================== */
router.get('/shelters', (req, res) => {
  const { status, city } = req.query;
  let result = [...sheltersDb];

  if (status) {
    result = result.filter((s) => s.status.toUpperCase() === status.toUpperCase());
  }
  if (city) {
    result = result.filter((s) => s.city.toLowerCase().includes(city.toLowerCase()));
  }

  res.json({
    success: true,
    count: result.length,
    data: result,
  });
});

router.patch('/shelters/:id/approve', requirePermission('APPROVE_PETS'), (req, res) => {
  const { id } = req.params;
  const { notes } = req.body;

  const shelter = sheltersDb.find((s) => s.id === id);
  if (!shelter) {
    return res.status(404).json({ success: false, error: 'Shelter registration not found' });
  }

  shelter.status = 'APPROVED';
  shelter.reviewerNotes = notes || 'Approved by system administrator after government document check.';
  shelter.approvedAt = new Date().toISOString();
  shelter.approvedBy = req.user.email;

  logAdminAction(req, 'APPROVED_SHELTER', shelter.id, `Shelter "${shelter.shelterName}" approved.`);

  res.json({
    success: true,
    message: `Shelter "${shelter.shelterName}" successfully approved.`,
    data: shelter,
  });
});

router.patch('/shelters/:id/reject', requirePermission('APPROVE_PETS'), (req, res) => {
  const { id } = req.params;
  const { reason } = req.body;

  if (!reason) {
    return res.status(400).json({ success: false, error: 'Rejection reason is required' });
  }

  const shelter = sheltersDb.find((s) => s.id === id);
  if (!shelter) {
    return res.status(404).json({ success: false, error: 'Shelter registration not found' });
  }

  shelter.status = 'REJECTED';
  shelter.rejectionReason = reason;
  shelter.reviewedAt = new Date().toISOString();
  shelter.reviewedBy = req.user.email;

  logAdminAction(req, 'REJECTED_SHELTER', shelter.id, `Shelter rejected. Reason: ${reason}`);

  res.json({
    success: true,
    message: `Shelter "${shelter.shelterName}" rejected.`,
    data: shelter,
  });
});

/* ==========================================================================
   6. SECURITY AUDIT LOGS
   ========================================================================== */
router.get('/audit-logs', requirePermission('AUDIT_LOGS'), (req, res) => {
  res.json({
    success: true,
    count: auditLogsDb.length,
    data: auditLogsDb,
  });
});

/* ==========================================================================
   7. SUBSCRIPTION & PAYMENT MANAGEMENT
   ========================================================================== */

/**
 * GET /api/v1/admin/subscriptions
 * Aggregated subscription dashboard metrics, active premium users, and plans
 */
router.get('/subscriptions', (req, res) => {
  const stats = paymentStore.getPaymentStats();
  const plans = planStore.getAllPlans();
  const allUsers = userStore.getAllUsers();
  const premiumUsers = allUsers.filter(u => u.isPremium);

  res.json({
    success: true,
    stats: {
      ...stats,
      activePremiumUsersCount: premiumUsers.length,
    },
    plans,
    activePremiumUsers: premiumUsers.map(u => ({
      id: u.id,
      name: u.name,
      email: u.email,
      phone: u.phone,
      planId: u.premiumPlanId,
      expiresAt: u.subscriptionExpiresAt,
      status: u.subscriptionStatus,
    })),
  });
});

/**
 * GET /api/v1/admin/payments
 * Filterable payment transaction log (SUCCESS, PENDING_APPROVAL, FAILED, ALL)
 */
router.get('/payments', (req, res) => {
  const { status, search } = req.query;
  const payments = paymentStore.getAllPayments({ status, search });

  res.json({
    success: true,
    count: payments.length,
    data: payments,
  });
});

/**
 * POST /api/v1/admin/payments/:tranId/approve
 * Approves a pending manual bKash payment and activates subscription
 */
router.post('/payments/:tranId/approve', (req, res) => {
  const { tranId } = req.params;
  const payment = paymentStore.getPaymentByTranId(tranId);

  if (!payment) {
    return res.status(404).json({ success: false, error: 'Payment transaction not found' });
  }

  if (payment.status === 'SUCCESS') {
    return res.status(400).json({ success: false, error: 'This payment has already been approved and activated.' });
  }

  const approved = paymentStore.approveManualPayment(tranId, req.user.email);
  const plan = planStore.getPlanById(approved.planId);
  const durationDays = plan ? plan.durationDays : 30;

  // Activate User Subscription
  const updatedUser = userStore.activateUserSubscription(approved.userId, approved.planId, durationDays, tranId);

  logAdminAction(req, 'APPROVED_BKASH_PAYMENT', tranId, `Approved bKash TrxID "${approved.trxId}" for user "${approved.userName}". Plan: ${approved.planName} (৳${approved.amount} BDT).`);

  res.json({
    success: true,
    message: `Payment "${tranId}" approved successfully. Premium activated for user "${approved.userName}" for ${durationDays} days.`,
    payment: approved,
    user: updatedUser,
  });
});

/**
 * POST /api/v1/admin/payments/:tranId/reject
 * Rejects a manual bKash payment request
 */
router.post('/payments/:tranId/reject', (req, res) => {
  const { tranId } = req.params;
  const { reason = 'Invalid or duplicate bKash Transaction ID (TrxID)' } = req.body;

  const payment = paymentStore.getPaymentByTranId(tranId);
  if (!payment) {
    return res.status(404).json({ success: false, error: 'Payment transaction not found' });
  }

  const rejected = paymentStore.rejectManualPayment(tranId, reason, req.user.email);

  logAdminAction(req, 'REJECTED_BKASH_PAYMENT', tranId, `Rejected payment "${tranId}". Reason: ${reason}`);

  res.json({
    success: true,
    message: `Payment "${tranId}" rejected.`,
    payment: rejected,
  });
});

/**
 * PUT /api/v1/admin/plans/:id
 * Dynamic Plan Editor (Admin can modify price, duration, features)
 */
router.put('/plans/:id', requireRole(['ADMIN', 'SUPER_ADMIN']), (req, res) => {
  const { id } = req.params;
  const updates = req.body;

  const updatedPlan = planStore.updatePlan(id, updates);
  if (!updatedPlan) {
    return res.status(404).json({ success: false, error: 'Plan not found' });
  }

  logAdminAction(req, 'UPDATED_SUBSCRIPTION_PLAN', id, `Updated plan "${updatedPlan.name}": Price ৳${updatedPlan.price} BDT, Duration: ${updatedPlan.durationDays} days.`);

  res.json({
    success: true,
    message: `Plan "${updatedPlan.name}" updated successfully.`,
    plan: updatedPlan,
  });
});

module.exports = router;
