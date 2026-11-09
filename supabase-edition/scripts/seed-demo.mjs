#!/usr/bin/env node
/**
 * Optional demo content: one approved shelter with a handful of listings.
 *
 *   SUPABASE_URL=... SUPABASE_SERVICE_ROLE_KEY=... node scripts/seed-demo.mjs
 *
 * Everything goes through the API with the service role, so the same triggers
 * and guards that run in production run here too. Idempotent by email.
 */

const SUPABASE_URL = process.env.SUPABASE_URL?.replace(/\/+$/, '');
const SERVICE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY;
const SHELTER_EMAIL = (process.env.DEMO_SHELTER_EMAIL || 'shelter.demo@adoptmatch.test').toLowerCase();
const SHELTER_PASSWORD = process.env.DEMO_SHELTER_PASSWORD || 'DemoShelter!2026';

if (!SUPABASE_URL || !SERVICE_KEY) {
  console.error('SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY are required.');
  process.exit(1);
}

const headers = {
  apikey: SERVICE_KEY,
  Authorization: `Bearer ${SERVICE_KEY}`,
  'Content-Type': 'application/json',
};

async function api(path, init = {}) {
  const response = await fetch(`${SUPABASE_URL}${path}`, { headers, ...init });
  const text = await response.text();
  const body = text ? JSON.parse(text) : null;
  if (!response.ok) {
    throw new Error(`${init.method ?? 'GET'} ${path} → ${response.status}: ${text.slice(0, 200)}`);
  }
  return body;
}

async function ensureShelterUser() {
  const existing = await api(
    `/rest/v1/profiles?select=id,email&email=eq.${encodeURIComponent(SHELTER_EMAIL)}`,
  );
  if (existing.length > 0) return existing[0].id;

  const created = await api('/auth/v1/admin/users', {
    method: 'POST',
    body: JSON.stringify({
      email: SHELTER_EMAIL,
      password: SHELTER_PASSWORD,
      email_confirm: true,
      user_metadata: { full_name: 'Dhaka Paws Rescue' },
    }),
  });
  return created.id;
}

async function ensureShelter(ownerId) {
  const existing = await api(`/rest/v1/shelters?select=id&owner_id=eq.${ownerId}`);
  if (existing.length > 0) return existing[0].id;

  const created = await api('/rest/v1/shelters', {
    method: 'POST',
    headers: { ...headers, Prefer: 'return=representation' },
    body: JSON.stringify({
      owner_id: ownerId,
      name: 'Dhaka Paws Rescue',
      about: 'Foster-based rescue in Mirpur. Home visits on weekends.',
      address: 'Road 12, Mirpur DOHS',
      city: 'Dhaka',
      phone: '+8801700000000',
      email: SHELTER_EMAIL,
      verification_status: 'approved',
      verified_at: new Date().toISOString(),
      rating: 4.6,
    }),
  });
  return created[0].id;
}

async function ensurePets(ownerId, shelterId) {
  const existing = await api(
    `/rest/v1/pets?select=id&owner_id=eq.${ownerId}&limit=1`,
  );
  if (existing.length > 0) {
    console.log('• Demo pets already present, skipping.');
    return;
  }

  const pets = [
    {
      name: 'Mishti', species: 'Cat', breed: 'Deshi', age_months: 14, gender: 'female', size: 'small',
      story: 'Found near a tea stall in Mirpur. Confident, talkative, and extremely fond of laps.',
      medical_history: 'Spayed, vaccinated (TRICAT), dewormed.', is_vaccinated: true, is_neutered: true,
      is_house_trained: true, is_apartment_friendly: true, is_kid_safe: true, city: 'Dhaka',
      latitude: 23.8069, longitude: 90.3687, adoption_status: 'available', moderation_status: 'approved',
    },
    {
      name: 'Raju', species: 'Dog', breed: 'Street mix', age_months: 30, gender: 'male', size: 'medium',
      story: 'Lean, fast and endlessly cheerful. Learns commands in a weekend.',
      medical_history: 'Neutered, anti-rabies given, healthy bloodwork.', is_vaccinated: true, is_neutered: true,
      is_house_trained: true, is_kid_safe: true, city: 'Dhaka',
      latitude: 23.8103, longitude: 90.4125, adoption_status: 'available', moderation_status: 'approved',
      is_urgent: true,
    },
    {
      name: 'Tuktuki', species: 'Bird', breed: 'Budgerigar', age_months: 8, gender: 'unknown', size: 'small',
      story: 'Hand-tamed pair kept in a small cage; needs a bigger flight space.',
      medical_history: 'Avian checkup done, no parasites.', is_vaccinated: false, city: 'Dhaka',
      latitude: 23.7509, longitude: 90.3934, adoption_status: 'foster', moderation_status: 'approved',
    },
  ].map((pet) => ({
    ...pet,
    owner_id: ownerId,
    shelter_id: shelterId,
    contact_phone: '+8801700000000',
    is_active: true,
  }));

  await api('/rest/v1/pets', {
    method: 'POST',
    headers: { ...headers, Prefer: 'return=minimal' },
    body: JSON.stringify(pets),
  });

  console.log(`✔ Inserted ${pets.length} demo listings.`);
}

async function main() {
  const ownerId = await ensureShelterUser();

  // The account signs in as a shelter, so the role must match the listing access.
  await api(`/rest/v1/profiles?id=eq.${ownerId}`, {
    method: 'PATCH',
    body: JSON.stringify({ role: 'shelter', is_verified: true }),
  });

  const shelterId = await ensureShelter(ownerId);
  await ensurePets(ownerId, shelterId);
  console.log(`✔ Demo shelter ready. Sign in as ${SHELTER_EMAIL}`);
}

main().catch((error) => {
  console.error(error.message);
  process.exit(1);
});
