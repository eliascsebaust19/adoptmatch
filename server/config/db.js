const mysql = require('mysql2/promise');
const path = require('path');
const fs = require('fs');

let pool = null;
let useMemoryFallback = false;

const dbConfig = {
  host: process.env.DB_HOST || 'localhost',
  user: process.env.DB_USER || 'root',
  password: process.env.DB_PASSWORD || '',
  database: process.env.DB_NAME || 'adoptmatch_db',
  port: parseInt(process.env.DB_PORT || '3306'),
  waitForConnections: true,
  connectionLimit: 10,
  queueLimit: 0
};

async function initDB() {
  try {
    pool = mysql.createPool(dbConfig);
    const conn = await pool.getConnection();
    console.log('✅ Connected to MySQL database:', dbConfig.database);
    conn.release();
    useMemoryFallback = false;
  } catch (err) {
    console.warn('⚠️ MySQL Connection failed (', err.message, '). Switched to robust in-memory database provider for seamless demo.');
    useMemoryFallback = true;
  }
}

// In-Memory Database Store for Fallback
const memoryStore = {
  users: [
    { id: 1, name: 'System Admin', email: 'admin@adoptmatch.com', password_hash: '$2b$10$137M37f2O9D.N9X5kLpLreEwKjU7xN3L5U9T4W3xM1k9.5xO5Z5x2', role: 'ADMIN', phone: '555-0100', avatar_url: 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=150' },
    { id: 2, name: 'Sarah Jenkins', email: 'sarah.adopter@gmail.com', password_hash: '$2b$10$137M37f2O9D.N9X5kLpLreEwKjU7xN3L5U9T4W3xM1k9.5xO5Z5x2', role: 'ADOPTER', phone: '555-0101', avatar_url: 'https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=150' },
    { id: 3, name: 'Alex Rivera', email: 'alex.adopter@gmail.com', password_hash: '$2b$10$137M37f2O9D.N9X5kLpLreEwKjU7xN3L5U9T4W3xM1k9.5xO5Z5x2', role: 'ADOPTER', phone: '555-0102', avatar_url: 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=150' },
    { id: 4, name: 'Paws Shelter Staff', email: 'staff@pawshelter.org', password_hash: '$2b$10$137M37f2O9D.N9X5kLpLreEwKjU7xN3L5U9T4W3xM1k9.5xO5Z5x2', role: 'SHELTER_STAFF', phone: '555-0103', avatar_url: 'https://images.unsplash.com/photo-1573496359142-b8d87734a5a2?w=150' },
    { id: 5, name: 'Haven Pet Manager', email: 'staff@havenpets.org', password_hash: '$2b$10$137M37f2O9D.N9X5kLpLreEwKjU7xN3L5U9T4W3xM1k9.5xO5Z5x2', role: 'SHELTER_STAFF', phone: '555-0104', avatar_url: 'https://images.unsplash.com/photo-1560250097-0b93528c311a?w=150' },
    { id: 6, name: 'Elena Rostova', email: 'elena.foster@gmail.com', password_hash: '$2b$10$137M37f2O9D.N9X5kLpLreEwKjU7xN3L5U9T4W3xM1k9.5xO5Z5x2', role: 'FOSTER', phone: '555-0105', avatar_url: 'https://images.unsplash.com/photo-1544005313-94ddf0286df2?w=150' },
    { id: 7, name: 'Dr. Marcus Vance', email: 'dr.vance@vetcare.org', password_hash: '$2b$10$137M37f2O9D.N9X5kLpLreEwKjU7xN3L5U9T4W3xM1k9.5xO5Z5x2', role: 'VETERINARIAN', phone: '555-0106', avatar_url: 'https://images.unsplash.com/photo-1622253692010-333f2da6031d?w=150' }
  ],
  shelters: [
    { id: 1, name: 'Happy Tails Animal Shelter', address: '124 Pet Haven Way', city: 'Seattle', state: 'WA', zip: '98101', phone: '206-555-0199', email: 'contact@happytails.org', website: 'https://happytails.org', verification_status: 'VERIFIED', capacity: 60 },
    { id: 2, name: 'City Paws Rescue', address: '580 Park Avenue', city: 'San Francisco', state: 'CA', zip: '94102', phone: '415-555-0144', email: 'help@citypaws.org', website: 'https://citypaws.org', verification_status: 'VERIFIED', capacity: 45 },
    { id: 3, name: 'Golden State Pet Sanctuary', address: '892 Oak Lane', city: 'Los Angeles', state: 'CA', zip: '90001', phone: '213-555-0188', email: 'info@goldenstatepets.org', website: 'https://goldenstatepets.org', verification_status: 'VERIFIED', capacity: 80 }
  ],
  pets: [
    {
      id: 1, shelter_id: 1, name: 'Barnaby', species: 'Dog', breed: 'Golden Retriever Mix', age_months: 24, gender: 'Male', size: 'Medium', weight_lbs: 48.5, energy_level: 'Moderate', temperament: 'Gentle, Playful, Affectionate', description: 'Barnaby is an exceptionally friendly Golden Retriever mix who loves outdoor walks, belly rubs, and playing fetch. Great with kids and apartment friendly with moderate activity.', child_friendly: 1, dog_friendly: 1, cat_friendly: 1, apartment_friendly: 1, house_trained: 1, leash_trained: 1, grooming_requirement: 'Moderate', exercise_requirement: 'Moderate', special_needs: 0, medical_status: 'Healthy & Vaccinated', adoption_status: 'Available', location: 'Seattle, WA',
      photos: ['https://images.unsplash.com/photo-1552053831-71594a27632d?w=800', 'https://images.unsplash.com/photo-1537151608828-ea2b11777ee8?w=800']
    },
    {
      id: 2, shelter_id: 1, name: 'Luna', species: 'Cat', breed: 'Domestic Short Hair', age_months: 18, gender: 'Female', size: 'Small', weight_lbs: 8.2, energy_level: 'Low', temperament: 'Calm, Affectionate, Quiet', description: 'Luna is a sweet indoor cat who loves sunbathing on windowsills and sitting on warm laps.', child_friendly: 1, dog_friendly: 1, cat_friendly: 1, apartment_friendly: 1, house_trained: 1, leash_trained: 1, grooming_requirement: 'Low', exercise_requirement: 'Low', special_needs: 0, medical_status: 'Vaccinated, Spayed', adoption_status: 'Available', location: 'Seattle, WA',
      photos: ['https://images.unsplash.com/photo-1514888286974-6c03e2ca1dba?w=800']
    },
    {
      id: 3, shelter_id: 2, name: 'Milo', species: 'Dog', breed: 'Australian Shepherd', age_months: 14, gender: 'Male', size: 'Medium', weight_lbs: 38.0, energy_level: 'High', temperament: 'Energetic, Intelligent, Agile', description: 'Milo is a smart, high-energy pup who thrives on agility games and hiking.', child_friendly: 1, dog_friendly: 1, cat_friendly: 0, apartment_friendly: 0, house_trained: 1, leash_trained: 1, grooming_requirement: 'Moderate', exercise_requirement: 'High', special_needs: 0, medical_status: 'Healthy & Microchipped', adoption_status: 'Available', location: 'San Francisco, CA',
      photos: ['https://images.unsplash.com/photo-1507146426996-ef05306b995a?w=800']
    },
    {
      id: 4, shelter_id: 2, name: 'Bella', species: 'Dog', breed: 'French Bulldog', age_months: 36, gender: 'Female', size: 'Small', weight_lbs: 22.0, energy_level: 'Low', temperament: 'Loyal, Cuddly, Chilled', description: 'Bella is a low-energy companion who loves short neighborhood strolls.', child_friendly: 1, dog_friendly: 1, cat_friendly: 1, apartment_friendly: 1, house_trained: 1, leash_trained: 1, grooming_requirement: 'Low', exercise_requirement: 'Low', special_needs: 0, medical_status: 'Healthy', adoption_status: 'Pending', location: 'San Francisco, CA',
      photos: ['https://images.unsplash.com/photo-1583511655857-d19b40a7a54e?w=800']
    },
    {
      id: 5, shelter_id: 3, name: 'Oliver', species: 'Cat', breed: 'Maine Coon Mix', age_months: 30, gender: 'Male', size: 'Medium', weight_lbs: 14.5, energy_level: 'Moderate', temperament: 'Friendly, Vocal, Playful', description: 'Oliver is a majestic Maine Coon mix with a fluffy coat and sweet personality.', child_friendly: 1, dog_friendly: 1, cat_friendly: 1, apartment_friendly: 1, house_trained: 1, leash_trained: 1, grooming_requirement: 'High', exercise_requirement: 'Moderate', special_needs: 0, medical_status: 'Vaccinated', adoption_status: 'Available', location: 'Los Angeles, CA',
      photos: ['https://images.unsplash.com/photo-1573865526739-10659fec78a5?w=800']
    }
  ],
  assessments: {},
  applications: [
    {
      id: 1, pet_id: 1, adopter_user_id: 2, status: 'Under Review',
      housing_details: 'Single family home with fenced backyard in Seattle suburb.',
      experience_details: 'Grew up with Golden Retrievers for 10+ years.',
      reason_for_adoption: 'Looking for a gentle family companion for our 8-year-old child.',
      care_plan: 'Daily 45-min walks, weekend park visits, local vet care planned.',
      agreement_consent: true, shelter_notes: 'Initial screening passed. Scheduling interview for Friday.',
      created_at: new Date().toISOString()
    }
  ],
  favorites: [
    { id: 1, user_id: 2, pet_id: 1 },
    { id: 2, user_id: 2, pet_id: 2 }
  ],
  fosters: [
    { id: 1, user_id: 6, capacity: 2, preferred_species: 'Dog, Cat', preferred_size: 'Small, Medium', experience_years: 4, availability_status: 'AVAILABLE', home_notes: 'Spacious townhouse with park access.' }
  ],
  medicalRecords: [
    { id: 1, pet_id: 1, vet_user_id: 7, record_date: '2026-06-15', condition_title: 'Annual Health Exam & Vaccination', treatment_notes: 'Comprehensive checkup completed. Heart, lungs, and joints healthy.', medication: 'Heartworm Preventative', allergies: 'None', next_due_date: '2027-06-15' }
  ],
  behaviorRecords: [
    { id: 1, pet_id: 1, assessor_id: 4, aggression_level: 'None', socialization_score: 9, separation_anxiety: 0, behavior_notes: 'Extremely outgoing and calm. Responds well to basic commands.' }
  ],
  postAdoptionSurveys: [],
  notifications: [
    { id: 1, user_id: 2, title: 'Application Update', message: 'Your application for Barnaby is under review!', is_read: false, created_at: new Date().toISOString() }
  ]
};

module.exports = {
  initDB,
  getPool: () => pool,
  isMemory: () => useMemoryFallback,
  memoryStore
};
