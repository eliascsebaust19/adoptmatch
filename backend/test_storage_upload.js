/**
 * Test storage upload endpoint (Vercel Blob / Supabase compatible)
 */
const http = require('http');
const app = require('./server');

async function testStorageUpload() {
  console.log('--- Testing Storage Upload Endpoint (Vercel Blob / Supabase) ---');

  const server = http.createServer(app);
  await new Promise((resolve) => server.listen(0, resolve));
  const port = server.address().port;

  // Tiny 1x1 test gif base64
  const testBase64 = 'R0lGODlhAQABAIAAAAAAAP///yH5BAEAAAAALAAAAAABAAEAAAIBRAA7';

  const res = await fetch(`http://127.0.0.1:${port}/api/v1/storage/upload`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      filename: 'profile-avatar.jpg',
      base64Data: testBase64,
      contentType: 'image/jpeg',
      userId: 'u-101',
    }),
  });

  const data = await res.json();
  console.log('Response status:', res.status);
  console.log('Response body:', JSON.stringify(data, null, 2));

  server.close();

  if (res.status === 200 && data.success && data.url) {
    console.log('✓ Storage upload endpoint verified successfully!');
  } else {
    throw new Error('Storage upload test failed');
  }
}

testStorageUpload().catch((err) => {
  console.error('Storage test failed:', err);
  process.exit(1);
});

