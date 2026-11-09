#!/usr/bin/env node
/**
 * Creates the first super admin — once.
 *
 * Run it with the service role key, after `supabase db push`:
 *
 *   SUPABASE_URL=https://<ref>.supabase.co \
 *   SUPABASE_SERVICE_ROLE_KEY=<service-role-key> \
 *   ADMIN_EMAIL=you@example.com ADMIN_PASSWORD='<strong-password>' \
 *   node scripts/bootstrap-admin.mjs
 *
 * It refuses to run when a super admin already exists, so a leaked command
 * cannot be replayed to mint another one. `--force` exists for local resets and
 * is refused when NODE_ENV=production.
 */

const SUPABASE_URL = process.env.SUPABASE_URL?.replace(/\/+$/, '');
const SERVICE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY;
const EMAIL = process.env.ADMIN_EMAIL?.trim().toLowerCase();
const PASSWORD = process.env.ADMIN_PASSWORD;
const NAME = process.env.ADMIN_NAME?.trim() || 'AdoptMatch Admin';
const FORCE = process.argv.includes('--force');

function die(message) {
  console.error(`\n✖ ${message}\n`);
  process.exit(1);
}

if (!SUPABASE_URL || !SERVICE_KEY) die('SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY are required.');
if (!EMAIL || !PASSWORD) die('ADMIN_EMAIL and ADMIN_PASSWORD are required.');
if (PASSWORD.length < 10) die('Use a password of at least 10 characters.');
if (FORCE && process.env.NODE_ENV === 'production') die('--force is not allowed in production.');

const headers = {
  apikey: SERVICE_KEY,
  Authorization: `Bearer ${SERVICE_KEY}`,
  'Content-Type': 'application/json',
};

async function api(path, init = {}) {
  const response = await fetch(`${SUPABASE_URL}${path}`, { headers, ...init });
  const text = await response.text();
  let body = null;
  if (text) {
    try {
      body = JSON.parse(text);
    } catch {
      body = text;
    }
  }
  if (!response.ok) {
    throw new Error(`${init.method ?? 'GET'} ${path} → ${response.status}: ${text.slice(0, 300)}`);
  }
  return body;
}

async function main() {
  console.log(`→ Target project: ${SUPABASE_URL}`);

  const existing = await api('/rest/v1/profiles?select=id,email&role=eq.super_admin&limit=1');
  if (existing.length > 0 && !FORCE) {
    die(
      `A super admin already exists (${existing[0].email ?? existing[0].id}). ` +
        'Refusing to create another one.',
    );
  }

  const created = await api('/auth/v1/admin/users', {
    method: 'POST',
    body: JSON.stringify({
      email: EMAIL,
      password: PASSWORD,
      email_confirm: true,
      user_metadata: { full_name: NAME },
    }),
  }).catch(async (error) => {
    // A rerun after a partial setup: reuse the account if it already exists.
    if (String(error.message).includes('already been registered')) {
      console.log('• Account already exists, reusing it.');
      const list = await api(`/auth/v1/admin/users?page=1&per_page=200`);
      const found = (list.users ?? []).find((u) => (u.email ?? '').toLowerCase() === EMAIL);
      if (!found) throw error;
      return { id: found.id };
    }
    throw error;
  });

  const userId = created.id ?? created.user?.id;
  if (!userId) die('The auth service did not return a user id.');

  await api(`/rest/v1/profiles?id=eq.${userId}`, {
    method: 'PATCH',
    headers: { ...headers, Prefer: 'return=representation' },
    body: JSON.stringify({ role: 'super_admin', is_verified: true, status: 'active' }),
  });

  const check = await api(`/rest/v1/profiles?id=eq.${userId}&select=id,email,role,status`);
  if (check[0]?.role !== 'super_admin') {
    die('The profile was created but the super_admin role did not stick.');
  }

  console.log(`✔ Super admin ready: ${check[0].email} (${check[0].id})`);
  console.log('  Sign in, then rotate the password from the app if it was shared.');
}

main().catch((error) => {
  console.error(error.message);
  process.exit(1);
});
