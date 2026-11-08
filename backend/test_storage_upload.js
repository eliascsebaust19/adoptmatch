/**
 * AdoptMatch - Storage upload tests
 *
 * A URL may only be returned when bytes were actually persisted. With no
 * storage provider configured the endpoint must fail closed, and callers must
 * be authenticated with a genuine image.
 *
 * Run: node test_storage_upload.js
 */

process.env.NODE_ENV = 'test';
process.env.JWT_SECRET = 'storage-upload-test-secret';
delete process.env.BLOB_READ_WRITE_TOKEN;
delete process.env.SUPABASE_URL;
delete process.env.SUPABASE_SERVICE_ROLE_KEY;

const assert = require('assert');
const jwt = require('jsonwebtoken');
const app = require('./server');
const { JWT_SECRET } = require('./middleware/rbacMiddleware');

const GIF_BASE64 = 'R0lGODlhAQABAIAAAAAAAP///yH5BAEAAAAALAAAAAABAAEAAAIBRAA7';
const PNG_BASE64 =
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8DwHwAFAAH/q842iQAAAABJRU5ErkJggg==';

async function run() {
  const server = app.listen(0, '127.0.0.1');
  await new Promise((resolve) => server.once('listening', resolve));
  const base = `http://127.0.0.1:${server.address().port}`;

  const token = jwt.sign(
    { id: 'u-101', email: 'elias3224@gmail.com', role: 'USER' },
    JWT_SECRET,
    { expiresIn: '1h' }
  );

  const upload = async (body, authToken) => {
    const res = await fetch(`${base}/api/v1/storage/upload`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        ...(authToken ? { Authorization: `Bearer ${authToken}` } : {}),
      },
      body: JSON.stringify(body),
    });
    return { status: res.status, data: await res.json() };
  };

  try {
    console.log('--- Storage upload contract ---');

    console.log('[1] Anonymous uploads are rejected');
    let res = await upload({ base64Data: GIF_BASE64, contentType: 'image/gif' });
    assert.strictEqual(res.status, 401);

    console.log('[2] Missing payload is rejected');
    res = await upload({}, token);
    assert.strictEqual(res.status, 400);

    console.log('[3] Non-image content types are rejected');
    res = await upload({ base64Data: GIF_BASE64, contentType: 'image/svg+xml' }, token);
    assert.strictEqual(res.status, 415);

    console.log('[4] Bytes that do not match the declared type are rejected');
    res = await upload({ base64Data: GIF_BASE64, contentType: 'image/png' }, token);
    assert.strictEqual(res.status, 415);

    console.log('[5] Oversized payloads are rejected');
    const oversized = Buffer.alloc(6 * 1024 * 1024, 1);
    oversized.set([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a], 0);
    res = await upload({ base64Data: oversized.toString('base64'), contentType: 'image/png' }, token);
    assert.strictEqual(res.status, 413);

    console.log('[6] A valid image with no configured provider fails closed');
    res = await upload({ base64Data: PNG_BASE64, contentType: 'image/png', filename: 'avatar.png' }, token);
    assert.strictEqual(res.status, 503);
    assert.strictEqual(res.data.success, false);
    assert.strictEqual(res.data.url, undefined, 'no URL may be fabricated without a real write');

    console.log('\nAll storage upload assertions passed.');
  } finally {
    await new Promise((resolve) => server.close(resolve));
  }
}

run().catch((err) => {
  console.error('\nStorage upload test failed:', err);
  process.exit(1);
});
