require('dotenv').config({ path: require('path').join(__dirname, '.env') });
const { put } = require('@vercel/blob');

async function testVercelBlob() {
  console.log('Testing live Vercel Blob upload with provided token...');
  const token = process.env.BLOB_READ_WRITE_TOKEN;
  console.log('Using token:', token ? `${token.substring(0, 20)}...` : 'NONE');

  const dummyImageBuffer = Buffer.from('R0lGODlhAQABAIAAAAAAAP///yH5BAEAAAAALAAAAAABAAEAAAIBRAA7', 'base64');
  const filename = `avatars/test-profile-${Date.now()}.png`;

  try {
    const blob = await put(filename, dummyImageBuffer, {
      access: 'private',
      token,
      contentType: 'image/png',
    });

    console.log('🎉 VERCEL BLOB UPLOAD SUCCEEDED!');
    console.log('Blob URL:', blob.url);
    console.log('Pathname:', blob.pathname);
    console.log('Content Type:', blob.contentType);
  } catch (err) {
    console.error('❌ Vercel Blob error:', err.message);
    process.exit(1);
  }
}

testVercelBlob();
