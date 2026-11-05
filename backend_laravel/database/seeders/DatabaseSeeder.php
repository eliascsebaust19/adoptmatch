<?php

namespace Database\Seeders;

use App\Models\AdoptionRequest;
use App\Models\Pet;
use App\Models\PetImage;
use App\Models\Shelter;
use App\Models\User;
use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\Hash;

class DatabaseSeeder extends Seeder
{
    public function run(): void
    {
        // 1. Shelter User
        $shelterUser = User::create([
            'name' => 'Dhaka Animal Rescue',
            'email' => 'shelter@adoptmatch.com',
            'phone' => '+880 1712 345678',
            'role' => 'shelter',
            'avatar' => 'https://images.unsplash.com/photo-1544005313-94ddf0286df2?auto=format&fit=crop&w=400&q=80',
            'location_lat' => 23.7925,
            'location_lng' => 90.4078,
            'password' => Hash::make('password123'),
            'email_verified_at' => now(),
        ]);

        Shelter::create([
            'user_id' => $shelterUser->id,
            'organization_name' => 'Dhaka Animal Rescue Society',
            'license_number' => 'DCC-VET-2024-88',
            'address' => 'Road 11, Banani, Dhaka-1213',
            'phone' => '+880 1712 345678',
            'rating' => 4.9,
            'is_verified' => true,
        ]);

        // 2. Demo Adopter
        $adopter = User::create([
            'name' => 'Elias Ahmed',
            'email' => 'elias3224@gmail.com',
            'phone' => '+880 1711 234567',
            'role' => 'adopter',
            'avatar' => 'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?auto=format&fit=crop&w=400&q=80',
            'location_lat' => 23.7808,
            'location_lng' => 90.4152,
            'password' => Hash::make('password123'),
            'email_verified_at' => now(),
        ]);

        // 3. Demo Pets
        $petsData = [
            [
                'name' => 'Luna',
                'species' => 'dog',
                'breed' => 'Golden Retriever Mix',
                'age_months' => 14,
                'gender' => 'female',
                'size' => 'large',
                'description' => 'Luna is a joyful and gentle family retriever. She loves open gardens, playing fetch, and bonding with children.',
                'image' => 'https://images.unsplash.com/photo-1552053831-71594a27632d?auto=format&fit=crop&w=800&q=80',
                'location_lat' => 23.7925,
                'location_lng' => 90.4078,
                'location_city' => 'Banani, Dhaka',
                'match_score' => 98,
            ],
            [
                'name' => 'Mimi',
                'species' => 'cat',
                'breed' => 'Domestic Shorthair (দেশি বিড়াল)',
                'age_months' => 8,
                'gender' => 'female',
                'size' => 'small',
                'description' => 'Mimi is an energetic and affectionate rescued Deshi cat. Healthy, vaccinated, and very loyal to her humans.',
                'image' => 'https://images.unsplash.com/photo-1514888286974-6c03e2ca1dba?auto=format&fit=crop&w=800&q=80',
                'location_lat' => 23.7465,
                'location_lng' => 90.3760,
                'location_city' => 'Dhanmondi, Dhaka',
                'match_score' => 96,
            ],
            [
                'name' => 'Charlie',
                'species' => 'dog',
                'breed' => 'Beagle',
                'age_months' => 20,
                'gender' => 'male',
                'size' => 'medium',
                'description' => 'Curious and friendly companion with an adventurous spirit. Great with cats and apartment living.',
                'image' => 'https://images.unsplash.com/photo-1537151625747-768eb6cf92b2?auto=format&fit=crop&w=800&q=80',
                'location_lat' => 23.7937,
                'location_lng' => 90.4066,
                'location_city' => 'Gulshan, Dhaka',
                'match_score' => 92,
            ],
            [
                'name' => 'Mochi',
                'species' => 'cat',
                'breed' => 'Calico Cat',
                'age_months' => 12,
                'gender' => 'female',
                'size' => 'small',
                'description' => 'Quiet, calm indoor cat who enjoys sunbathing on windowsills and gentle head scratches.',
                'image' => 'https://images.unsplash.com/photo-1573865526739-10659fec78a5?auto=format&fit=crop&w=800&q=80',
                'location_lat' => 23.8103,
                'location_lng' => 90.4125,
                'location_city' => 'Uttara, Dhaka',
                'match_score' => 90,
            ],
        ];

        foreach ($petsData as $item) {
            $pet = Pet::create([
                'owner_id' => $shelterUser->id,
                'name' => $item['name'],
                'species' => $item['species'],
                'breed' => $item['breed'],
                'age_months' => $item['age_months'],
                'gender' => $item['gender'],
                'size' => $item['size'],
                'vaccination_status' => 'fully_vaccinated',
                'is_spayed_neutered' => true,
                'description' => $item['description'],
                'medical_history' => 'Dewormed, vaccinated, certified healthy by shelter veterinarian.',
                'location_lat' => $item['location_lat'],
                'location_lng' => $item['location_lng'],
                'location_city' => $item['location_city'],
                'adoption_status' => 'available',
                'qr_hash' => 'ADOPT-PET-' . strtoupper($item['name']) . '-2026',
                'match_score' => $item['match_score'],
            ]);

            PetImage::create([
                'pet_id' => $pet->id,
                'image_url' => $item['image'],
                'is_primary' => true,
            ]);
        }

        // 4. Sample Adoption Request
        $mimiPet = Pet::where('name', 'Mimi')->first();
        if ($mimiPet) {
            AdoptionRequest::create([
                'reference_no' => 'AM-APP-89214',
                'pet_id' => $mimiPet->id,
                'requester_id' => $adopter->id,
                'owner_id' => $shelterUser->id,
                'status' => 'home_visit',
                'applicant_data' => [
                    'applicantName' => 'Elias Ahmed',
                    'applicantPhone' => '+880 1711 234567',
                    'applicantEmail' => 'elias3224@gmail.com',
                    'address' => 'House 42, Road 11, Banani, Dhaka-1213',
                    'housingType' => 'Apartment',
                    'ownershipStatus' => 'Owned',
                    'yardType' => 'Balcony with Safety Netting',
                    'petLivingSpace' => 'Indoor Only',
                    'totalAdults' => 2,
                    'hasKids' => false,
                    'whyAdopt' => 'Looking for a calm, affectionate indoor companion to join our quiet home.',
                ],
                'reviewer_notes' => 'Virtual interview passed. Home visit scheduled for Sunday 4:00 PM.',
                'home_visit_date' => now()->addDays(2),
                'is_signed' => true,
                'signature_data' => 'DIGITAL_SIGNATURE_VERIFIED',
            ]);
        }
    }
}

