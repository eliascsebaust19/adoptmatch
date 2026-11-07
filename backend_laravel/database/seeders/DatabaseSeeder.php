<?php

namespace Database\Seeders;

use App\Models\User;
use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\Hash;

class DatabaseSeeder extends Seeder
{
    /**
     * Clean production database seeder.
     * Seeds essential system administrator roles without any dummy pets or mock user activity.
     */
    public function run(): void
    {
        // 1. System Roles Initial Accounts (Clean Production Defaults)
        $admin = User::firstOrCreate(
            ['email' => 'admin@adoptmatch.com'],
            [
                'name' => 'System Administrator',
                'password' => Hash::make(env('ADMIN_DEFAULT_PASSWORD', 'AdoptMatchAdmin@2026')),
                'role' => 'admin',
                'phone' => '+880 1800 000001',
                'avatar' => 'https://3kht7mdtcvdag9ff.private.blob.vercel-storage.com/pets/pet_1.jpg',
                'email_verified_at' => now(),
            ]
        );

        $moderator = User::firstOrCreate(
            ['email' => 'moderator@adoptmatch.com'],
            [
                'name' => 'Community Moderator',
                'password' => Hash::make(env('MODERATOR_DEFAULT_PASSWORD', 'AdoptMatchMod@2026')),
                'role' => 'moderator',
                'phone' => '+880 1800 000002',
                'avatar' => 'https://3kht7mdtcvdag9ff.private.blob.vercel-storage.com/pets/pet_2.jpg',
                'email_verified_at' => now(),
            ]
        );

        // 2. Verified Default Shelter Partner
        $shelter = User::firstOrCreate(
            ['email' => 'shelter@adoptmatch.com'],
            [
                'name' => 'Central Rescue Organization',
                'password' => Hash::make(env('SHELTER_DEFAULT_PASSWORD', 'AdoptMatchShelter@2026')),
                'role' => 'shelter',
                'phone' => '+880 1800 000003',
                'avatar' => 'https://3kht7mdtcvdag9ff.private.blob.vercel-storage.com/pets/pet_3.jpg',
                'email_verified_at' => now(),
            ]
        );

        if (!$shelter->shelter()->exists()) {
            $shelter->shelter()->create([
                'organization_name' => 'Central Animal Rescue Network',
                'license_number' => 'BD-RESCUE-2026-01',
                'address' => 'Dhaka, Bangladesh',
                'phone' => '+880 1800 000003',
                'rating' => 5.0,
                'is_verified' => true,
            ]);
        }

        // All pet, adoption request, and chat message tables remain fresh and empty for real production users.
    }
}
