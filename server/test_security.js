process.env.NODE_ENV = 'test';
process.env.JWT_SECRET = 'legacy-server-test-secret';
const assert = require('node:assert/strict');
const { spawnSync } = require('node:child_process');
const { app } = require('./index');
const { initDB } = require('./config/db');

async function main() {
  await initDB(); // non-production test intentionally uses the isolated memory provider
  const server = app.listen(0, '127.0.0.1');
  await new Promise(resolve => server.once('listening', resolve));
  const base = `http://127.0.0.1:${server.address().port}`;
  const request = async (path, body) => {
    const res = await fetch(base + path, { method: 'POST',
      headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(body) });
    return { status: res.status, data: await res.json() };
  };
  try {
    let res = await request('/api/auth/register', { name: 'Admin Attempt', email: 'admin-attempt@example.test',
      password: 'StrongPass123!', role: 'ADMIN' });
    assert.equal(res.status, 403);
    res = await request('/api/auth/register', { name: 'Test Adopter', email: 'legacy-test@example.test',
      password: 'CorrectPass123!', role: 'ADOPTER' });
    assert.equal(res.status, 201);
    res = await request('/api/auth/login', { email: 'legacy-test@example.test', password: 'password123' });
    assert.equal(res.status, 401, 'universal password must not authenticate');
    res = await request('/api/auth/login', { email: 'legacy-test@example.test', password: 'CorrectPass123!' });
    assert.equal(res.status, 200);
    assert.equal(res.data.user.role, 'ADOPTER');
    console.log('All 4 legacy auth security checks passed.');
  } finally { await new Promise(resolve => server.close(resolve)); }
  const prod = spawnSync(process.execPath, ['index.js'], { cwd: __dirname,
    env: { ...process.env, NODE_ENV: 'production', DB_HOST: '127.0.0.1', DB_PORT: '1' }, encoding: 'utf8', timeout: 10000 });
  assert.notEqual(prod.status, 0, 'production must not silently fall back to memory when MySQL is unavailable');
  console.log('Production database failure fails closed.');
}
main().catch(err => { console.error(err); process.exit(1); });
