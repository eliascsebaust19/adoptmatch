/**
 * AdoptMatch - Google authentication tests
 *
 * The endpoint must only accept cryptographically verified Google ID tokens.
 * These tests assert the rejection paths and the session lifecycle; they exit
 * non-zero when any assertion fails.
 *
 * Run: node test_google_auth.js
 */

process.env.NODE_ENV = 'test';
process.env.JWT_SECRET = 'google-auth-test-secret';

const assert = require('assert');
const jwt = require('jsonwebtoken');
const app = require('./server');
const { JWT_SECRET } = require('./middleware/rbacMiddleware');
const userStore = require('./models/userStore');

async function run() {
  const server = app.listen(0, '127.0.0.1');
  await new Promise((resolve) => server.once('listening', resolve));
  const base = `http://127.0.0.1:${server.address().port}`;

  const request = async (path, { method = 'GET', body, token } = {}) => {
    const res = await fetch(base + path, {
      method,
      headers: {
        'Content-Type': 'application/json',
        ...(token ? { Authorization: `Bearer ${token}` } : {}),
      },
      ...(body ? { body: JSON.stringify(body) } : {}),
    });
    return { status: res.status, data: await res.json() };
  };

  try {
    console.log('--- Google authentication contract ---');

    console.log('[1] Missing credentials are rejected');
    let res = await request('/api/v1/auth/google', { method: 'POST', body: {} });
    assert.strictEqual(res.status, 400);
    assert.strictEqual(res.data.code, 'MISSING_GOOGLE_CREDENTIALS');

    console.log('[2] A supplied profile cannot impersonate an administrator');
    res = await request('/api/v1/auth/google', {
      method: 'POST',
      body: { profile: { id: 'attacker-sub', email: 'superadmin@adoptmatch.org', name: 'Impostor' } },
    });
    assert.strictEqual(res.status, 400);
    assert.strictEqual(res.data.success, false);

    console.log('[3] Both snake_case and camelCase token keys are accepted as input, then verified');
    for (const key of ['id_token', 'idToken']) {
      res = await request('/api/v1/auth/google', { method: 'POST', body: { [key]: 'forged.google.token' } });
      assert.strictEqual(res.status, 401, `${key} must be verified, not trusted`);
      assert.strictEqual(res.data.code, 'INVALID_GOOGLE_TOKEN');
    }

    console.log('[4] An unauthenticated /me request is rejected');
    res = await request('/api/v1/auth/me');
    assert.strictEqual(res.status, 401);

    console.log('[5] A valid session reads its profile and is revoked on logout');
    const account = userStore.findByEmail('elias3224@gmail.com');
    const token = jwt.sign(
      { id: account.id, email: account.email, role: account.role, name: account.name },
      JWT_SECRET,
      { expiresIn: '1h' }
    );
    res = await request('/api/v1/auth/me', { token });
    assert.strictEqual(res.status, 200);
    assert.strictEqual(res.data.user.email, account.email);

    res = await request('/api/v1/auth/logout', { method: 'POST', body: {}, token });
    assert.strictEqual(res.status, 200);

    res = await request('/api/v1/auth/me', { token });
    assert.strictEqual(res.status, 401);
    assert.strictEqual(res.data.code, 'TOKEN_BLACKLISTED');

    console.log('[6] A suspended account cannot obtain a session');
    const banned = userStore.findByEmail('petshopdhaka@fake.com');
    assert.ok(banned, 'seeded suspended account exists');
    assert.strictEqual(String(banned.status).toUpperCase(), 'BANNED');
    const bannedToken = jwt.sign(
      { id: banned.id, email: banned.email, role: banned.role },
      JWT_SECRET,
      { expiresIn: '1h' }
    );
    res = await request('/api/v1/auth/me', { token: bannedToken });
    assert.strictEqual(res.status, 403);
    assert.strictEqual(res.data.code, 'USER_BANNED');

    console.log('\nAll Google authentication assertions passed.');
  } finally {
    await new Promise((resolve) => server.close(resolve));
  }
}

run().catch((err) => {
  console.error('\nGoogle auth test failed:', err);
  process.exit(1);
});
