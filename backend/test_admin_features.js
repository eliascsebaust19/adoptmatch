/**
 * Verification test script for AdoptMatch Admin API
 * Tests User Banning, Token Invalidation, Role Delegation, and Pet Anytime CRUD & Image Override.
 */

const jwt = require('jsonwebtoken');
const express = require('express');
const {
  authenticateToken,
  requireRole,
  requirePermission,
  revokeUserTokens,
  clearUserRevocation,
  JWT_SECRET,
} = require('./middleware/rbacMiddleware');
const adminRoutes = require('./routes/adminRoutes');

const app = express();
app.use(express.json());
app.use('/api/v1/admin', adminRoutes);

// Helper to create token
function generateToken(payload) {
  return jwt.sign(payload, JWT_SECRET, { expiresIn: '1h' });
}

async function runTests() {
  console.log('--- Starting AdoptMatch Admin API Feature Verification ---');

  // 1. Generate Super Admin Token
  const adminToken = generateToken({
    id: 'u-103',
    email: 'superadmin@adoptmatch.org',
    role: 'SUPER_ADMIN',
    name: 'Sarah Rahman',
    permissions: ['APPROVE_PETS', 'FLAG_CONTENT', 'REVIEW_APPLICATIONS', 'MANAGE_USERS', 'AUDIT_LOGS'],
  });

  // 2. Generate regular user token (issued now)
  const regularUserToken = generateToken({
    id: 'u-101',
    email: 'elias3224@gmail.com',
    role: 'USER',
    name: 'Elias Ahmed',
  });

  const http = require('http');
  const server = http.createServer(app);

  await new Promise((resolve) => server.listen(0, resolve));
  const port = server.address().port;
  const baseUrl = `http://127.0.0.1:${port}/api/v1/admin`;

  const request = async (method, path, body = null, token = adminToken) => {
    const res = await fetch(`${baseUrl}${path}`, {
      method,
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${token}`,
      },
      body: body ? JSON.stringify(body) : undefined,
    });
    const data = await res.json();
    return { status: res.status, data };
  };

  // Test 1: User Banning & Immediate Token Invalidation
  console.log('\n[TEST 1] Banning user u-101 and invalidating JWT tokens...');
  const banRes = await request('PATCH', '/users/u-101/block', { reason: 'Unauthorized commercial advertising' });
  console.log('Ban response status:', banRes.status);
  console.log('Ban message:', banRes.data.message);
  if (banRes.status !== 200) throw new Error('Failed to ban user');

  // Test 1b: Verify previously issued token for u-101 is now REJECTED
  console.log('\n[TEST 1b] Verifying that u-101 active token is now rejected due to revocation...');
  const revokedCheck = await request('GET', '/stats', null, regularUserToken);
  console.log('Revoked token check status:', revokedCheck.status);
  console.log('Revoked error code:', revokedCheck.data.code);
  if (revokedCheck.status !== 401 || revokedCheck.data.code !== 'TOKEN_REVOKED') {
    throw new Error('Expected TOKEN_REVOKED 401 error for banned user token');
  }
  console.log('✓ Token invalidation works! Token was rejected immediately.');

  // Test 1c: Unblock user
  console.log('\n[TEST 1c] Unblocking user u-101...');
  const unblockRes = await request('PATCH', '/users/u-101/unblock');
  console.log('Unblock response:', unblockRes.data.message);
  if (unblockRes.status !== 200) throw new Error('Failed to unblock user');

  // Test 2: Role Delegation (USER -> MODERATOR)
  console.log('\n[TEST 2] Delegating MODERATOR role to u-101...');
  const roleRes = await request('PATCH', '/users/u-101/role', {
    role: 'MODERATOR',
    permissions: ['APPROVE_PETS', 'FLAG_CONTENT'],
  });
  console.log('Role delegation response:', roleRes.data.message);
  console.log('Delegated permissions:', roleRes.data.data.permissions);
  if (roleRes.status !== 200 || roleRes.data.data.role !== 'MODERATOR') {
    throw new Error('Failed to delegate MODERATOR role');
  }
  console.log('✓ Role delegation successful!');

  // Test 3: Updating User Permissions
  console.log('\n[TEST 3] Updating permissions for u-101...');
  const permRes = await request('PATCH', '/users/u-101/permissions', {
    permissions: ['APPROVE_PETS', 'FLAG_CONTENT', 'REVIEW_APPLICATIONS'],
  });
  console.log('Permissions updated:', permRes.data.data.permissions);
  if (permRes.status !== 200) throw new Error('Failed to update permissions');
  console.log('✓ Permissions update verified!');

  // Test 4: Create Pet Listing Directly by Admin
  console.log('\n[TEST 4] Admin creates direct pet listing with multi-image carousel...');
  const createPetRes = await request('POST', '/pets', {
    name: 'Atlas',
    species: 'Dog',
    breed: 'Siberian Husky',
    ageDisplay: '2 yrs',
    gender: 'Male',
    weightKg: 24.5,
    images: [
      'https://images.unsplash.com/photo-husky-1',
      'https://images.unsplash.com/photo-husky-2',
      'https://images.unsplash.com/photo-husky-3',
    ],
    description: 'Energetic rescue husky saved by emergency team.',
    medicalHistory: 'Rabies, DHPP, and microchip implanted.',
    isVaccinated: true,
    isNeutered: true,
    isUrgent: true,
    isFeatured: true,
  });
  console.log('Pet creation status:', createPetRes.status);
  console.log('Created pet ID:', createPetRes.data.data.id);
  const createdPetId = createPetRes.data.data.id;
  if (createPetRes.status !== 201) throw new Error('Failed to create pet profile');
  console.log('✓ Admin pet profile created!');

  // Test 5: Admin Anytime Edit & Image Override (PUT /api/v1/admin/pets/:petId)
  console.log('\n[TEST 5] Admin overrides listing anytime (PUT /pets/:id)...');
  const overrideRes = await request('PUT', `/pets/${createdPetId}`, {
    name: 'Atlas the Wonder Dog',
    images: [
      'https://images.unsplash.com/photo-override-1',
      'https://images.unsplash.com/photo-override-2',
    ],
    description: 'Updated story: Loving, leash-trained, and ready for home.',
    medicalHistory: 'Surgery completed successfully by Dr. Hasan.',
    adminOverrideNotes: 'Post-op medical check passed',
  });
  console.log('Override status:', overrideRes.status);
  console.log('Updated pet name:', overrideRes.data.data.name);
  console.log('Updated photos count:', overrideRes.data.data.galleryUrls.length);
  if (overrideRes.status !== 200 || overrideRes.data.data.name !== 'Atlas the Wonder Dog') {
    throw new Error('Failed to override pet listing');
  }
  console.log('✓ Admin anytime edit & override verified!');

  // Test 6: Dedicated Multi-Image Carousel Replacement (PATCH /pets/:id/images)
  console.log('\n[TEST 6] Dedicated image carousel replacement (PATCH /pets/:id/images)...');
  const imageRes = await request('PATCH', `/pets/${createdPetId}/images`, {
    images: [
      'https://images.unsplash.com/photo-new-carousel-1',
      'https://images.unsplash.com/photo-new-carousel-2',
      'https://images.unsplash.com/photo-new-carousel-3',
      'https://images.unsplash.com/photo-new-carousel-4',
    ],
  });
  console.log('Image carousel replaced, total photos:', imageRes.data.data.galleryUrls.length);
  if (imageRes.status !== 200 || imageRes.data.data.galleryUrls.length !== 4) {
    throw new Error('Failed to replace image carousel');
  }
  console.log('✓ Multi-image carousel replacement verified!');

  // Test 7: Admin Pet Deletion (DELETE /pets/:id)
  console.log('\n[TEST 7] Deleting pet listing (DELETE /pets/:id)...');
  const deleteRes = await request('DELETE', `/pets/${createdPetId}`);
  console.log('Delete response:', deleteRes.data.message);
  if (deleteRes.status !== 200) throw new Error('Failed to delete pet listing');
  console.log('✓ Admin deletion verified!');

  server.close();
  console.log('\n=======================================================');
  console.log(' ALL ADMIN PRIVILEGE & MODERATION API TESTS PASSED! 🚀');
  console.log('=======================================================');
}

runTests().catch((err) => {
  console.error('Test execution failed:', err);
  process.exit(1);
});

