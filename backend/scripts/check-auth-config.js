/**
 * Auth configuration preflight.
 *
 * Verifies that this deployment can actually authenticate users instead of
 * failing at runtime with 401/503. Exits non-zero when auth-critical config is
 * missing so it can be used in CI or before `npm start`.
 *
 *   node scripts/check-auth-config.js
 *   NODE_ENV=production node scripts/check-auth-config.js
 */

require('dotenv').config({ path: require('path').join(__dirname, '..', '.env') });

const isProduction = process.env.NODE_ENV === 'production';
const rows = [];
let failed = false;

function check(name, value, { required, hint, validate }) {
  const present = typeof value === 'string' && value.trim().length > 0;
  let ok = present;
  let note = '';
  if (present && validate) {
    const problem = validate(value.trim());
    if (problem) { ok = false; note = problem; }
  }
  if (!present) note = required ? 'MISSING (required)' : 'not set (optional)';
  if (!ok && required) failed = true;
  rows.push({ name, status: ok ? 'OK' : (required ? 'FAIL' : 'WARN'), note: note || hint || '' });
}

const googleIds = [process.env.GOOGLE_CLIENT_ID, ...(process.env.GOOGLE_CLIENT_IDS || '').split(',')]
  .map((v) => (v || '').trim()).filter(Boolean);

check('GOOGLE_CLIENT_ID', process.env.GOOGLE_CLIENT_ID, {
  required: true,
  hint: 'Web OAuth client ID; must equal the app\'s --dart-define=GOOGLE_CLIENT_ID',
  validate: (v) => v.endsWith('.apps.googleusercontent.com')
    ? '' : 'does not look like an OAuth client ID (*.apps.googleusercontent.com)',
});

check('JWT_SECRET', process.env.JWT_SECRET, {
  required: true,
  hint: 'signs API sessions',
  validate: (v) => v.length >= 32 ? '' : `too short (${v.length}); use at least 32 characters`,
});

check('DATABASE_PATH', process.env.DATABASE_PATH, {
  required: isProduction,
  hint: 'durable SQLite file; one process per file',
});

check('TEST_AUTH_SECRET', process.env.TEST_AUTH_SECRET, {
  required: false,
  hint: 'only needed to mint non-production test tokens',
});

check('BLOB_READ_WRITE_TOKEN', process.env.BLOB_READ_WRITE_TOKEN, {
  required: false,
  hint: 'image uploads return 503 without a storage provider',
});

console.log('\nAdoptMatch auth configuration preflight');
console.log(`Environment: ${process.env.NODE_ENV || 'development'}\n`);
for (const row of rows) {
  console.log(`  [${row.status.padEnd(4)}] ${row.name.padEnd(22)} ${row.note}`);
}
console.log(`\n  Google audiences accepted: ${googleIds.length ? googleIds.join(', ') : '(none — /auth/google returns 503)'}`);
console.log('\n  Phone OTP is configured on the Laravel API (SUPABASE_URL / SUPABASE_ANON_KEY),');
console.log('  not here. See docs/AUTH_SETUP.md for the full checklist.\n');

if (failed) {
  console.error('Auth configuration is incomplete. Fix the FAIL rows before serving traffic.');
  process.exit(1);
}
console.log('Auth configuration looks usable. Live provider verification is still required.');
