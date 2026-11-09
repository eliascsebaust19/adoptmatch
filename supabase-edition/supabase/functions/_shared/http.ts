export const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'GET, POST, PATCH, OPTIONS',
};

/**
 * A failure the client is allowed to see. Anything else becomes a generic 500 so
 * internal details never leak into a response body.
 */
export class ApiError extends Error {
  readonly status: number;
  readonly code: string;

  constructor(status: number, code: string, message: string) {
    super(message);
    this.name = 'ApiError';
    this.status = status;
    this.code = code;
  }
}

export function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json; charset=utf-8' },
  });
}

export function text(body: string, status = 200): Response {
  return new Response(body, {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'text/plain; charset=utf-8' },
  });
}

export function redirectTo(location: string, status = 303): Response {
  return new Response(null, { status, headers: { ...corsHeaders, Location: location } });
}

export function preflight(req: Request): Response | null {
  return req.method === 'OPTIONS' ? new Response('ok', { headers: corsHeaders }) : null;
}

export async function readJson<T>(req: Request): Promise<T> {
  const raw = await req.text();
  if (!raw) throw new ApiError(400, 'EMPTY_BODY', 'A JSON body is required.');
  try {
    return JSON.parse(raw) as T;
  } catch {
    throw new ApiError(400, 'INVALID_JSON', 'The request body is not valid JSON.');
  }
}

export async function readForm(req: Request): Promise<URLSearchParams> {
  const raw = await req.text();
  return new URLSearchParams(raw);
}

export function errorResponse(error: unknown): Response {
  if (error instanceof ApiError) {
    return json({ status: 'error', code: error.code, message: error.message }, error.status);
  }
  console.error('[unhandled]', error);
  return json(
    { status: 'error', code: 'INTERNAL', message: 'The server could not complete this request.' },
    500,
  );
}

/** Last path segment, used for the tiny routers in these functions. */
export function tail(pathname: string): string {
  const parts = pathname.split('/').filter(Boolean);
  return parts.length > 0 ? parts[parts.length - 1] : '';
}

/** Path without the function prefix, e.g. `admin/users/abc` → `users/abc`. */
export function routeOf(req: Request, functionName: string): string {
  const url = new URL(req.url);
  let path = url.pathname;
  const longMarker = `/functions/v1/${functionName}`;
  if (path.startsWith(longMarker)) {
    path = path.slice(longMarker.length);
  } else if (path.startsWith(`/${functionName}`)) {
    path = path.slice(functionName.length + 1);
  }
  return path.replace(/^\/+/, '');
}
