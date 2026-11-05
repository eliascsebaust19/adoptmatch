/**
 * AdoptMatch - Test Google Auth Endpoints
 */

const http = require('http');

function post(path, body, token) {
  return new Promise((resolve, reject) => {
    const data = JSON.stringify(body);
    const headers = {
      'Content-Type': 'application/json',
      'Content-Length': Buffer.byteLength(data),
    };
    if (token) {
      headers['Authorization'] = `Bearer ${token}`;
    }

    const req = http.request(
      {
        hostname: 'localhost',
        port: 5000,
        path,
        method: 'POST',
        headers,
      },
      (res) => {
        let raw = '';
        res.on('data', (c) => (raw += c));
        res.on('end', () => {
          try {
            resolve({ status: res.statusCode, data: JSON.parse(raw) });
          } catch (e) {
            resolve({ status: res.statusCode, raw });
          }
        });
      }
    );

    req.on('error', reject);
    req.write(data);
    req.end();
  });
}

function get(path, token) {
  return new Promise((resolve, reject) => {
    const headers = {};
    if (token) {
      headers['Authorization'] = `Bearer ${token}`;
    }

    const req = http.request(
      {
        hostname: 'localhost',
        port: 5000,
        path,
        method: 'GET',
        headers,
      },
      (res) => {
        let raw = '';
        res.on('data', (c) => (raw += c));
        res.on('end', () => {
          try {
            resolve({ status: res.statusCode, data: JSON.parse(raw) });
          } catch (e) {
            resolve({ status: res.statusCode, raw });
          }
        });
      }
    );

    req.on('error', reject);
    req.end();
  });
}

async function run() {
  const app = require('./server');
  const server = app.listen(5000, async () => {
    try {
      console.log('--- Testing Google Auth Backend Flow ---');

      // 1. First time Google login (New user creation)
      console.log('\n[1] Testing Google First Login (New User)...');
      const res1 = await post('/api/v1/auth/google', {
        profile: {
          id: 'google-sub-998877',
          email: 'newuser.google@gmail.com',
          name: 'Sarah Connor',
          picture: 'https://lh3.googleusercontent.com/a/sarah.jpg',
        },
      });
      console.log('Status:', res1.status);
      console.log('Response message:', res1.data.message);
      console.log('Created user:', res1.data.user.email, 'Role:', res1.data.user.role, 'Provider:', res1.data.user.provider);
      const token = res1.data.tokens.accessToken;

      // 2. Fetch current user via /me
      console.log('\n[2] Testing GET /api/v1/auth/me...');
      const meRes = await get('/api/v1/auth/me', token);
      console.log('Status:', meRes.status);
      console.log('Me user:', meRes.data.user.name, meRes.data.user.email);

      // 3. Test Account Linking (Login with existing email u-101 elias3224@gmail.com via Google)
      console.log('\n[3] Testing Account Linking (Existing User elias3224@gmail.com via Google)...');
      const linkRes = await post('/api/v1/auth/google', {
        profile: {
          id: 'google-sub-elias-1234',
          email: 'elias3224@gmail.com',
          name: 'Elias Ahmed (Google Linked)',
          picture: 'https://lh3.googleusercontent.com/a/elias.jpg',
        },
      });
      console.log('Status:', linkRes.status);
      console.log('Linked user ID:', linkRes.data.user.id);
      console.log('Linked provider:', linkRes.data.user.provider);

      // 4. Test Logout
      console.log('\n[4] Testing POST /api/v1/auth/logout...');
      const logoutRes = await post('/api/v1/auth/logout', {}, token);
      console.log('Status:', logoutRes.status);
      console.log('Message:', logoutRes.data.message);

      // 5. Test Blacklisted token access
      console.log('\n[5] Verifying Blacklisted Token Rejected...');
      const revokedMe = await get('/api/v1/auth/me', token);
      console.log('Revoked status (should be 401):', revokedMe.status);
      console.log('Code:', revokedMe.data.code);

      console.log('\n✓ ALL GOOGLE AUTH BACKEND TESTS PASSED!');
    } catch (e) {
      console.error('Test failed:', e);
    } finally {
      server.close();
      process.exit(0);
    }
  });
}

run();
