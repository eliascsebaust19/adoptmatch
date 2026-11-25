#!/usr/bin/env node
/**
 * Seeds all 23 catalog pets from Flutter PetRepository into Supabase database.
 * Run with SUPABASE_SERVICE_ROLE_KEY.
 */

const SUPABASE_URL = process.env.SUPABASE_URL || 'https://wgztdhabgedhkaippkpd.supabase.co';
const SERVICE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY || 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6IndnenRkaGFiZ2VkaGthaXBwa3BkIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc5Mjc4MDMxOSwiZXhwIjoyMTA4MzU2MzE5fQ.0B-B7dkoY9HbpSfpwkVHLzGoP_qBT8_akSjnBJydqQM';

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
    throw new Error(`${init.method ?? 'GET'} ${path} → ${response.status}: ${text.slice(0, 300)}`);
  }
  return body;
}

const CATALOG_PETS = [
  {
    name: 'Luna',
    species: 'Dog',
    breed: 'Lab Mix',
    age_months: 24,
    gender: 'female',
    weight_kg: 18.5,
    size: 'medium',
    story: 'Luna was found near Dhanmondi Lake and nurtured by loving volunteers. She is gentle, loves belly rubs, and is completely house-trained and kid-friendly!',
    medical_history: 'DHPP Core Vaccines (Done Dec 2025), Rabies booster due Nov 2026, Dewormed monthly.',
    vaccination_status: 'fully_vaccinated',
    is_vaccinated: true,
    is_neutered: true,
    is_house_trained: true,
    is_kid_safe: true,
    is_apartment_friendly: true,
    is_urgent: false,
    is_foster: false,
    image_url: 'https://images.unsplash.com/photo-1552053831-71594a27632d?auto=format&fit=crop&w=800&q=80',
    gallery: [
      'https://images.unsplash.com/photo-1552053831-71594a27632d?auto=format&fit=crop&w=800&q=80',
      'https://images.unsplash.com/photo-1537151625747-768eb6cf92b2?auto=format&fit=crop&w=800&q=80',
      'https://images.unsplash.com/photo-1583511655857-d19b40a7a54e?auto=format&fit=crop&w=800&q=80'
    ],
    qr_hash: 'ADOPT-PET-LUNA-DHAKA-2026-X99',
    city: 'Dhaka',
    latitude: 23.7465,
    longitude: 90.3760,
  },
  {
    name: 'Mochi',
    species: 'Cat',
    breed: 'Calico',
    age_months: 12,
    gender: 'female',
    weight_kg: 3.8,
    size: 'small',
    story: 'Mochi is a calm and affectionate calico cat who enjoys sunny windowsills and quiet lap naps. Ideal for apartment living.',
    medical_history: 'FVRCP Triple Vaccine up-to-date, Rabies vaccinated, negative for FeLV/FIV.',
    vaccination_status: 'fully_vaccinated',
    is_vaccinated: true,
    is_neutered: true,
    is_house_trained: true,
    is_kid_safe: true,
    is_apartment_friendly: true,
    is_urgent: false,
    is_foster: true,
    image_url: 'https://images.unsplash.com/photo-1514888286974-6c03e2ca1dba?auto=format&fit=crop&w=800&q=80',
    gallery: [
      'https://images.unsplash.com/photo-1514888286974-6c03e2ca1dba?auto=format&fit=crop&w=800&q=80',
      'https://images.unsplash.com/photo-1573865526739-10659fec78a5?auto=format&fit=crop&w=800&q=80'
    ],
    qr_hash: 'ADOPT-PET-MOCHI-GULSHAN-2026-M44',
    city: 'Dhaka',
    latitude: 23.7925,
    longitude: 90.4078,
  },
  {
    name: 'Cooper',
    species: 'Dog',
    breed: 'Golden Retriever',
    age_months: 6,
    gender: 'male',
    weight_kg: 14.2,
    size: 'medium',
    story: 'Cooper is an energetic pup with a heart of gold. He loves running around and playing fetch with kids.',
    medical_history: 'Puppy core vaccination course completed, next booster due July 2026.',
    vaccination_status: 'fully_vaccinated',
    is_vaccinated: true,
    is_neutered: false,
    is_house_trained: false,
    is_kid_safe: true,
    is_apartment_friendly: false,
    is_urgent: false,
    is_foster: false,
    image_url: 'https://images.unsplash.com/photo-1558788353-f76d92427f16?auto=format&fit=crop&w=800&q=80',
    gallery: [
      'https://images.unsplash.com/photo-1558788353-f76d92427f16?auto=format&fit=crop&w=800&q=80',
      'https://images.unsplash.com/photo-1530281700549-e82e7bf110d6?auto=format&fit=crop&w=800&q=80'
    ],
    qr_hash: 'ADOPT-PET-COOPER-UTTARA-2026-C88',
    city: 'Dhaka',
    latitude: 23.8759,
    longitude: 90.3795,
  },
  {
    name: 'Sage',
    species: 'Cat',
    breed: 'Grey Tabby',
    age_months: 36,
    gender: 'male',
    weight_kg: 4.5,
    size: 'small',
    story: 'Sage is an independent thinker who enjoys peaceful environments and bird watching from balconies.',
    medical_history: 'Fully immunized, microchip ID #BD99281747.',
    vaccination_status: 'fully_vaccinated',
    is_vaccinated: true,
    is_neutered: true,
    is_house_trained: true,
    is_kid_safe: false,
    is_apartment_friendly: true,
    is_urgent: false,
    is_foster: false,
    image_url: 'https://images.unsplash.com/photo-1574158622682-e40e69881006?auto=format&fit=crop&w=800&q=80',
    gallery: [
      'https://images.unsplash.com/photo-1574158622682-e40e69881006?auto=format&fit=crop&w=800&q=80'
    ],
    qr_hash: 'ADOPT-PET-SAGE-DHANMONDI-2026-S12',
    city: 'Dhaka',
    latitude: 23.7461,
    longitude: 90.3742,
  },
  {
    name: 'Gizmo',
    species: 'Dog',
    breed: 'French Bulldog',
    age_months: 48,
    gender: 'male',
    weight_kg: 12.0,
    size: 'small',
    story: 'Gizmo is a couch potato at heart! He loves short walks, snacking on carrots, and snoozing next to his human.',
    medical_history: 'All seasonal boosters up-to-date, allergy-screened hypoallergenic diet.',
    vaccination_status: 'fully_vaccinated',
    is_vaccinated: true,
    is_neutered: true,
    is_house_trained: true,
    is_kid_safe: true,
    is_apartment_friendly: true,
    is_urgent: false,
    is_foster: false,
    image_url: 'https://images.unsplash.com/photo-1583511655857-d19b40a7a54e?auto=format&fit=crop&w=800&q=80',
    gallery: [
      'https://images.unsplash.com/photo-1583511655857-d19b40a7a54e?auto=format&fit=crop&w=800&q=80'
    ],
    qr_hash: 'ADOPT-PET-GIZMO-BANANI-2026-G55',
    city: 'Dhaka',
    latitude: 23.7937,
    longitude: 90.4066,
  },
  {
    name: 'Peach',
    species: 'Cat',
    breed: 'Orange Tabby',
    age_months: 24,
    gender: 'female',
    weight_kg: 3.5,
    size: 'small',
    story: 'Sweet Peach is a chatterbox who purrs the moment you walk into the room. Loves feathers and catnip toys.',
    medical_history: 'All vaccinations verified, spayed, microchipped.',
    vaccination_status: 'fully_vaccinated',
    is_vaccinated: true,
    is_neutered: true,
    is_house_trained: true,
    is_kid_safe: true,
    is_apartment_friendly: true,
    is_urgent: false,
    is_foster: false,
    image_url: 'https://images.unsplash.com/photo-1533738363-b7f9aef128ce?auto=format&fit=crop&w=800&q=80',
    gallery: [
      'https://images.unsplash.com/photo-1533738363-b7f9aef128ce?auto=format&fit=crop&w=800&q=80'
    ],
    qr_hash: 'ADOPT-PET-PEACH-GULSHAN-2026-P33',
    city: 'Dhaka',
    latitude: 23.7925,
    longitude: 90.4078,
  },
  {
    name: 'Daisy',
    species: 'Dog',
    breed: 'Beagle Mix',
    age_months: 12,
    gender: 'female',
    weight_kg: 10.5,
    size: 'medium',
    story: 'Daisy has an inquisitive nose and a joyful spirit. She loves sniffing games and long park walks.',
    medical_history: 'Rabies vaccine valid until March 2027.',
    vaccination_status: 'fully_vaccinated',
    is_vaccinated: true,
    is_neutered: true,
    is_house_trained: true,
    is_kid_safe: true,
    is_apartment_friendly: true,
    is_urgent: false,
    is_foster: true,
    image_url: 'https://images.unsplash.com/photo-1505628346881-b72b27e84530?auto=format&fit=crop&w=800&q=80',
    gallery: [
      'https://images.unsplash.com/photo-1505628346881-b72b27e84530?auto=format&fit=crop&w=800&q=80'
    ],
    qr_hash: 'ADOPT-PET-DAISY-MIRPUR-2026-D22',
    city: 'Dhaka',
    latitude: 23.8069,
    longitude: 90.3687,
  },
  {
    name: 'Onyx',
    species: 'Cat',
    breed: 'British Shorthair',
    age_months: 60,
    gender: 'male',
    weight_kg: 5.2,
    size: 'small',
    story: 'Onyx is a regal gentleman with stunning plush coat. He is very tranquil and gets along with other felines.',
    medical_history: 'Senior health screening passed with flying colors.',
    vaccination_status: 'fully_vaccinated',
    is_vaccinated: true,
    is_neutered: true,
    is_house_trained: true,
    is_kid_safe: true,
    is_apartment_friendly: true,
    is_urgent: false,
    is_foster: false,
    image_url: 'https://images.unsplash.com/photo-1518791841217-8f162f1e1131?auto=format&fit=crop&w=800&q=80',
    gallery: [
      'https://images.unsplash.com/photo-1518791841217-8f162f1e1131?auto=format&fit=crop&w=800&q=80'
    ],
    qr_hash: 'ADOPT-PET-ONYX-UTTARA-2026-O77',
    city: 'Dhaka',
    latitude: 23.8680,
    longitude: 90.3950,
  },
  {
    name: 'Bella',
    species: 'Dog',
    breed: 'Poodle Mix',
    age_months: 36,
    gender: 'female',
    weight_kg: 8.0,
    size: 'small',
    story: 'Bella is hypoallergenic, very intelligent, knows 8 voice commands, and gives the sweetest cuddles.',
    medical_history: 'Vaccinated and dental cleaning performed Jan 2026.',
    vaccination_status: 'fully_vaccinated',
    is_vaccinated: true,
    is_neutered: true,
    is_house_trained: true,
    is_kid_safe: true,
    is_apartment_friendly: true,
    is_urgent: false,
    is_foster: false,
    image_url: 'https://images.unsplash.com/photo-1516734212186-a967f81ad0d7?auto=format&fit=crop&w=800&q=80',
    gallery: [
      'https://images.unsplash.com/photo-1516734212186-a967f81ad0d7?auto=format&fit=crop&w=800&q=80'
    ],
    qr_hash: 'ADOPT-PET-BELLA-DHANMONDI-2026-B81',
    city: 'Dhaka',
    latitude: 23.7465,
    longitude: 90.3760,
  },
  {
    name: 'Jasper',
    species: 'Cat',
    breed: 'Siamese',
    age_months: 24,
    gender: 'male',
    weight_kg: 4.0,
    size: 'small',
    story: 'Jasper has mesmerizing sapphire eyes and vocal charm. He greets you enthusiastically at the door.',
    medical_history: 'Complete vaccination records documented.',
    vaccination_status: 'fully_vaccinated',
    is_vaccinated: true,
    is_neutered: true,
    is_house_trained: true,
    is_kid_safe: true,
    is_apartment_friendly: true,
    is_urgent: false,
    is_foster: false,
    image_url: 'https://images.unsplash.com/photo-1561948955-570b270e7c36?auto=format&fit=crop&w=800&q=80',
    gallery: [
      'https://images.unsplash.com/photo-1561948955-570b270e7c36?auto=format&fit=crop&w=800&q=80'
    ],
    qr_hash: 'ADOPT-PET-JASPER-GULSHAN-2026-J19',
    city: 'Dhaka',
    latitude: 23.7925,
    longitude: 90.4078,
  },
  {
    name: 'Max',
    species: 'Dog',
    breed: 'Golden Retriever',
    age_months: 18,
    gender: 'male',
    weight_kg: 22.0,
    size: 'large',
    story: 'Max is looking for an active family with a yard. He is obedient, leash-trained, and extremely friendly.',
    medical_history: 'Full vaccination certificate issued by Central Vet Hospital.',
    vaccination_status: 'fully_vaccinated',
    is_vaccinated: true,
    is_neutered: true,
    is_house_trained: true,
    is_kid_safe: true,
    is_apartment_friendly: false,
    is_urgent: true,
    is_foster: false,
    image_url: 'https://images.unsplash.com/photo-1552053831-71594a27632d?auto=format&fit=crop&w=800&q=80',
    gallery: [
      'https://images.unsplash.com/photo-1552053831-71594a27632d?auto=format&fit=crop&w=800&q=80'
    ],
    qr_hash: 'ADOPT-PET-MAX-BASHUNDHARA-2026-M01',
    city: 'Dhaka',
    latitude: 23.8191,
    longitude: 90.4526,
  },
  {
    name: 'Charlie',
    species: 'Bird',
    breed: 'Parakeet',
    age_months: 12,
    gender: 'male',
    weight_kg: 0.1,
    size: 'small',
    story: 'Charlie sings cheerful melodies and whistles tunes. Very gentle and loves perching on shoulders.',
    medical_history: 'Avian health checkup done Dec 2025.',
    vaccination_status: 'fully_vaccinated',
    is_vaccinated: true,
    is_neutered: false,
    is_house_trained: true,
    is_kid_safe: true,
    is_apartment_friendly: true,
    is_urgent: false,
    is_foster: false,
    image_url: 'https://images.unsplash.com/photo-1552728089-57bdde30beb3?auto=format&fit=crop&w=800&q=80',
    gallery: [
      'https://images.unsplash.com/photo-1552728089-57bdde30beb3?auto=format&fit=crop&w=800&q=80'
    ],
    qr_hash: 'ADOPT-PET-CHARLIE-TEJGAON-2026-C11',
    city: 'Dhaka',
    latitude: 23.7599,
    longitude: 90.3920,
  },
  {
    name: 'Pip',
    species: 'Rabbit',
    breed: 'Holland Lop Bunny',
    age_months: 8,
    gender: 'female',
    weight_kg: 1.4,
    size: 'small',
    story: 'Pip has floppy ears and loves nibbling on fresh hay and parsley. Litter-box trained and very gentle.',
    medical_history: 'RHDV2 vaccination current, spayed.',
    vaccination_status: 'fully_vaccinated',
    is_vaccinated: true,
    is_neutered: true,
    is_house_trained: true,
    is_kid_safe: true,
    is_apartment_friendly: true,
    is_urgent: false,
    is_foster: false,
    image_url: 'https://images.unsplash.com/photo-1585110396000-c9ffd4e4b308?auto=format&fit=crop&w=800&q=80',
    gallery: [
      'https://images.unsplash.com/photo-1585110396000-c9ffd4e4b308?auto=format&fit=crop&w=800&q=80'
    ],
    qr_hash: 'ADOPT-PET-PIP-GULSHAN-2026-P02',
    city: 'Dhaka',
    latitude: 23.7925,
    longitude: 90.4078,
  },
  {
    name: 'Barnaby',
    species: 'Dog',
    breed: 'Basset Hound (Senior)',
    age_months: 108,
    gender: 'male',
    weight_kg: 24.0,
    size: 'medium',
    story: 'Barnaby is a wise, sleepy sweetheart waiting for a quiet retirement home. He loves short sniffs and long snoozes.',
    medical_history: 'Arthritis managed with glucosamine treats, heart and liver panels normal.',
    vaccination_status: 'fully_vaccinated',
    is_vaccinated: true,
    is_neutered: true,
    is_house_trained: true,
    is_kid_safe: true,
    is_apartment_friendly: true,
    is_urgent: true,
    is_foster: false,
    image_url: 'https://images.unsplash.com/photo-1543466835-00a7907e9de1?auto=format&fit=crop&w=800&q=80',
    gallery: [
      'https://images.unsplash.com/photo-1543466835-00a7907e9de1?auto=format&fit=crop&w=800&q=80'
    ],
    qr_hash: 'ADOPT-PET-BARNABY-UTTARA-2026-B99',
    city: 'Dhaka',
    latitude: 23.8680,
    longitude: 90.3950,
  },
  {
    name: 'Bubbles',
    species: 'Fish',
    breed: 'Red Cap Goldfish',
    age_months: 12,
    gender: 'male',
    weight_kg: 0.15,
    size: 'small',
    story: 'Bubbles is an active, healthy Red Cap Oranda goldfish with a vibrant red crown. Peaceful and soothing for any home aquarium.',
    medical_history: 'Quarantine cleared, healthy finnage, swim-bladder healthy, fed high-grade pellet diet.',
    vaccination_status: 'fully_vaccinated',
    is_vaccinated: true,
    is_neutered: false,
    is_house_trained: true,
    is_kid_safe: true,
    is_apartment_friendly: true,
    is_urgent: false,
    is_foster: false,
    image_url: 'https://images.unsplash.com/photo-1522069169874-c58ec4b76be5?auto=format&fit=crop&w=800&q=80',
    gallery: [
      'https://images.unsplash.com/photo-1522069169874-c58ec4b76be5?auto=format&fit=crop&w=800&q=80',
      'https://images.unsplash.com/photo-1535591273668-578e31182c4f?auto=format&fit=crop&w=800&q=80'
    ],
    qr_hash: 'ADOPT-PET-BUBBLES-KATABON-2026-F15',
    city: 'Dhaka',
    latitude: 23.7380,
    longitude: 90.3890,
  },
  {
    name: 'Crimson',
    species: 'Fish',
    breed: 'Betta Fish',
    age_months: 8,
    gender: 'male',
    weight_kg: 0.05,
    size: 'small',
    story: 'Crimson is a gorgeous Halfmoon Betta fish with stunning deep ruby fins. Extremely low-maintenance and ideal for compact study desks.',
    medical_history: 'Parasite-free, flared healthily, acclimated to conditioned tap water.',
    vaccination_status: 'fully_vaccinated',
    is_vaccinated: true,
    is_neutered: false,
    is_house_trained: true,
    is_kid_safe: true,
    is_apartment_friendly: true,
    is_urgent: false,
    is_foster: false,
    image_url: 'https://images.unsplash.com/photo-1535591273668-578e31182c4f?auto=format&fit=crop&w=800&q=80',
    gallery: [
      'https://images.unsplash.com/photo-1535591273668-578e31182c4f?auto=format&fit=crop&w=800&q=80'
    ],
    qr_hash: 'ADOPT-PET-CRIMSON-MIRPUR-2026-F16',
    city: 'Dhaka',
    latitude: 23.8069,
    longitude: 90.3687,
  },
  {
    name: 'Shelly',
    species: 'Turtle',
    breed: 'Red-Eared Slider Turtle',
    age_months: 36,
    gender: 'female',
    weight_kg: 1.2,
    size: 'small',
    story: 'Shelly is a friendly semi-aquatic turtle who loves basking under her UVB lamp and greeting you at feeding time.',
    medical_history: 'Shell hardening excellent, no respiratory symptoms, regular calcium and multivitamin supplemented.',
    vaccination_status: 'fully_vaccinated',
    is_vaccinated: true,
    is_neutered: false,
    is_house_trained: true,
    is_kid_safe: true,
    is_apartment_friendly: true,
    is_urgent: false,
    is_foster: false,
    image_url: 'https://images.unsplash.com/photo-1437622368342-7a3d73a34c8f?auto=format&fit=crop&w=800&q=80',
    gallery: [
      'https://images.unsplash.com/photo-1437622368342-7a3d73a34c8f?auto=format&fit=crop&w=800&q=80'
    ],
    qr_hash: 'ADOPT-PET-SHELLY-MOHAMMADPUR-2026-T17',
    city: 'Dhaka',
    latitude: 23.7540,
    longitude: 90.3620,
  },
  {
    name: 'Ziggy',
    species: 'Gecko',
    breed: 'Leopard Gecko',
    age_months: 14,
    gender: 'male',
    weight_kg: 0.08,
    size: 'small',
    story: 'Ziggy is a calm and docile Leopard Gecko with yellow and lavender spots. Loves eating mealworms and resting on warm hides.',
    medical_history: 'Healthy fat tail reserves, clear shedding history, free of metabolic bone disease.',
    vaccination_status: 'fully_vaccinated',
    is_vaccinated: true,
    is_neutered: false,
    is_house_trained: true,
    is_kid_safe: true,
    is_apartment_friendly: true,
    is_urgent: false,
    is_foster: false,
    image_url: 'https://images.unsplash.com/photo-1504450874802-0ba2bcd9b5ae?auto=format&fit=crop&w=800&q=80',
    gallery: [
      'https://images.unsplash.com/photo-1504450874802-0ba2bcd9b5ae?auto=format&fit=crop&w=800&q=80'
    ],
    qr_hash: 'ADOPT-PET-ZIGGY-BANANI-2026-G18',
    city: 'Dhaka',
    latitude: 23.7937,
    longitude: 90.4066,
  },
  {
    name: 'Draco',
    species: 'Gecko',
    breed: 'Bearded Dragon',
    age_months: 24,
    gender: 'male',
    weight_kg: 0.45,
    size: 'small',
    story: 'Draco is an interactive bearded dragon who loves head tilts, shoulder perches, and snacking on fresh greens and crickets.',
    medical_history: 'MBD screened negative, active joint mobility, pristine scales and healthy appetite.',
    vaccination_status: 'fully_vaccinated',
    is_vaccinated: true,
    is_neutered: false,
    is_house_trained: true,
    is_kid_safe: true,
    is_apartment_friendly: true,
    is_urgent: false,
    is_foster: false,
    image_url: 'https://images.unsplash.com/photo-1574063413132-355dbfd83e25?auto=format&fit=crop&w=800&q=80',
    gallery: [
      'https://images.unsplash.com/photo-1574063413132-355dbfd83e25?auto=format&fit=crop&w=800&q=80'
    ],
    qr_hash: 'ADOPT-PET-DRACO-BANANI-2026-G19',
    city: 'Dhaka',
    latitude: 23.7937,
    longitude: 90.4066,
  },
  {
    name: 'Clover',
    species: 'Rabbit',
    breed: 'Holland Lop Rabbit',
    age_months: 10,
    gender: 'female',
    weight_kg: 1.8,
    size: 'small',
    story: 'Clover is a sweet bunny with droopy lop ears. She is litter-trained, gentle with kids, and loves timothy hay and fresh cilantro.',
    medical_history: 'RHDV2 vaccinated, teeth alignment checked by vet, spayed and healthy.',
    vaccination_status: 'fully_vaccinated',
    is_vaccinated: true,
    is_neutered: true,
    is_house_trained: true,
    is_kid_safe: true,
    is_apartment_friendly: true,
    is_urgent: false,
    is_foster: false,
    image_url: 'https://images.unsplash.com/photo-1585110396000-c9ffd4e4b308?auto=format&fit=crop&w=800&q=80',
    gallery: [
      'https://images.unsplash.com/photo-1585110396000-c9ffd4e4b308?auto=format&fit=crop&w=800&q=80'
    ],
    qr_hash: 'ADOPT-PET-CLOVER-GULSHAN-2026-R20',
    city: 'Dhaka',
    latitude: 23.7925,
    longitude: 90.4078,
  },
  {
    name: 'Simba',
    species: 'Cat',
    breed: 'Persian',
    age_months: 24,
    gender: 'male',
    weight_kg: 4.5,
    size: 'small',
    story: 'Simba is a majestic white Persian cat with a silky plush coat. Calm, docile, and enjoys quiet apartment snoozing.',
    medical_history: 'FVRCP vaccinated, Rabies booster complete, eyes and coat professionally groomed.',
    vaccination_status: 'fully_vaccinated',
    is_vaccinated: true,
    is_neutered: true,
    is_house_trained: true,
    is_kid_safe: true,
    is_apartment_friendly: true,
    is_urgent: false,
    is_foster: false,
    image_url: 'https://images.unsplash.com/photo-1518791841217-8f162f1e1131?auto=format&fit=crop&w=800&q=80',
    gallery: [
      'https://images.unsplash.com/photo-1518791841217-8f162f1e1131?auto=format&fit=crop&w=800&q=80'
    ],
    qr_hash: 'ADOPT-PET-SIMBA-DHANMONDI-2026-C21',
    city: 'Dhaka',
    latitude: 23.7465,
    longitude: 90.3760,
  },
  {
    name: 'Leo',
    species: 'Cat',
    breed: 'Bengal',
    age_months: 15,
    gender: 'male',
    weight_kg: 4.8,
    size: 'small',
    story: 'Leo is an intelligent, leopard-spotted Bengal cat with playful energy. Loves interactive feather wands and cat towers.',
    medical_history: 'Full vaccination certificate, microchipped, negative for genetic cardiac conditions.',
    vaccination_status: 'fully_vaccinated',
    is_vaccinated: true,
    is_neutered: true,
    is_house_trained: true,
    is_kid_safe: true,
    is_apartment_friendly: true,
    is_urgent: false,
    is_foster: false,
    image_url: 'https://images.unsplash.com/photo-1603775020644-eb8decd79994?auto=format&fit=crop&w=800&q=80',
    gallery: [
      'https://images.unsplash.com/photo-1603775020644-eb8decd79994?auto=format&fit=crop&w=800&q=80'
    ],
    qr_hash: 'ADOPT-PET-LEO-GULSHAN-2026-C22',
    city: 'Dhaka',
    latitude: 23.7925,
    longitude: 90.4078,
  },
  {
    name: 'Mimi',
    species: 'Cat',
    breed: 'Domestic Shorthair (দেশি বিড়াল)',
    age_months: 8,
    gender: 'female',
    weight_kg: 3.2,
    size: 'small',
    story: 'Mimi is an energetic and affectionate rescued Deshi cat. Resilient, healthy, loving, and very loyal to her humans.',
    medical_history: 'Fully vaccinated, dewormed, spayed, ready for loving adoption.',
    vaccination_status: 'fully_vaccinated',
    is_vaccinated: true,
    is_neutered: true,
    is_house_trained: true,
    is_kid_safe: true,
    is_apartment_friendly: true,
    is_urgent: true,
    is_foster: false,
    image_url: 'https://images.unsplash.com/photo-1543852786-1cf6624b9987?auto=format&fit=crop&w=800&q=80',
    gallery: [
      'https://images.unsplash.com/photo-1543852786-1cf6624b9987?auto=format&fit=crop&w=800&q=80'
    ],
    qr_hash: 'ADOPT-PET-MIMI-DHANMONDI-2026-C23',
    city: 'Dhaka',
    latitude: 23.7465,
    longitude: 90.3760,
  }
];

// Fallback images for existing demo pets
const DEMO_UPDATES = {
  'Mishti': {
    image_url: 'https://images.unsplash.com/photo-1514888286974-6c03e2ca1dba?auto=format&fit=crop&w=800&q=80',
    is_apartment_friendly: true,
  },
  'Raju': {
    image_url: 'https://images.unsplash.com/photo-1583511655857-d19b40a7a54e?auto=format&fit=crop&w=800&q=80',
    is_apartment_friendly: true,
  },
  'Tuktuki': {
    image_url: 'https://images.unsplash.com/photo-1552728089-57bdde30beb3?auto=format&fit=crop&w=800&q=80',
    is_apartment_friendly: true,
  }
};

async function main() {
  console.log(`Connecting to Supabase at: ${SUPABASE_URL}`);

  // 1. Get default shelter
  const shelters = await api('/rest/v1/shelters?select=id,owner_id&limit=1');
  if (shelters.length === 0) {
    throw new Error('No shelter found in Supabase! Run seed-demo.mjs first.');
  }
  const shelter = shelters[0];
  console.log(`Using Shelter: ${shelter.id}, Owner: ${shelter.owner_id}`);

  // 2. Fetch existing pets in database
  const existingPets = await api('/rest/v1/pets?select=id,name');
  const existingMap = new Map();
  for (const p of existingPets) {
    existingMap.set(p.name.toLowerCase().trim(), p.id);
  }
  console.log(`Currently in database: ${existingPets.length} pets.`);

  // 3. Update existing demo pets if their images are missing
  for (const [name, update] of Object.entries(DEMO_UPDATES)) {
    const existingId = existingMap.get(name.toLowerCase());
    if (existingId) {
      console.log(`Updating demo pet image: ${name} (${existingId})`);
      await api(`/rest/v1/pets?id=eq.${existingId}`, {
        method: 'PATCH',
        headers: { ...headers, Prefer: 'return=minimal' },
        body: JSON.stringify(update),
      });
    }
  }

  // 4. Insert any catalog pets that are not yet in Supabase
  let insertedCount = 0;
  for (const pet of CATALOG_PETS) {
    const key = pet.name.toLowerCase().trim();
    if (existingMap.has(key)) {
      console.log(`• Pet '${pet.name}' already exists, skipping.`);
      continue;
    }

    const { gallery, ...dbFields } = pet;
    const payload = {
      ...dbFields,
      owner_id: shelter.owner_id,
      shelter_id: shelter.id,
      adoption_status: pet.is_foster ? 'foster' : 'available',
      moderation_status: 'approved',
      contact_phone: '+8801700000000',
      is_active: true,
    };

    const inserted = await api('/rest/v1/pets', {
      method: 'POST',
      headers: { ...headers, Prefer: 'return=representation' },
      body: JSON.stringify(payload),
    });

    const newPet = inserted[0];
    if (newPet && gallery && gallery.length > 0) {
      const imagesPayload = gallery.map((url, idx) => ({
        pet_id: newPet.id,
        url: url,
        sort_order: idx,
      }));
      await api('/rest/v1/pet_images', {
        method: 'POST',
        headers: { ...headers, Prefer: 'return=minimal' },
        body: JSON.stringify(imagesPayload),
      });
    }

    insertedCount++;
    console.log(`✔ Inserted [${pet.species}] ${pet.name}`);
  }

  // 5. Final count check
  const allFinalPets = await api('/rest/v1/pets?select=id,name,species,moderation_status,image_url');
  console.log(`\n🎉 Total pets now in Supabase: ${allFinalPets.length}`);
  console.log(`✔ Inserted ${insertedCount} new pets.`);
  const pending = allFinalPets.filter(p => p.moderation_status !== 'approved');
  if (pending.length > 0) {
    console.warn(`⚠ Warning: ${pending.length} pets are still pending moderation!`);
  } else {
    console.log('✔ 100% of pets are approved and ready for adoption feed.');
  }
}

main().catch(err => {
  console.error('Fatal error:', err);
  process.exit(1);
});
