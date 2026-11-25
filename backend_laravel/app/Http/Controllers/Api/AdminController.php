<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use Illuminate\Http\Request;
use App\Models\Pet;
use App\Models\AdoptionRequest;
use App\Models\Shelter;
use App\Models\User;

class AdminController extends Controller
{
    /**
     * Return administrative KPI statistics.
     */
    public function stats(Request $request)
    {
        $activeRescues = Pet::where('adoption_status', 'available')->count();
        $totalApplications = AdoptionRequest::count();
        $homeVisits = AdoptionRequest::where('status', 'home_visit_scheduled')->count();
        $trialFosters = AdoptionRequest::where('status', 'foster_trial')->count();
        $adoptionsCompleted = AdoptionRequest::where('status', 'approved')->count();
        $pendingShelters = Shelter::where('status', 'pending')->count();
        $flaggedListings = Pet::where('adoption_status', 'flagged')->orWhere('adoption_status', 'pending')->count();

        return response()->json([
            'success' => true,
            'data' => [
                'active_rescues' => $activeRescues,
                'activeRescues' => $activeRescues,
                'total_applications' => $totalApplications,
                'totalApplications' => $totalApplications,
                'home_visits' => $homeVisits,
                'homeVisits' => $homeVisits,
                'trial_fosters' => $trialFosters,
                'trialFosters' => $trialFosters,
                'adoptions_completed' => $adoptionsCompleted,
                'adoptionsCompleted' => $adoptionsCompleted,
                'totalAdoptions' => $adoptionsCompleted,
                'pending_shelters' => $pendingShelters,
                'pendingShelters' => $pendingShelters,
                'flagged_listings' => $flaggedListings,
                'flaggedListings' => $flaggedListings,
                'totalDonationsBDT' => 0,
                'revenue_bdt' => 0,
                'activeDisputes' => 0,
                'active_disputes' => 0,
            ]
        ]);
    }

    /**
     * List registered users with moderation filters.
     */
    public function users(Request $request)
    {
        $users = User::latest()->take(50)->get()->map(function ($u) {
            return [
                'id' => (string) $u->id,
                'name' => $u->name ?? '',
                'email' => $u->email ?? '',
                'phone' => $u->phone ?? '',
                'role' => $u->role ?? 'USER',
                'status' => $u->status ?? 'Active',
                'permissions' => [],
                'adoptionsCount' => 0,
                'joinedAt' => $u->created_at ? $u->created_at->toIso8601String() : null,
            ];
        });

        return response()->json([
            'success' => true,
            'data' => $users,
        ]);
    }

    /**
     * List shelters for verification.
     */
    public function shelters(Request $request)
    {
        $shelters = Shelter::latest()->take(50)->get()->map(function ($s) {
            return [
                'id' => (string) $s->id,
                'shelterName' => $s->name ?? '',
                'registrationNumber' => $s->registration_number ?? '',
                'contactPerson' => $s->contact_person ?? '',
                'email' => $s->email ?? '',
                'phone' => $s->phone ?? '',
                'city' => $s->city ?? 'Dhaka',
                'address' => $s->address ?? '',
                'nidNumber' => $s->nid_number ?? '',
                'tradeLicenseNumber' => $s->trade_license_number ?? '',
                'vetAffiliation' => $s->vet_affiliation ?? '',
                'status' => strtoupper($s->status ?? 'PENDING'),
                'documentUrls' => [],
                'submittedAt' => $s->created_at ? $s->created_at->toIso8601String() : null,
                'reviewerNotes' => $s->reviewer_notes ?? null,
                'capacity' => (int) ($s->capacity ?? 20),
            ];
        });

        return response()->json([
            'success' => true,
            'data' => $shelters,
        ]);
    }

    /**
     * List pets for moderation.
     */
    public function pets(Request $request)
    {
        $pets = Pet::with('images')->latest()->take(50)->get()->map(function ($p) {
            return [
                'id' => (string) $p->id,
                'name' => $p->name ?? '',
                'species' => $p->species ?? '',
                'breed' => $p->breed ?? '',
                'ageDisplay' => $p->age_display ?? '',
                'ageMonths' => (int) ($p->age_months ?? 0),
                'gender' => $p->gender ?? '',
                'weightKg' => (float) ($p->weight_kg ?? 0),
                'distanceKm' => 0.0,
                'matchScore' => 0,
                'imageUrl' => $p->image_url ?? ($p->images->first()->image_url ?? ''),
                'galleryUrls' => $p->images->pluck('image_url')->toArray(),
                'isUrgent' => (bool) $p->is_urgent,
                'isFeatured' => (bool) $p->is_featured,
                'isVaccinated' => (bool) $p->is_vaccinated,
                'isNeutered' => (bool) $p->is_neutered,
                'isHouseTrained' => (bool) $p->is_house_trained,
                'isKidSafe' => (bool) $p->is_kid_safe,
                'isApartmentFriendly' => (bool) $p->is_apartment_friendly,
                'shelterName' => $p->shelter_name ?? '',
                'shelterPhone' => $p->shelter_phone ?? '',
                'shelterAddress' => $p->shelter_address ?? '',
                'story' => $p->bio ?? $p->story ?? '',
                'medicalHistory' => $p->medical_history ?? '',
                'qrHash' => $p->qr_hash ?? '',
                'adoptionStatus' => $p->adoption_status ?? 'available',
                'reportsCount' => 0,
                'reportReasons' => [],
                'isBanned' => false,
                'createdAt' => $p->created_at ? $p->created_at->toIso8601String() : null,
            ];
        });

        return response()->json([
            'success' => true,
            'data' => $pets,
        ]);
    }

    /**
     * List audit log entries.
     */
    public function auditLogs(Request $request)
    {
        return response()->json([
            'success' => true,
            'data' => [],
        ]);
    }
}
