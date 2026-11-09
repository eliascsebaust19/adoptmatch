-- AdoptMatch Seed Data
USE adoptmatch_db;

-- Clear existing data
SET FOREIGN_KEY_CHECKS = 0;
TRUNCATE TABLE audit_logs;
TRUNCATE TABLE notifications;
TRUNCATE TABLE support_resources;
TRUNCATE TABLE post_adoption_surveys;
TRUNCATE TABLE adoptions;
TRUNCATE TABLE foster_assignments;
TRUNCATE TABLE foster_profiles;
TRUNCATE TABLE favorites;
TRUNCATE TABLE application_status_history;
TRUNCATE TABLE adoption_applications;
TRUNCATE TABLE match_scores;
TRUNCATE TABLE adopter_assessments;
TRUNCATE TABLE pet_behavior_records;
TRUNCATE TABLE pet_vaccinations;
TRUNCATE TABLE pet_medical_records;
TRUNCATE TABLE pet_photos;
TRUNCATE TABLE pets;
TRUNCATE TABLE adopter;
TRUNCATE TABLE shelter_staff;
TRUNCATE TABLE shelters;
TRUNCATE TABLE users;
SET FOREIGN_KEY_CHECKS = 1;

-- Passwords hashed for 'password123' using bcrypt: $2a$10$e8w.x.sX3/Q33r6HlI4/9u3P4j/d0H1j6w0a9
-- We'll also support plain string check in seed runner for ease.

-- 1. Users
INSERT INTO users (id, name, email, password_hash, role, phone, avatar_url) VALUES
(1, 'System Admin', 'admin@adoptmatch.com', '$2b$10$137M37f2O9D.N9X5kLpLreEwKjU7xN3L5U9T4W3xM1k9.5xO5Z5x2', 'ADMIN', '555-0100', 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=150'),
(2, 'Sarah Jenkins', 'sarah.adopter@gmail.com', '$2b$10$137M37f2O9D.N9X5kLpLreEwKjU7xN3L5U9T4W3xM1k9.5xO5Z5x2', 'ADOPTER', '555-0101', 'https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=150'),
(3, 'Alex Rivera', 'alex.adopter@gmail.com', '$2b$10$137M37f2O9D.N9X5kLpLreEwKjU7xN3L5U9T4W3xM1k9.5xO5Z5x2', 'ADOPTER', '555-0102', 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=150'),
(4, 'Paws Shelter Staff', 'staff@pawshelter.org', '$2b$10$137M37f2O9D.N9X5kLpLreEwKjU7xN3L5U9T4W3xM1k9.5xO5Z5x2', 'SHELTER_STAFF', '555-0103', 'https://images.unsplash.com/photo-1573496359142-b8d87734a5a2?w=150'),
(5, 'Haven Pet Manager', 'staff@havenpets.org', '$2b$10$137M37f2O9D.N9X5kLpLreEwKjU7xN3L5U9T4W3xM1k9.5xO5Z5x2', 'SHELTER_STAFF', '555-0104', 'https://images.unsplash.com/photo-1560250097-0b93528c311a?w=150'),
(6, 'Elena Rostova', 'elena.foster@gmail.com', '$2b$10$137M37f2O9D.N9X5kLpLreEwKjU7xN3L5U9T4W3xM1k9.5xO5Z5x2', 'FOSTER', '555-0105', 'https://images.unsplash.com/photo-1544005313-94ddf0286df2?w=150'),
(7, 'Dr. Marcus Vance', 'dr.vance@vetcare.org', '$2b$10$137M37f2O9D.N9X5kLpLreEwKjU7xN3L5U9T4W3xM1k9.5xO5Z5x2', 'VETERINARIAN', '555-0106', 'https://images.unsplash.com/photo-1622253692010-333f2da6031d?w=150'),
(8, 'David Miller', 'david.adopter@gmail.com', '$2b$10$137M37f2O9D.N9X5kLpLreEwKjU7xN3L5U9T4W3xM1k9.5xO5Z5x2', 'ADOPTER', '555-0107', 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=150'),
(9, 'Emily Chen', 'emily.foster@gmail.com', '$2b$10$137M37f2O9D.N9X5kLpLreEwKjU7xN3L5U9T4W3xM1k9.5xO5Z5x2', 'FOSTER', '555-0108', 'https://images.unsplash.com/photo-1517841905240-472988babdf9?w=150');

-- 2. Shelters
INSERT INTO shelters (id, name, address, city, state, zip, phone, email, website, verification_status, capacity) VALUES
(1, 'Happy Tails Animal Shelter', '124 Pet Haven Way', 'Seattle', 'WA', '98101', '206-555-0199', 'contact@happytails.org', 'https://happytails.org', 'VERIFIED', 60),
(2, 'City Paws Rescue', '580 Park Avenue', 'San Francisco', 'CA', '94102', '415-555-0144', 'help@citypaws.org', 'https://citypaws.org', 'VERIFIED', 45),
(3, 'Golden State Pet Sanctuary', '892 Oak Lane', 'Los Angeles', 'CA', '90001', '213-555-0188', 'info@goldenstatepets.org', 'https://goldenstatepets.org', 'VERIFIED', 80),
(4, 'Metro Humane Society', '310 River Street', 'Portland', 'OR', '97201', '503-555-0122', 'adoptions@metrohumane.org', 'https://metrohumane.org', 'VERIFIED', 50),
(5, 'Sun Valley Fosters Network', '77 Pine Ridge Rd', 'Denver', 'CO', '80201', '303-555-0177', 'hello@sunvalleyfosters.org', 'https://sunvalleyfosters.org', 'VERIFIED', 30);

-- 3. Shelter Staff Mapping
INSERT INTO shelter_staff (user_id, shelter_id, position) VALUES
(4, 1, 'Senior Adoption Counselor'),
(5, 2, 'Shelter Director');

-- 4. Adopters
INSERT INTO adopters (user_id, address, city, housing_type, own_or_rent, landlord_permission, has_yard, yard_fenced, household_members, has_children, has_other_pets, pet_experience) VALUES
(2, '742 Evergreen Terrace', 'Seattle', 'HOUSE', 'OWN', TRUE, TRUE, TRUE, 3, TRUE, FALSE, 'INTERMEDIATE'),
(3, '1088 Howard Street Apt 4B', 'San Francisco', 'APARTMENT', 'RENT', TRUE, FALSE, FALSE, 1, FALSE, FALSE, 'BEGINNER'),
(8, '450 Sunset Blvd', 'Los Angeles', 'HOUSE', 'OWN', TRUE, TRUE, TRUE, 4, TRUE, TRUE, 'EXPERIENCED');

-- 5. Pets (20 realistic pets)
INSERT INTO pets (id, shelter_id, name, species, breed, age_months, gender, size, weight_lbs, energy_level, temperament, description, child_friendly, dog_friendly, cat_friendly, apartment_friendly, house_trained, leash_trained, grooming_requirement, exercise_requirement, special_needs, medical_status, adoption_status, location) VALUES
(1, 1, 'Barnaby', 'Dog', 'Golden Retriever Mix', 24, 'Male', 'Medium', 48.50, 'Moderate', 'Gentle, Playful, Affectionate', 'Barnaby is an exceptionally friendly Golden Retriever mix who loves outdoor walks, belly rubs, and playing fetch. Great with kids and apartment friendly with moderate activity.', TRUE, TRUE, TRUE, TRUE, TRUE, TRUE, 'Moderate', 'Moderate', FALSE, 'Healthy & Vaccinated', 'Available', 'Seattle, WA'),
(2, 1, 'Luna', 'Cat', 'Domestic Short Hair', 18, 'Female', 'Small', 8.20, 'Low', 'Calm, Affectionate, Quiet', 'Luna is a sweet indoor cat who loves sunbathing on windowsills and sitting on warm laps. Extremely gentle and suitable for first-time owners.', TRUE, TRUE, TRUE, TRUE, TRUE, TRUE, 'Low', 'Low', FALSE, 'Vaccinated, Spayed', 'Available', 'Seattle, WA'),
(3, 2, 'Milo', 'Dog', 'Australian Shepherd', 14, 'Male', 'Medium', 38.00, 'High', 'Energetic, Intelligent, Agile', 'Milo is a smart, high-energy pup who thrives on agility games, hiking, and mental stimulation. Ideal for an active family with a fenced yard.', TRUE, TRUE, FALSE, FALSE, TRUE, TRUE, 'Moderate', 'High', FALSE, 'Healthy & Microchipped', 'Available', 'San Francisco, CA'),
(4, 2, 'Bella', 'Dog', 'French Bulldog', 36, 'Female', 'Small', 22.00, 'Low', 'Loyal, Cuddly, Chilled', 'Bella is a low-energy companion who loves short neighborhood strolls and curling up on the sofa. Perfect for apartment living.', TRUE, TRUE, TRUE, TRUE, TRUE, TRUE, 'Low', 'Low', FALSE, 'Healthy', 'Pending', 'San Francisco, CA'),
(5, 3, 'Oliver', 'Cat', 'Maine Coon Mix', 30, 'Male', 'Medium', 14.50, 'Moderate', 'Friendly, Vocal, Playful', 'Oliver is a majestic Maine Coon mix with a fluffy coat and sweet personality. Loves interacting with family members and companion cats.', TRUE, TRUE, TRUE, TRUE, TRUE, TRUE, 'High', 'Moderate', FALSE, 'Vaccinated', 'Available', 'Los Angeles, CA'),
(6, 3, 'Rocky', 'Dog', 'German Shepherd', 42, 'Male', 'Large', 72.00, 'High', 'Protective, Loyal, Obedient', 'Rocky is a well-trained, protective Shepherd with excellent leash etiquette. Needs an experienced owner who can provide consistent guidance.', FALSE, FALSE, FALSE, FALSE, TRUE, TRUE, 'Low', 'High', FALSE, 'Vaccinated & Neutered', 'Available', 'Los Angeles, CA'),
(7, 4, 'Daisy', 'Dog', 'Beagle', 12, 'Female', 'Small', 18.00, 'Moderate', 'Curious, Gentle, Loving', 'Daisy is a sweet young Beagle with an endearing nose and cheerful personality. Enjoys sniffing gardens and cuddling on couches.', TRUE, TRUE, TRUE, TRUE, TRUE, TRUE, 'Low', 'Moderate', FALSE, 'Healthy', 'Available', 'Portland, OR'),
(8, 4, 'Felix', 'Cat', 'Siamese Mix', 20, 'Male', 'Small', 9.00, 'Moderate', 'Social, Talkative, Intelligent', 'Felix is a social cat who loves communicating with his humans and playing with laser pointers.', TRUE, TRUE, TRUE, TRUE, TRUE, TRUE, 'Low', 'Low', FALSE, 'Vaccinated', 'Available', 'Portland, OR'),
(9, 5, 'Cooper', 'Dog', 'Labrador Retriever', 28, 'Male', 'Large', 65.00, 'Moderate', 'Friendly, Outgoing, Loving', 'Cooper is the classic family dog—loves water, playing fetch, and getting along with everyone he meets.', TRUE, TRUE, TRUE, FALSE, TRUE, TRUE, 'Low', 'Moderate', FALSE, 'Healthy', 'Fostered', 'Denver, CO'),
(10, 5, 'Cleo', 'Cat', 'Persian', 48, 'Female', 'Small', 7.80, 'Low', 'Quiet, Gentle, Regal', 'Cleo is a quiet Persian cat who prefers a calm household. Requires regular grooming to keep her fluffy coat soft.', TRUE, FALSE, TRUE, TRUE, TRUE, FALSE, 'High', 'Low', TRUE, 'Daily eye wipes required', 'Available', 'Denver, CO'),
(11, 1, 'Zeus', 'Dog', 'Boxer Mix', 36, 'Male', 'Large', 60.00, 'Very High', 'Playful, Energetic, Loving', 'Zeus is a goofy, fun-loving dog with bounds of energy. Loves running in big yards.', TRUE, TRUE, FALSE, FALSE, TRUE, TRUE, 'Low', 'High', FALSE, 'Healthy', 'Available', 'Seattle, WA'),
(12, 2, 'Chloe', 'Cat', 'Tabby', 10, 'Female', 'Small', 6.50, 'Moderate', 'Playful, Curious, Sweet', 'Chloe is a curious kitten-at-heart who loves feather wands and warm window spots.', TRUE, TRUE, TRUE, TRUE, TRUE, TRUE, 'Low', 'Low', FALSE, 'Vaccinated', 'Available', 'San Francisco, CA'),
(13, 3, 'Buster', 'Dog', 'Pug', 60, 'Male', 'Small', 16.00, 'Low', 'Gentle, Affectionate, Calm', 'Buster is a senior Pug who enjoys quiet afternoon naps and slow evening walks.', TRUE, TRUE, TRUE, TRUE, TRUE, TRUE, 'Low', 'Low', TRUE, 'Joint supplements', 'Available', 'Los Angeles, CA'),
(14, 4, 'Ruby', 'Dog', 'Australian Cattle Dog', 22, 'Female', 'Medium', 35.00, 'High', 'Smart, Focused, Active', 'Ruby is an energetic herding dog who thrives with active runners or outdoor enthusiasts.', FALSE, TRUE, FALSE, FALSE, TRUE, TRUE, 'Low', 'High', FALSE, 'Healthy', 'Available', 'Portland, OR'),
(15, 5, 'Simba', 'Cat', 'Bengal Mix', 15, 'Male', 'Medium', 11.00, 'High', 'Active, Vocal, Bold', 'Simba is a sleek Bengal mix who loves climbing high cat trees and chasing toys.', TRUE, TRUE, FALSE, TRUE, TRUE, TRUE, 'Low', 'Moderate', FALSE, 'Healthy', 'Available', 'Denver, CO'),
(16, 1, 'Coco', 'Dog', 'Poodle Mix (Doodle)', 16, 'Female', 'Medium', 32.00, 'Moderate', 'Friendly, Hypoallergenic, Smart', 'Coco is a non-shedding, highly intelligent companion who loves learning tricks.', TRUE, TRUE, TRUE, TRUE, TRUE, TRUE, 'High', 'Moderate', FALSE, 'Vaccinated', 'Adopted', 'Seattle, WA'),
(17, 2, 'Teddy', 'Dog', 'Corgi', 26, 'Male', 'Small', 25.00, 'Moderate', 'Playful, Loyal, Alert', 'Teddy is a classic Pembroke Welsh Corgi with short legs and a huge personality.', TRUE, TRUE, TRUE, TRUE, TRUE, TRUE, 'Moderate', 'Moderate', FALSE, 'Healthy', 'Available', 'San Francisco, CA'),
(18, 3, 'Penny', 'Rabbit', 'Holland Lop', 12, 'Female', 'Small', 3.50, 'Low', 'Gentle, Quiet, Soft', 'Penny is a sweet indoor bunny who loves fresh parsley and quiet lap time.', TRUE, TRUE, TRUE, TRUE, TRUE, FALSE, 'Low', 'Low', FALSE, 'Vaccinated', 'Available', 'Los Angeles, CA'),
(19, 4, 'Max', 'Dog', 'Golden Retriever', 48, 'Male', 'Large', 70.00, 'Moderate', 'Patient, Gentle, Loving', 'Max is a sweet, mature Golden Retriever who is therapy-dog material.', TRUE, TRUE, TRUE, FALSE, TRUE, TRUE, 'Moderate', 'Moderate', FALSE, 'Healthy', 'Available', 'Portland, OR'),
(20, 5, 'Ziggy', 'Bird', 'Cockatiel', 24, 'Male', 'Small', 0.25, 'Low', 'Whistling, Friendly, Curious', 'Ziggy loves whistling tunes and riding on his owner\'s shoulder.', TRUE, FALSE, FALSE, TRUE, FALSE, FALSE, 'Low', 'Low', FALSE, 'Healthy', 'Available', 'Denver, CO');

-- 6. Pet Photos
INSERT INTO pet_photos (pet_id, photo_url, is_primary) VALUES
(1, 'https://images.unsplash.com/photo-1552053831-71594a27632d?w=800', TRUE),
(1, 'https://images.unsplash.com/photo-1537151608828-ea2b11777ee8?w=800', FALSE),
(2, 'https://images.unsplash.com/photo-1514888286974-6c03e2ca1dba?w=800', TRUE),
(3, 'https://images.unsplash.com/photo-1507146426996-ef05306b995a?w=800', TRUE),
(4, 'https://images.unsplash.com/photo-1583511655857-d19b40a7a54e?w=800', TRUE),
(5, 'https://images.unsplash.com/photo-1573865526739-10659fec78a5?w=800', TRUE),
(6, 'https://images.unsplash.com/photo-1589941013453-ec89f33b5e95?w=800', TRUE),
(7, 'https://images.unsplash.com/photo-1505628346881-b72b27e84530?w=800', TRUE),
(8, 'https://images.unsplash.com/photo-1561948955-570b270e7c36?w=800', TRUE),
(9, 'https://images.unsplash.com/photo-1543466835-00a7907e9de1?w=800', TRUE),
(10, 'https://images.unsplash.com/photo-1533738363-b7f9aef128ce?w=800', TRUE),
(11, 'https://images.unsplash.com/photo-1544568100-847a948585b9?w=800', TRUE),
(12, 'https://images.unsplash.com/photo-1574158622682-e40e69881006?w=800', TRUE),
(13, 'https://images.unsplash.com/photo-1517423440428-a5a00ad493e8?w=800', TRUE),
(14, 'https://images.unsplash.com/photo-1568640347023-a616a30bc3bd?w=800', TRUE),
(15, 'https://images.unsplash.com/photo-1513360371669-4adf3dd7dff8?w=800', TRUE),
(16, 'https://images.unsplash.com/photo-1518717758536-85ae29035b6d?w=800', TRUE),
(17, 'https://images.unsplash.com/photo-1612536053382-362b81a028d1?w=800', TRUE),
(18, 'https://images.unsplash.com/photo-1585110396000-c9ffd4e4b308?w=800', TRUE),
(19, 'https://images.unsplash.com/photo-1633722715463-d30f4f325e24?w=800', TRUE),
(20, 'https://images.unsplash.com/photo-1522858547137-f1dcec554f55?w=800', TRUE);

-- 7. Medical Records
INSERT INTO pet_medical_records (pet_id, vet_user_id, record_date, condition_title, treatment_notes, medication, allergies, next_due_date) VALUES
(1, 7, '2026-06-15', 'Annual Health Exam & Vaccination', 'Comprehensive checkup completed. Heart, lungs, and joints healthy. Teatment clean.', 'Heartworm Preventative', 'None', '2027-06-15'),
(2, 7, '2026-07-01', 'Feline Spay & Vaccination', 'Spay procedure successful. Stitches healed cleanly.', 'Pain Relief (3 days)', 'None', '2027-07-01'),
(3, 7, '2026-05-10', 'Microchip & DHPP Vaccine', 'Microchip implanted (#9851410023). Vaccine administered.', 'N/A', 'Grain sensitivity', '2027-05-10');

-- 8. Vaccinations
INSERT INTO pet_vaccinations (pet_id, vaccine_name, date_administered, next_due_date, administered_by) VALUES
(1, 'Rabies 3-Year', '2026-06-15', '2029-06-15', 'Dr. Marcus Vance'),
(1, 'DHPP', '2026-06-15', '2027-06-15', 'Dr. Marcus Vance'),
(2, 'FVRCP', '2026-07-01', '2027-07-01', 'Dr. Marcus Vance');

-- 9. Behavior Records
INSERT INTO pet_behavior_records (pet_id, assessor_id, aggression_level, socialization_score, separation_anxiety, behavior_notes) VALUES
(1, 4, 'None', 9, FALSE, 'Extremely outgoing and calm. Responds well to basic commands (sit, stay, paw).'),
(2, 4, 'None', 8, FALSE, 'Gentle and affectionate. Enjoys being held for short periods.'),
(3, 5, 'None', 9, FALSE, 'High drive, energetic herder. Needs structured play time.');

-- 10. Adopter Lifestyle Assessments (For Sarah Jenkins)
INSERT INTO adopter_assessments (user_id, daily_free_time_hours, working_schedule, activity_level, travel_frequency, pet_experience, housing_type, has_yard, yard_fenced, living_space_sqft, landlord_allows_pets, has_children, has_elderly, has_other_pets, preferred_species, preferred_age_min, preferred_age_max, preferred_size, preferred_gender, training_willingness, grooming_willingness, special_needs_willingness) VALUES
(2, 4, 'HYBRID', 'MODERATE', 'SELDOM', 'INTERMEDIATE', 'HOUSE', TRUE, TRUE, 1800, TRUE, TRUE, FALSE, FALSE, 'Dog', 6, 60, 'Medium', 'Any', 'MODERATE', 'MODERATE', FALSE),
(3, 2, 'REMOTE', 'SEDENTARY', 'NEVER', 'BEGINNER', 'APARTMENT', FALSE, FALSE, 750, TRUE, FALSE, FALSE, FALSE, 'Cat', 12, 84, 'Small', 'Female', 'LOW', 'LOW', FALSE);

-- 11. Applications
INSERT INTO adoption_applications (id, pet_id, adopter_user_id, status, housing_details, experience_details, reason_for_adoption, care_plan, agreement_consent, shelter_notes) VALUES
(1, 1, 2, 'Under Review', 'Single family home with fenced backyard in Seattle suburb.', 'Grew up with Golden Retrievers for 10+ years.', 'Looking for a gentle family companion for our 8-year-old child.', 'Daily 45-min walks, weekend park visits, local vet care planned.', TRUE, 'Initial screening passed. Scheduling interview for Friday.');

-- 12. Application Status History
INSERT INTO application_status_history (application_id, previous_status, new_status, changed_by_user_id, notes) VALUES
(1, NULL, 'Submitted', 2, 'Application submitted by Sarah Jenkins.'),
(1, 'Submitted', 'Under Review', 4, 'Application assigned to Sarah for background review.');

-- 13. Favorites
INSERT INTO favorites (user_id, pet_id) VALUES
(2, 1),
(2, 2),
(3, 2);

-- 14. Foster Profiles
INSERT INTO foster_profiles (user_id, capacity, preferred_species, preferred_size, experience_years, availability_status, home_notes) VALUES
(6, 2, 'Dog, Cat', 'Small, Medium', 4, 'AVAILABLE', 'Spacious townhouse with direct access to private park. Experienced with puppies.'),
(9, 1, 'Cat', 'Small', 2, 'AVAILABLE', 'Quiet apartment, no other pets. Great for shy or recovering cats.');

-- 15. Support Resources
INSERT INTO support_resources (title, category, content, target_period) VALUES
('Welcome Home: The 3-3-3 Rule for Pet Adoption', 'SETTLING_IN', 'In the first 3 days, your pet may feel overwhelmed. Give them space and a safe corner. By 3 weeks, they start learning your routine. By 3 months, they feel truly at home.', 'WEEK_1'),
('Establishing a Healthy Feeding & Exercise Routine', 'FEEDING', 'Maintain the shelter feeding schedule for the first week to avoid stomach upset. Gradually transition food over 7 days if changing brands.', 'WEEK_1'),
('Positive Reinforcement & House Rules', 'TRAINING', 'Reward good behavior with small treats and gentle verbal praise. Consistency across household members is key to fast learning.', 'WEEK_2'),
('Understanding Feline & Canine Body Language', 'BEHAVIOR', 'Learn to identify signs of stress or contentment. A relaxed tail and soft eyes indicate comfort, while pinned ears signal anxiety.', 'WEEK_3');
