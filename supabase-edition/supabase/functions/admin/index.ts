/**
 * Admin and moderation API.
 *
 * Every route requires a staff role, re-read from `profiles` on each call —
 * the client's claim is not trusted. Mutations are appended to `audit_logs`.
 *
 * Routes (all under /functions/v1/admin):
 *   GET   stats
 *   GET   users?q=&role=&status=&limit=&offset=
 *   PATCH users/{id}                 { role?, status? }
 *   GET   pets?moderation=
 *   PATCH pets/{id}                  { moderation_status?, is_featured?, adoption_status? }
 *   GET   shelters?verification=
 *   PATCH shelters/{id}              { verification_status? }
 *   GET   payments?status=
 *   POST  payments/{tran_id}/approve
 *   POST  payments/{tran_id}/reject  { reason }
 *   GET   audit-logs?limit=
 */

import {
  ApiError,
  errorResponse,
  json,
  preflight,
  readJson,
  routeOf,
} from '../_shared/http.ts';
import { audit, requireStaff, serviceClient, type StaffRole } from '../_shared/supabase.ts';

const ROLES: StaffRole[] = ['moderator', 'admin', 'super_admin'];
const ASSIGNABLE_ROLES = ['adopter', 'foster', 'pet_owner', 'shelter', 'moderator', 'admin', 'super_admin'];
const ACCOUNT_STATES = ['active', 'suspended', 'banned'];
const PET_STATES = ['pending', 'approved', 'rejected', 'flagged'];
const SHELTER_STATES = ['pending', 'approved', 'rejected', 'suspended'];

Deno.serve(async (req: Request): Promise<Response> => {
  const options = preflight(req);
  if (options) return options;

  try {
    const route = routeOf(req, 'admin');
    const [resource, id, action] = route.split('/');
    const method = req.method;
    const url = new URL(req.url);

    if ((method === 'GET' || method === 'POST') && resource === 'stats') return await stats(req);
    if (resource === 'users' && method === 'GET' && !id) return await listUsers(req, url);
    if (resource === 'users' && method === 'PATCH' && id) return await patchUser(req, id);
    if (resource === 'pets' && method === 'GET' && !id) return await listPets(req, url);
    if (resource === 'pets' && method === 'POST' && !id) return await createPet(req);
    if (resource === 'pets' && (method === 'PATCH' || method === 'PUT') && id) return await patchPet(req, id);
    if (resource === 'pets' && method === 'DELETE' && id) return await deletePet(req, id, url);
    if (resource === 'shelters' && method === 'GET' && !id) return await listShelters(req, url);
    if (resource === 'shelters' && method === 'PATCH' && id) return await patchShelter(req, id);
    if (resource === 'payments' && method === 'GET' && !id) return await listPayments(req, url);
    if (resource === 'payments' && method === 'POST' && id && action === 'approve') {
      return await decidePayment(req, id, true);
    }
    if (resource === 'payments' && method === 'POST' && id && action === 'reject') {
      return await decidePayment(req, id, false);
    }
    if (resource === 'audit-logs' && method === 'GET') return await listAudit(req, url);

    throw new ApiError(404, 'NOT_FOUND', `No admin route for ${method} /${route}`);
  } catch (error) {
    return errorResponse(error);
  }
});

async function stats(req: Request): Promise<Response> {
  await requireStaff(req, ROLES);
  const { data, error } = await serviceClient().rpc('admin_dashboard_stats');
  if (error) throw new ApiError(500, 'STATS_UNAVAILABLE', 'Could not compute the dashboard numbers.');
  return json({ status: 'success', data });
}

async function listUsers(req: Request, url: URL): Promise<Response> {
  await requireStaff(req, ROLES);

  const limit = clamp(Number(url.searchParams.get('limit') ?? 50), 1, 200);
  const offset = Math.max(0, Number(url.searchParams.get('offset') ?? 0));
  const role = url.searchParams.get('role');
  const status = url.searchParams.get('status');
  const query = (url.searchParams.get('q') ?? '').trim();

  let builder = serviceClient()
    .from('profiles')
    .select('id,full_name,email,phone,role,status,is_verified,location,created_at', {
      count: 'exact',
    })
    .order('created_at', { ascending: false })
    .range(offset, offset + limit - 1);

  if (role && ASSIGNABLE_ROLES.includes(role)) builder = builder.eq('role', role);
  if (status && ACCOUNT_STATES.includes(status)) builder = builder.eq('status', status);
  if (query) builder = builder.or(`full_name.ilike.%${query}%,email.ilike.%${query}%`);

  const { data, error, count } = await builder;
  if (error) throw new ApiError(500, 'USERS_UNAVAILABLE', 'Could not load users.');

  return json({ status: 'success', data: data ?? [], total: count ?? 0, limit, offset });
}

async function patchUser(req: Request, userId: string): Promise<Response> {
  const actor = await requireStaff(req, ROLES);
  const actorRole = await requireRole(actor.id);
  const body = await readJson<{ role?: string; status?: string; reason?: string }>(req);

  const patch: Record<string, unknown> = {};

  if (body.role !== undefined) {
    if (!ASSIGNABLE_ROLES.includes(body.role)) {
      throw new ApiError(400, 'INVALID_ROLE', 'That role does not exist.');
    }
    // Only a super admin may hand out (or take back) staff roles.
    const touchesStaff = ['moderator', 'admin', 'super_admin'].includes(body.role);
    if (touchesStaff && actorRole !== 'super_admin') {
      throw new ApiError(403, 'FORBIDDEN', 'Only a super admin can change staff roles.');
    }
    patch.role = body.role;
  }

  if (body.status !== undefined) {
    if (!ACCOUNT_STATES.includes(body.status)) {
      throw new ApiError(400, 'INVALID_STATUS', 'Unknown account status.');
    }
    patch.status = body.status;
  }

  if (Object.keys(patch).length === 0) {
    throw new ApiError(400, 'NOTHING_TO_UPDATE', 'Send a role or a status.');
  }

  const { error } = await serviceClient().from('profiles').update(patch).eq('id', userId);
  if (error) throw new ApiError(500, 'USER_UPDATE_FAILED', 'Could not update this account.');

  if (patch.status === 'banned' || patch.status === 'suspended') {
    // Blocks new sign-ins immediately. Existing access tokens stay valid until
    // they expire (one hour by default), so the ban is not instant for a session
    // that is already open.
    const { error: banError } = await serviceClient().auth.admin.updateUserById(userId, {
      ban_duration: '876000h',
    });
    if (banError) console.error('[admin] auth ban failed', banError);
  } else if (patch.status === 'active') {
    const { error: unbanError } = await serviceClient().auth.admin.updateUserById(userId, {
      ban_duration: 'none',
    });
    if (unbanError) console.error('[admin] auth unban failed', unbanError);
  }

  await audit(actor.id, 'user.update', 'profiles', userId, patch);
  return json({ status: 'success', data: { id: userId, ...patch } });
}

async function listPets(req: Request, url: URL): Promise<Response> {
  await requireStaff(req, ROLES);
  const limit = clamp(Number(url.searchParams.get('limit') ?? 50), 1, 200);
  const moderation = url.searchParams.get('moderation');

  let builder = serviceClient()
    .from('pets')
    .select('id,name,species,breed,owner_id,shelter_id,adoption_status,moderation_status,is_featured,is_active,created_at')
    .order('created_at', { ascending: false })
    .limit(limit);

  if (moderation && PET_STATES.includes(moderation)) builder = builder.eq('moderation_status', moderation);

  const { data, error } = await builder;
  if (error) throw new ApiError(500, 'PETS_UNAVAILABLE', 'Could not load listings.');
  return json({ status: 'success', data: data ?? [] });
}

async function createPet(req: Request): Promise<Response> {
  const actor = await requireStaff(req, ROLES);
  const body = await readJson<Record<string, unknown>>(req);
  const name = typeof body.name === 'string' ? body.name.trim() : '';
  const species = typeof body.species === 'string' ? body.species.trim() : '';
  if (!name || !species) {
    throw new ApiError(400, 'INVALID_PET', 'Name and species are required.');
  }

  const rawGender = typeof body.gender === 'string' ? body.gender.toLowerCase().trim() : 'unknown';
  const gender = rawGender === 'male' || rawGender === 'female' ? rawGender : 'unknown';

  const insertPayload: Record<string, unknown> = {
    owner_id: actor.id,
    name,
    species,
    breed: typeof body.breed === 'string' && body.breed.trim() ? body.breed.trim() : 'Mixed',
    age_months: typeof body.age_months === 'number' && body.age_months >= 0 ? body.age_months : 12,
    gender,
    weight_kg: typeof body.weight_kg === 'number' ? body.weight_kg : null,
    story: typeof body.story === 'string' ? body.story : '',
    medical_history: typeof body.medical_history === 'string' ? body.medical_history : '',
    image_url: typeof body.image_url === 'string' ? body.image_url : null,
    is_vaccinated: Boolean(body.is_vaccinated),
    is_neutered: Boolean(body.is_neutered),
    is_house_trained: Boolean(body.is_house_trained),
    is_kid_safe: Boolean(body.is_kid_safe),
    is_apartment_friendly: Boolean(body.is_apartment_friendly),
    is_urgent: Boolean(body.is_urgent),
    is_featured: Boolean(body.is_featured),
    moderation_status: 'approved',
    adoption_status: 'available',
  };

  const { data, error } = await serviceClient().from('pets').insert(insertPayload).select().single();
  if (error || !data) throw new ApiError(500, 'PET_CREATE_FAILED', 'Could not create this listing.');

  const gallery = Array.isArray(body.gallery_urls)
    ? body.gallery_urls.filter((u): u is string => typeof u === 'string' && u.length > 0)
    : [];
  if (gallery.length > 0) {
    const rows = gallery.map((url, idx) => ({ pet_id: data.id, url, sort_order: idx }));
    await serviceClient().from('pet_images').insert(rows);
  }

  await audit(actor.id, 'pet.create', 'pets', String(data.id), { name, species });
  return json({ status: 'success', data });
}

async function patchPet(req: Request, petId: string): Promise<Response> {
  const actor = await requireStaff(req, ROLES);
  const body = await readJson<{
    moderation_status?: string;
    is_featured?: boolean;
    is_active?: boolean;
    is_urgent?: boolean;
    is_vaccinated?: boolean;
    is_neutered?: boolean;
    is_house_trained?: boolean;
    is_kid_safe?: boolean;
    is_apartment_friendly?: boolean;
    adoption_status?: string;
    name?: string;
    species?: string;
    breed?: string;
    age_months?: number;
    gender?: string;
    weight_kg?: number;
    story?: string;
    medical_history?: string;
    image_url?: string;
    gallery_urls?: string[];
    reason?: string;
  }>(req);

  const patch: Record<string, unknown> = {};
  if (body.moderation_status !== undefined) {
    if (!PET_STATES.includes(body.moderation_status)) {
      throw new ApiError(400, 'INVALID_STATUS', 'Unknown moderation status.');
    }
    patch.moderation_status = body.moderation_status;
  }
  if (body.adoption_status !== undefined) {
    if (!['available', 'foster', 'pending', 'adopted', 'archived'].includes(body.adoption_status)) {
      throw new ApiError(400, 'INVALID_STATUS', 'Unknown adoption status.');
    }
    patch.adoption_status = body.adoption_status;
  }
  if (body.name !== undefined) patch.name = body.name;
  if (body.species !== undefined) patch.species = body.species;
  if (body.breed !== undefined) patch.breed = body.breed;
  if (body.age_months !== undefined) patch.age_months = body.age_months;
  if (body.gender !== undefined) {
    const g = body.gender.toLowerCase().trim();
    patch.gender = g === 'male' || g === 'female' ? g : 'unknown';
  }
  if (body.weight_kg !== undefined) patch.weight_kg = body.weight_kg;
  if (body.story !== undefined) patch.story = body.story;
  if (body.medical_history !== undefined) patch.medical_history = body.medical_history;
  if (body.image_url !== undefined) patch.image_url = body.image_url;
  if (body.is_featured !== undefined) patch.is_featured = Boolean(body.is_featured);
  if (body.is_active !== undefined) patch.is_active = Boolean(body.is_active);
  if (body.is_urgent !== undefined) patch.is_urgent = Boolean(body.is_urgent);
  if (body.is_vaccinated !== undefined) patch.is_vaccinated = Boolean(body.is_vaccinated);
  if (body.is_neutered !== undefined) patch.is_neutered = Boolean(body.is_neutered);
  if (body.is_house_trained !== undefined) patch.is_house_trained = Boolean(body.is_house_trained);
  if (body.is_kid_safe !== undefined) patch.is_kid_safe = Boolean(body.is_kid_safe);
  if (body.is_apartment_friendly !== undefined) patch.is_apartment_friendly = Boolean(body.is_apartment_friendly);

  if (Object.keys(patch).length === 0) {
    throw new ApiError(400, 'NOTHING_TO_UPDATE', 'Send at least one field to change.');
  }

  const { data, error } = await serviceClient().from('pets').update(patch).eq('id', petId).select().maybeSingle();
  if (error || !data) throw new ApiError(500, 'PET_UPDATE_FAILED', 'Could not update this listing.');

  if (Array.isArray(body.gallery_urls) && body.gallery_urls.length > 0) {
    await serviceClient().from('pet_images').delete().eq('pet_id', petId);
    const rows = body.gallery_urls.map((url, idx) => ({ pet_id: petId, url, sort_order: idx }));
    await serviceClient().from('pet_images').insert(rows);
  }

  await audit(actor.id, 'pet.moderate', 'pets', petId, { ...patch, reason: body.reason ?? null });
  return json({ status: 'success', data });
}

async function deletePet(req: Request, petId: string, url: URL): Promise<Response> {
  const actor = await requireStaff(req, ROLES);
  const soft = url.searchParams.get('soft') === 'true';

  if (soft) {
    const { data, error } = await serviceClient()
      .from('pets')
      .update({ adoption_status: 'archived', is_active: false })
      .eq('id', petId)
      .select()
      .maybeSingle();
    if (error || !data) throw new ApiError(500, 'PET_ARCHIVE_FAILED', 'Could not archive this listing.');
    await audit(actor.id, 'pet.archive', 'pets', petId, {});
    return json({ status: 'success', data });
  }

  const { error } = await serviceClient().from('pets').delete().eq('id', petId);
  if (error) throw new ApiError(500, 'PET_DELETE_FAILED', 'Could not delete this listing.');
  await audit(actor.id, 'pet.delete', 'pets', petId, {});
  return json({ status: 'success', data: { id: petId, deleted: true } });
}

async function listShelters(req: Request, url: URL): Promise<Response> {
  await requireStaff(req, ROLES);
  const verification = url.searchParams.get('verification');

  let builder = serviceClient()
    .from('shelters')
    .select('id,name,owner_id,city,phone,verification_status,rating,created_at')
    .order('created_at', { ascending: false })
    .limit(200);

  if (verification && SHELTER_STATES.includes(verification)) {
    builder = builder.eq('verification_status', verification);
  }

  const { data, error } = await builder;
  if (error) throw new ApiError(500, 'SHELTERS_UNAVAILABLE', 'Could not load shelters.');
  return json({ status: 'success', data: data ?? [] });
}

async function patchShelter(req: Request, shelterId: string): Promise<Response> {
  const actor = await requireStaff(req, ROLES);
  const body = await readJson<{ verification_status?: string; reason?: string }>(req);

  if (!body.verification_status || !SHELTER_STATES.includes(body.verification_status)) {
    throw new ApiError(400, 'INVALID_STATUS', 'Send a valid verification status.');
  }

  const patch = {
    verification_status: body.verification_status,
    verified_at: body.verification_status === 'approved' ? new Date().toISOString() : null,
  };

  const { error } = await serviceClient().from('shelters').update(patch).eq('id', shelterId);
  if (error) throw new ApiError(500, 'SHELTER_UPDATE_FAILED', 'Could not update this shelter.');

  await audit(actor.id, 'shelter.verify', 'shelters', shelterId, {
    ...patch,
    reason: body.reason ?? null,
  });
  return json({ status: 'success', data: { id: shelterId, ...patch } });
}

async function listPayments(req: Request, url: URL): Promise<Response> {
  await requireStaff(req, ['admin', 'super_admin']);
  const status = url.searchParams.get('status');

  let builder = serviceClient()
    .from('payments')
    .select('tran_id,user_id,plan_id,amount,currency,method,status,trx_id,sender_phone,created_at,verified_at')
    .order('created_at', { ascending: false })
    .limit(200);

  if (status && ['pending', 'paid', 'failed', 'cancelled', 'refunded', 'disputed'].includes(status)) {
    builder = builder.eq('status', status);
  }

  const { data, error } = await builder;
  if (error) throw new ApiError(500, 'PAYMENTS_UNAVAILABLE', 'Could not load payments.');
  return json({ status: 'success', data: data ?? [] });
}

async function decidePayment(req: Request, tranId: string, approve: boolean): Promise<Response> {
  const actor = await requireStaff(req, ['admin', 'super_admin']);
  const sb = serviceClient();
  const body = approve ? {} : await readJson<{ reason?: string }>(req).catch(() => ({}));

  if (approve) {
    const { data, error } = await sb
      .from('payments')
      .update({ status: 'paid', verified_at: new Date().toISOString(), verified_by: actor.id })
      .eq('tran_id', tranId)
      .eq('method', 'bkash_manual')
      .eq('status', 'pending')
      .select('id')
      .maybeSingle();

    if (error) throw new ApiError(500, 'PAYMENT_UPDATE_FAILED', 'Could not approve this payment.');
    if (!data) {
      throw new ApiError(409, 'PAYMENT_NOT_PENDING', 'That payment is not awaiting review.');
    }

    const { error: rpcError } = await sb.rpc('apply_paid_payment', { p_tran_id: tranId });
    if (rpcError) {
      throw new ApiError(500, 'ENTITLEMENT_FAILED', 'Marked paid, but the subscription could not be applied.');
    }

    await audit(actor.id, 'payment.approve', 'payments', tranId);
    return json({ status: 'success', data: { tran_id: tranId, status: 'paid' } });
  }

  const reason = String(body.reason ?? '').trim();
  if (reason.length < 4) {
    throw new ApiError(400, 'REASON_REQUIRED', 'Say why this payment is rejected.');
  }

  const { data, error } = await sb
    .from('payments')
    .update({ status: 'failed', failure_reason: reason.slice(0, 240) })
    .eq('tran_id', tranId)
    .in('status', ['pending', 'processing'])
    .select('id')
    .maybeSingle();

  if (error) throw new ApiError(500, 'PAYMENT_UPDATE_FAILED', 'Could not reject this payment.');
  if (!data) throw new ApiError(409, 'PAYMENT_NOT_PENDING', 'That payment is not awaiting review.');

  await audit(actor.id, 'payment.reject', 'payments', tranId, { reason });
  return json({ status: 'success', data: { tran_id: tranId, status: 'failed' } });
}

async function listAudit(req: Request, url: URL): Promise<Response> {
  await requireStaff(req, ROLES);
  const limit = clamp(Number(url.searchParams.get('limit') ?? 100), 1, 500);

  const { data, error } = await serviceClient()
    .from('audit_logs')
    .select('id,actor_id,actor_email,action,target_table,target_id,metadata,created_at')
    .order('created_at', { ascending: false })
    .limit(limit);

  if (error) throw new ApiError(500, 'AUDIT_UNAVAILABLE', 'Could not load the audit trail.');
  return json({ status: 'success', data: data ?? [] });
}

async function requireRole(userId: string): Promise<string> {
  const { data, error } = await serviceClient()
    .from('profiles')
    .select('role')
    .eq('id', userId)
    .maybeSingle();

  if (error) throw new ApiError(500, 'PROFILE_LOOKUP_FAILED', 'Could not read the account role.');
  return String(data?.role ?? 'adopter');
}

function clamp(value: number, min: number, max: number): number {
  if (!Number.isFinite(value)) return min;
  return Math.min(Math.max(Math.trunc(value), min), max);
}
