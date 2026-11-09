/**
 * Push notifications through FCM HTTP v1.
 *
 * Staff call it with a user id; the function fans out to that user's registered
 * devices and drops tokens FCM reports as gone. Without a service account the
 * route returns 503 — it never pretends a push was delivered.
 *
 * Route: POST /functions/v1/notify  { user_id, title, body, data? }
 */

import { ApiError, errorResponse, json, preflight, readJson } from '../_shared/http.ts';
import { optional, required } from '../_shared/env.ts';
import { requireStaff, serviceClient } from '../_shared/supabase.ts';

type ServiceAccount = {
  project_id: string;
  client_email: string;
  private_key: string;
};

type PushBody = {
  user_id?: string;
  title?: string;
  body?: string;
  data?: Record<string, string>;
};

let cachedToken: { value: string; expiresAt: number } | null = null;

Deno.serve(async (req: Request): Promise<Response> => {
  const options = preflight(req);
  if (options) return options;

  try {
    if (req.method !== 'POST') throw new ApiError(405, 'METHOD_NOT_ALLOWED', 'Use POST.');

    await requireStaff(req);
    const payload = await readJson<PushBody>(req);

    const userId = String(payload.user_id ?? '').trim();
    const title = String(payload.title ?? '').trim();
    const body = String(payload.body ?? '').trim();

    if (!userId) throw new ApiError(400, 'USER_REQUIRED', 'Which user should receive this?');
    if (!title || !body) throw new ApiError(400, 'CONTENT_REQUIRED', 'A title and body are required.');

    const account = serviceAccount();
    const accessToken = await accessTokenFor(account);

    const { data: tokens, error } = await serviceClient()
      .from('device_tokens')
      .select('token,platform')
      .eq('user_id', userId);

    if (error) throw new ApiError(500, 'TOKENS_UNAVAILABLE', 'Could not read device tokens.');
    if (!tokens || tokens.length === 0) {
      return json({ status: 'success', data: { sent: 0, failed: 0, message: 'No registered devices.' } });
    }

    let sent = 0;
    let failed = 0;

    for (const row of tokens) {
      const result = await sendOne(account, accessToken, String(row.token), title, body, payload.data ?? {});
      if (result.ok) {
        sent += 1;
        await serviceClient()
          .from('device_tokens')
          .update({ last_seen_at: new Date().toISOString() })
          .eq('user_id', userId)
          .eq('token', String(row.token));
      } else {
        failed += 1;
        if (result.gone) {
          await serviceClient()
            .from('device_tokens')
            .delete()
            .eq('user_id', userId)
            .eq('token', String(row.token));
        }
      }
    }

    await serviceClient().from('notifications').insert({
      user_id: userId,
      title,
      body,
      category: 'push',
      data: payload.data ?? {},
    });

    return json({ status: 'success', data: { sent, failed } });
  } catch (error) {
    return errorResponse(error);
  }
});

function serviceAccount(): ServiceAccount {
  const raw = required('FCM_SERVICE_ACCOUNT_JSON');
  let parsed: Partial<ServiceAccount>;
  try {
    parsed = JSON.parse(raw) as Partial<ServiceAccount>;
  } catch {
    throw new ApiError(503, 'NOT_CONFIGURED', 'FCM_SERVICE_ACCOUNT_JSON is not valid JSON.');
  }
  if (!parsed.project_id || !parsed.client_email || !parsed.private_key) {
    throw new ApiError(503, 'NOT_CONFIGURED', 'The FCM service account is missing required fields.');
  }
  return parsed as ServiceAccount;
}

async function accessTokenFor(account: ServiceAccount): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  if (cachedToken && cachedToken.expiresAt - 60 > now) return cachedToken.value;

  const header = b64url(JSON.stringify({ alg: 'RS256', typ: 'JWT' }));
  const claims = b64url(JSON.stringify({
    iss: account.client_email,
    scope: 'https://www.googleapis.com/auth/firebase.messaging',
    aud: 'https://oauth2.googleapis.com/token',
    iat: now,
    exp: now + 3600,
  }));

  const key = await crypto.subtle.importKey(
    'pkcs8',
    pemToArrayBuffer(account.private_key),
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
    false,
    ['sign'],
  );

  const signature = await crypto.subtle.sign(
    'RSASSA-PKCS1-v1_5',
    key,
    new TextEncoder().encode(`${header}.${claims}`),
  );

  const assertion = `${header}.${claims}.${b64url(new Uint8Array(signature))}`;

  const response = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion,
    }).toString(),
  });

  if (!response.ok) {
    console.error('[notify] token exchange failed', await response.text());
    throw new ApiError(502, 'FCM_AUTH_FAILED', 'Google rejected the FCM credentials.');
  }

  const data = await response.json() as { access_token?: string; expires_in?: number };
  if (!data.access_token) throw new ApiError(502, 'FCM_AUTH_FAILED', 'No access token returned.');

  cachedToken = { value: data.access_token, expiresAt: now + (data.expires_in ?? 3600) };
  return cachedToken.value;
}

async function sendOne(
  account: ServiceAccount,
  accessToken: string,
  token: string,
  title: string,
  body: string,
  data: Record<string, string>,
): Promise<{ ok: boolean; gone: boolean }> {
  const response = await fetch(
    `https://fcm.googleapis.com/v1/projects/${account.project_id}/messages:send`,
    {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${accessToken}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        message: {
          token,
          notification: { title, body },
          data,
          android: { priority: 'HIGH' },
          apns: { payload: { aps: { sound: 'default' } } },
        },
      }),
    },
  );

  if (response.ok) return { ok: true, gone: false };

  const detail = await response.text();
  const gone = response.status === 404 || detail.includes('UNREGISTERED') || detail.includes('INVALID_ARGUMENT');
  console.error('[notify] send failed', response.status, detail.slice(0, 200));
  return { ok: false, gone };
}

function pemToArrayBuffer(pem: string): ArrayBuffer {
  const base64 = pem
    .replace(/-----BEGIN PRIVATE KEY-----/, '')
    .replace(/-----END PRIVATE KEY-----/, '')
    .replace(/\s+/g, '');

  const binary = atob(base64);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i += 1) bytes[i] = binary.charCodeAt(i);
  return bytes.buffer;
}

function b64url(input: string | Uint8Array): string {
  const bytes = typeof input === 'string' ? new TextEncoder().encode(input) : input;
  let binary = '';
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
}

// Referenced so a project that forgets the key fails loudly at call time only.
export const notifyConfigured = (): boolean => optional('FCM_SERVICE_ACCOUNT_JSON') !== undefined;
