-- AdoptMatch Relational Database Schema (MySQL 8.0 / MariaDB Compatible)
CREATE DATABASE IF NOT EXISTS adoptmatch_db;
USE adoptmatch_db;

-- 1. Users Table
CREATE TABLE IF NOT EXISTS users (
    id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    email VARCHAR(255) NOT NULL UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    role ENUM('ADMIN', 'SHELTER_STAFF', 'ADOPTER', 'FOSTER', 'VETERINARIAN') NOT NULL DEFAULT 'ADOPTER',
    phone VARCHAR(50),
    avatar_url VARCHAR(500),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

-- 2. Shelters Table
CREATE TABLE IF NOT EXISTS shelters (
    id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    address TEXT NOT NULL,
    city VARCHAR(100) NOT NULL,
    state VARCHAR(100) NOT NULL,
    zip VARCHAR(20) NOT NULL,
    phone VARCHAR(50) NOT NULL,
    email VARCHAR(255) NOT NULL,
    website VARCHAR(255),
    verification_status ENUM('PENDING', 'VERIFIED', 'REJECTED') DEFAULT 'VERIFIED',
    capacity INT DEFAULT 50,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

-- 3. Shelter Staff Mapping Table
CREATE TABLE IF NOT EXISTS shelter_staff (
    id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NOT NULL,
    shelter_id INT NOT NULL,
    position VARCHAR(100) DEFAULT 'Staff Member',
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (shelter_id) REFERENCES shelters(id) ON DELETE CASCADE
);

-- 4. Adopters Table
CREATE TABLE IF NOT EXISTS adopters (
    id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NOT NULL UNIQUE,
    address TEXT,
    city VARCHAR(100),
    housing_type ENUM('APARTMENT', 'HOUSE', 'CONDO', 'TOWNHOUSE') DEFAULT 'HOUSE',
    own_or_rent ENUM('OWN', 'RENT') DEFAULT 'OWN',
    landlord_permission BOOLEAN DEFAULT TRUE,
    has_yard BOOLEAN DEFAULT TRUE,
    yard_fenced BOOLEAN DEFAULT TRUE,
    household_members INT DEFAULT 1,
    has_children BOOLEAN DEFAULT FALSE,
    has_other_pets BOOLEAN DEFAULT FALSE,
    pet_experience ENUM('BEGINNER', 'INTERMEDIATE', 'EXPERIENCED') DEFAULT 'INTERMEDIATE',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

-- 5. Pets Table
CREATE TABLE IF NOT EXISTS pets (
    id INT AUTO_INCREMENT PRIMARY KEY,
    shelter_id INT NOT NULL,
    name VARCHAR(100) NOT NULL,
    species ENUM('Dog', 'Cat', 'Rabbit', 'Bird', 'Other') NOT NULL,
    breed VARCHAR(100) NOT NULL,
    age_months INT NOT NULL,
    gender ENUM('Male', 'Female') NOT NULL,
    size ENUM('Small', 'Medium', 'Large', 'Extra Large') NOT NULL,
    weight_lbs DECIMAL(5,2),
    energy_level ENUM('Low', 'Moderate', 'High', 'Very High') NOT NULL,
    temperament VARCHAR(255),
    description TEXT,
    child_friendly BOOLEAN DEFAULT TRUE,
    dog_friendly BOOLEAN DEFAULT TRUE,
    cat_friendly BOOLEAN DEFAULT TRUE,
    apartment_friendly BOOLEAN DEFAULT TRUE,
    house_trained BOOLEAN DEFAULT TRUE,
    leash_trained BOOLEAN DEFAULT TRUE,
    grooming_requirement ENUM('Low', 'Moderate', 'High') DEFAULT 'Low',
    exercise_requirement ENUM('Low', 'Moderate', 'High') DEFAULT 'Moderate',
    special_needs BOOLEAN DEFAULT FALSE,
    special_needs_notes TEXT,
    medical_status VARCHAR(255) DEFAULT 'Healthy & Vaccinated',
    adoption_status ENUM('Available', 'Pending', 'Adopted', 'Fostered', 'Medical Hold') DEFAULT 'Available',
    location VARCHAR(255) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (shelter_id) REFERENCES shelters(id) ON DELETE CASCADE
);

-- 6. Pet Photos Table
CREATE TABLE IF NOT EXISTS pet_photos (
    id INT AUTO_INCREMENT PRIMARY KEY,
    pet_id INT NOT NULL,
    photo_url VARCHAR(500) NOT NULL,
    is_primary BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (pet_id) REFERENCES pets(id) ON DELETE CASCADE
);

-- 7. Pet Medical Records
CREATE TABLE IF NOT EXISTS pet_medical_records (
    id INT AUTO_INCREMENT PRIMARY KEY,
    pet_id INT NOT NULL,
    vet_user_id INT,
    record_date DATE NOT NULL,
    condition_title VARCHAR(255) NOT NULL,
    treatment_notes TEXT NOT NULL,
    medication VARCHAR(255),
    allergies VARCHAR(255),
    next_due_date DATE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (pet_id) REFERENCES pets(id) ON DELETE CASCADE,
    FOREIGN KEY (vet_user_id) REFERENCES users(id) ON DELETE SET NULL
);

-- 8. Pet Vaccinations
CREATE TABLE IF NOT EXISTS pet_vaccinations (
    id INT AUTO_INCREMENT PRIMARY KEY,
    pet_id INT NOT NULL,
    vaccine_name VARCHAR(100) NOT NULL,
    date_administered DATE NOT NULL,
    next_due_date DATE,
    administered_by VARCHAR(255),
    FOREIGN KEY (pet_id) REFERENCES pets(id) ON DELETE CASCADE
);

-- 9. Pet Behavior Records
CREATE TABLE IF NOT EXISTS pet_behavior_records (
    id INT AUTO_INCREMENT PRIMARY KEY,
    pet_id INT NOT NULL,
    assessor_id INT,
    aggression_level ENUM('None', 'Low', 'Moderate', 'High') DEFAULT 'None',
    socialization_score INT DEFAULT 8, -- 1 to 10
    separation_anxiety BOOLEAN DEFAULT FALSE,
    behavior_notes TEXT,
    assessed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (pet_id) REFERENCES pets(id) ON DELETE CASCADE
);

-- 10. Adopter Lifestyle Assessments
CREATE TABLE IF NOT EXISTS adopter_assessments (
    id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NOT NULL,
    daily_free_time_hours INT NOT NULL,
    working_schedule ENUM('REMOTE', 'HYBRID', 'OFFICE', 'FLEXIBLE') NOT NULL,
    activity_level ENUM('SEDENTARY', 'MODERATE', 'ACTIVE', 'VERY_ACTIVE') NOT NULL,
    travel_frequency ENUM('NEVER', 'SELDOM', 'MONTHLY', 'FREQUENT') NOT NULL,
    pet_experience ENUM('BEGINNER', 'INTERMEDIATE', 'EXPERIENCED') NOT NULL,
    housing_type ENUM('APARTMENT', 'HOUSE', 'CONDO', 'TOWNHOUSE') NOT NULL,
    has_yard BOOLEAN DEFAULT FALSE,
    yard_fenced BOOLEAN DEFAULT FALSE,
    living_space_sqft INT DEFAULT 1000,
    landlord_allows_pets BOOLEAN DEFAULT TRUE,
    has_children BOOLEAN DEFAULT FALSE,
    has_elderly BOOLEAN DEFAULT FALSE,
    has_other_pets BOOLEAN DEFAULT FALSE,
    preferred_species VARCHAR(50) DEFAULT 'Dog',
    preferred_age_min INT DEFAULT 0,
    preferred_age_max INT DEFAULT 180,
    preferred_size VARCHAR(50) DEFAULT 'Medium',
    preferred_gender VARCHAR(20) DEFAULT 'Any',
    training_willingness ENUM('LOW', 'MODERATE', 'HIGH') DEFAULT 'MODERATE',
    grooming_willingness ENUM('LOW', 'MODERATE', 'HIGH') DEFAULT 'MODERATE',
    special_needs_willingness BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

-- 11. Match Scores Cache
CREATE TABLE IF NOT EXISTS match_scores (
    id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NOT NULL,
    pet_id INT NOT NULL,
    score INT NOT NULL,
    classification VARCHAR(50) NOT NULL,
    reasons JSON,
    considerations JSON,
    calculated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (pet_id) REFERENCES pets(id) ON DELETE CASCADE,
    UNIQUE KEY user_pet_match (user_id, pet_id)
);

-- 12. Adoption Applications Table
CREATE TABLE IF NOT EXISTS adoption_applications (
    id INT AUTO_INCREMENT PRIMARY KEY,
    pet_id INT NOT NULL,
    adopter_user_id INT NOT NULL,
    status ENUM('Submitted', 'Under Review', 'Interview', 'Approved', 'Rejected', 'Completed', 'Withdrawn') DEFAULT 'Submitted',
    housing_details TEXT NOT NULL,
    experience_details TEXT NOT NULL,
    reason_for_adoption TEXT NOT NULL,
    care_plan TEXT NOT NULL,
    agreement_consent BOOLEAN DEFAULT TRUE,
    shelter_notes TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (pet_id) REFERENCES pets(id) ON DELETE CASCADE,
    FOREIGN KEY (adopter_user_id) REFERENCES users(id) ON DELETE CASCADE
);

-- 13. Application Status History
CREATE TABLE IF NOT EXISTS application_status_history (
    id INT AUTO_INCREMENT PRIMARY KEY,
    application_id INT NOT NULL,
    previous_status VARCHAR(50),
    new_status VARCHAR(50) NOT NULL,
    changed_by_user_id INT,
    notes TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (application_id) REFERENCES adoption_applications(id) ON DELETE CASCADE
);

-- 14. Favorites Table
CREATE TABLE IF NOT EXISTS favorites (
    id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NOT NULL,
    pet_id INT NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (pet_id) REFERENCES pets(id) ON DELETE CASCADE,
    UNIQUE KEY user_pet_fav (user_id, pet_id)
);

-- 15. Foster Profiles
CREATE TABLE IF NOT EXISTS foster_profiles (
    id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NOT NULL UNIQUE,
    capacity INT DEFAULT 2,
    preferred_species VARCHAR(100) DEFAULT 'Dog, Cat',
    preferred_size VARCHAR(100) DEFAULT 'Small, Medium',
    experience_years INT DEFAULT 3,
    availability_status ENUM('AVAILABLE', 'BUSY', 'INACTIVE') DEFAULT 'AVAILABLE',
    home_notes TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

-- 16. Foster Assignments
CREATE TABLE IF NOT EXISTS foster_assignments (
    id INT AUTO_INCREMENT PRIMARY KEY,
    pet_id INT NOT NULL,
    foster_user_id INT NOT NULL,
    shelter_id INT NOT NULL,
    start_date DATE NOT NULL,
    end_date DATE,
    status ENUM('Pending', 'Active', 'Completed', 'Cancelled') DEFAULT 'Pending',
    notes TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (pet_id) REFERENCES pets(id) ON DELETE CASCADE,
    FOREIGN KEY (foster_user_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (shelter_id) REFERENCES shelters(id) ON DELETE CASCADE
);

-- 17. Adoptions Records
CREATE TABLE IF NOT EXISTS adoptions (
    id INT AUTO_INCREMENT PRIMARY KEY,
    pet_id INT NOT NULL UNIQUE,
    application_id INT NOT NULL UNIQUE,
    adopter_user_id INT NOT NULL,
    shelter_id INT NOT NULL,
    adoption_date DATE NOT NULL,
    adoption_fee DECIMAL(10,2) DEFAULT 150.00,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (pet_id) REFERENCES pets(id),
    FOREIGN KEY (application_id) REFERENCES adoption_applications(id),
    FOREIGN KEY (adopter_user_id) REFERENCES users(id),
    FOREIGN KEY (shelter_id) REFERENCES shelters(id)
);

-- 18. Post-Adoption Surveys
CREATE TABLE IF NOT EXISTS post_adoption_surveys (
    id INT AUTO_INCREMENT PRIMARY KEY,
    adoption_id INT NOT NULL,
    survey_period ENUM('WEEK_1', 'WEEK_2', 'WEEK_3', 'MONTH_1') NOT NULL,
    adapting_well BOOLEAN DEFAULT TRUE,
    eating_normally BOOLEAN DEFAULT TRUE,
    sleeping_normally BOOLEAN DEFAULT TRUE,
    behavior_issues BOOLEAN DEFAULT FALSE,
    aggression_noted BOOLEAN DEFAULT FALSE,
    facing_difficulties BOOLEAN DEFAULT FALSE,
    notes TEXT,
    risk_level ENUM('LOW_CONCERN', 'NEEDS_ATTENTION', 'HIGH_CONCERN') DEFAULT 'LOW_CONCERN',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (adoption_id) REFERENCES adoptions(id) ON DELETE CASCADE
);

-- 19. Support Resources
CREATE TABLE IF NOT EXISTS support_resources (
    id INT AUTO_INCREMENT PRIMARY KEY,
    title VARCHAR(255) NOT NULL,
    category ENUM('TRAINING', 'FEEDING', 'BEHAVIOR', 'HEALTH', 'SETTLING_IN') NOT NULL,
    content TEXT NOT NULL,
    target_period ENUM('ALL', 'WEEK_1', 'WEEK_2', 'WEEK_3', 'MONTH_1') DEFAULT 'ALL',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 20. Notifications
CREATE TABLE IF NOT EXISTS notifications (
    id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NOT NULL,
    title VARCHAR(255) NOT NULL,
    message TEXT NOT NULL,
    is_read BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

-- 21. Audit Logs
CREATE TABLE IF NOT EXISTS audit_logs (
    id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT,
    action VARCHAR(255) NOT NULL,
    details TEXT,
    ip_address VARCHAR(45),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
