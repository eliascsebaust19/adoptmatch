import { createClient, type SupabaseClient, type User } from 'npm:@supabase/supabase-js@2';
import { ApiError } from './http.ts';
import { required, supabaseUrl } from './env.ts';

export type StaffRole = 'moderator' | 'admin' | 'super_admin';

let cached: SupabaseClient | null = null;

/**
 * Service-role client. Bypasses RLS, so it is only used after the caller has been
 * authenticated and authorised by the helpers below.
 */
export function serviceClient(): SupabaseClient {
  if (cached) return cached;
  cached = createClient(supabaseUrl(), required('SUPABASE_SERVICE_ROLE_KEY'), {
    auth: { persistSession: false, autoRefreshToken: false },
    global: { headers: { 'X-Client-Info': 'adoptmatch-edge-functions' } },
  });
  return cached;
}

export function bearerToken(req: Request): string | null {
  const header = req.headers.get('Authorization') ?? req.headers.get('authorization') ?? '';
  const match = header.match(/^Bearer\s+(.+)$/i);
  return match ? match[1].trim() : null;
}

export async function requireUser(req: Request): Promise<User> {
  const token = bearerToken(req);
  if (!token) throw new ApiError(401, 'SIGNED_OUT', 'Sign in to continue.');

  const { data, error } = await serviceClient().auth.getUser(token);
  if (error || !data.user) {
    throw new ApiError(401, 'SIGNED_OUT', 'Your session has expired. Sign in again.');
  }
  return data.user;
}

export async function roleOf(userId: string): Promise<string | null> {
  const { data, error } = await serviceClient()
    .from('profiles')
    .select('role')
    .eq('id', userId)
    .maybeSingle();

  if (error) throw new ApiError(500, 'PROFILE_LOOKUP_FAILED', 'Could not read the account role.');
  return (data?.role as string | undefined) ?? null;
}

export async function requireStaff(
  req: Request,
  allowed: StaffRole[] = ['moderator', 'admin', 'super_admin'],
): Promise<User> {
  const user = await requireUser(req);
  const role = await roleOf(user.id);
  if (!role || !allowed.includes(role as StaffRole)) {
    throw new ApiError(403, 'FORBIDDEN', 'Staff access required.');
  }
  return user;
}

export async function audit(
  actorId: string,
  action: string,
  targetTable?: string,
  targetId?: string,
  metadata: Record<string, unknown> = {},
): Promise<void> {
  const { error } = await serviceClient().rpc('log_audit', {
    p_actor_id: actorId,
    p_action: action,
    p_target_table: targetTable ?? null,
    p_target_id: targetId ?? null,
    p_metadata: metadata,
  });
  if (error) console.error('[audit] write failed', error);
}
