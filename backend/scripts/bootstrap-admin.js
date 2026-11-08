#!/usr/bin/env node
/**
 * Create the first Node admin account without shipping demo credentials.
 * The administrator signs in with Google; provide the verified Google subject
 * (`sub`) for that account. Existing accounts are never silently promoted.
 */
require('dotenv').config({ path: require('path').join(__dirname, '..', '.env') });
const path = require('node:path');

function arg(name) {
  const index = process.argv.indexOf(name);
  return index === -1 ? '' : (process.argv[index + 1] || '');
}

const databasePath = process.env.DATABASE_PATH;
if (!databasePath || databasePath === ':memory:') {
  console.error('Set DATABASE_PATH to a durable SQLite file before bootstrapping an admin.');
  process.exit(1);
}
process.env.DATABASE_PATH = path.resolve(databasePath);
const email = arg('--email').trim().toLowerCase();
const googleSub = arg('--google-sub').trim();
const name = arg('--name').trim() || 'AdoptMatch Administrator';
if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email) || !/^[0-9]{5,40}$/.test(googleSub)) {
  console.error('Usage: npm run bootstrap:admin -- --email admin@example.com --google-sub 1234567890 [--name "Name"]');
  process.exit(1);
}
const users = require('../models/userStore');
if (users.findByEmail(email) || users.findByGoogleId(googleSub)) {
  console.error('An account with this email or Google subject already exists. No changes were made.');
  process.exit(1);
}
const admin = users.createUser({ name, email, googleId: googleSub, provider: 'google',
  emailVerified: true, role: 'SUPER_ADMIN', status: 'Active', permissions: [] });
console.log(`Created SUPER_ADMIN ${admin.id} for ${email}. Sign in with that Google account.`);
