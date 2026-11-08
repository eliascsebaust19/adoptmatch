<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Favorite;
use App\Models\Pet;
use App\Models\PetImage;
use Illuminate\Http\Request;
use Illuminate\Support\Str;

class PetController extends Controller
{
    /**
     * Tinder Swipe Card Stack.
     * Returns up to 20 pets the current user has not yet swiped on.
     */
    public function getSwipeStack(Request $request)
    {
        $userId = $request->user()->id;

        $swipedPetIds = Favorite::where('user_id', $userId)
            ->pluck('pet_id')
            ->toArray();

        $pets = Pet::with(['images', 'owner:id,name,avatar,role,phone'])
            ->where('adoption_status', 'available')
            ->where('owner_id', '!=', $userId)
            ->whereNotIn('id', $swipedPetIds)
            ->inRandomOrder()
            ->take(20)
            ->get();

        return response()->json([
            'status' => 'success',
            'count' => $pets->count(),
            'data' => $pets,
        ], 200);
    }

    /**
     * Record Swipe Action (Like or Dislike).
     */
    public function swipeLike(Request $request, $id)
    {
        $request->validate([
            'direction' => 'required|in:like,dislike',
        ]);

        $pet = Pet::findOrFail($id);
        $userId = $request->user()->id;

        $favorite = Favorite::updateOrCreate(
            [
                'user_id' => $userId,
                'pet_id' => $pet->id,
            ],
            [
                'swipe_direction' => $request->direction,
            ]
        );

        return response()->json([
            'status' => 'success',
            'message' => "Pet marked as {$request->direction}",
            'data' => $favorite,
        ], 200);
    }

    /** Favorites are separate from swipe decisions and shared across devices. */
    public function getFavorites(Request $request)
    {
        $favorites = Favorite::where('user_id', $request->user()->id)
            ->where('is_favorite', true)->with(['pet.images', 'pet.owner:id,name,avatar'])
            ->get()->pluck('pet')->filter()->values();
        return response()->json(['status' => 'success', 'data' => $favorites]);
    }

    public function getFavorite(Request $request, $id)
    {
        Pet::findOrFail($id);
        $favorite = Favorite::where('user_id', $request->user()->id)->where('pet_id', $id)->first();
        return response()->json(['status' => 'success', 'data' => ['is_favorite' => (bool) ($favorite && $favorite->is_favorite)]]);
    }

    public function addFavorite(Request $request, $id)
    {
        Pet::findOrFail($id);
        Favorite::updateOrCreate(
            ['user_id' => $request->user()->id, 'pet_id' => $id],
            ['is_favorite' => true]
        );
        return response()->json(['status' => 'success', 'data' => ['is_favorite' => true]]);
    }

    public function removeFavorite(Request $request, $id)
    {
        Pet::findOrFail($id);
        Favorite::updateOrCreate(
            ['user_id' => $request->user()->id, 'pet_id' => $id],
            ['is_favorite' => false]
        );
        return response()->json(['status' => 'success', 'data' => ['is_favorite' => false]]);
    }

    /**
     * Proximity Search using Haversine Distance Formula.
     */
    public function getNearbyPets(Request $request)
    {
        // Accept both spellings, then validate the resolved values so that a
        // legitimate 0 coordinate is not treated as "missing".
        $request->merge([
            'latitude' => $request->input('latitude', $request->input('lat')),
            'longitude' => $request->input('longitude', $request->input('lng')),
            'radius_km' => $request->input('radius_km', $request->input('radius', 30)),
        ]);

        $request->validate([
            'latitude' => 'required|numeric|between:-90,90',
            'longitude' => 'required|numeric|between:-180,180',
            'radius_km' => 'nullable|numeric|min:0|max:150',
            'species' => 'nullable|string',
        ]);

        $lat = (float) $request->input('latitude');
        $lng = (float) $request->input('longitude');
        $radius = (float) $request->input('radius_km', 30);

        $haversine = "(6371 * acos(least(1.0, cos(radians(?)) 
                      * cos(radians(location_lat)) 
                      * cos(radians(location_lng) - radians(?)) 
                      + sin(radians(?)) 
                      * sin(radians(location_lat)))))";

        $query = Pet::select('*')
            ->selectRaw("{$haversine} AS distance_km", [$lat, $lng, $lat])
            ->where('adoption_status', 'available')
            ->whereNotNull('location_lat')
            ->whereNotNull('location_lng');

        if ($request->filled('species')) {
            $query->where('species', strtolower($request->species));
        }

        $pets = $query->having('distance_km', '<=', $radius)
            ->orderBy('distance_km', 'asc')
            ->with(['images', 'owner:id,name,avatar'])
            ->paginate(15);

        return response()->json([
            'status' => 'success',
            'user_location' => ['lat' => $lat, 'lng' => $lng],
            'radius_km' => $radius,
            'data' => $pets,
        ], 200);
    }

    /**
     * Browse Catalog with Filters.
     */
    public function index(Request $request)
    {
        $query = Pet::with(['images', 'owner:id,name,avatar']);

        if ($request->filled('species') && $request->species !== 'all') {
            $query->where('species', strtolower($request->species));
        }

        if ($request->filled('status')) {
            $query->where('adoption_status', $request->status);
        } else {
            $query->where('adoption_status', 'available');
        }

        if ($request->filled('search')) {
            $searchTerm = '%' . $request->search . '%';
            $query->where(function ($q) use ($searchTerm) {
                $q->where('name', 'like', $searchTerm)
                  ->orWhere('breed', 'like', $searchTerm)
                  ->orWhere('description', 'like', $searchTerm);
            });
        }

        $pets = $query->orderBy('match_score', 'desc')->paginate(20);

        return response()->json([
            'status' => 'success',
            'data' => $pets,
        ], 200);
    }

    /**
     * Single Pet Details with Images and Owner/Shelter.
     */
    public function show($id)
    {
        $pet = Pet::with(['images', 'owner.shelter'])->findOrFail($id);

        return response()->json([
            'status' => 'success',
            'data' => $pet,
        ], 200);
    }

    /** Listings owned by the authenticated shelter/user. */
    public function myPets(Request $request)
    {
        $pets = Pet::with('images')->where('owner_id', $request->user()->id)
            ->orderBy('created_at', 'desc')->paginate(20);
        return response()->json(['status' => 'success', 'data' => $pets], 200);
    }

    /**
     * Create New Pet Listing with Multiple Images.
     */
    public function store(Request $request)
    {
        $request->validate([
            'name' => 'required|string|max:100',
            'species' => 'required|string|max:50',
            'breed' => 'required|string|max:100',
            'age_months' => 'required|integer|min:1',
            'gender' => 'required|in:male,female,unknown',
            'size' => 'required|in:small,medium,large,giant',
            'vaccination_status' => 'required|string',
            'description' => 'required|string',
            'location_city' => 'nullable|string',
            'location_lat' => 'nullable|numeric',
            'location_lng' => 'nullable|numeric',
            'adoption_fee' => 'nullable|numeric|min:0',
            'images' => 'required|array|min:1|max:5',
            'images.*' => 'required|url:http,https|max:2048',
        ]);

        $pet = Pet::create([
            'owner_id' => $request->user()->id,
            'name' => $request->name,
            'species' => strtolower($request->species),
            'breed' => $request->breed,
            'age_months' => $request->age_months,
            'gender' => $request->gender,
            'size' => $request->size,
            'vaccination_status' => $request->vaccination_status,
            'is_spayed_neutered' => $request->boolean('is_spayed_neutered', false),
            'description' => $request->description,
            'medical_history' => $request->input('medical_history'),
            'location_city' => $request->location_city ?? 'Dhaka',
            'location_lat' => $request->location_lat,
            'location_lng' => $request->location_lng,
            'adoption_fee' => $request->adoption_fee ?? 0.00,
            'adoption_status' => 'available',
            'qr_hash' => 'ADOPT-PET-' . strtoupper(Str::random(12)),
            'match_score' => 0, // Compatibility is calculated by the matching service, not invented here.
        ]);

        foreach ($request->images as $index => $imageUrl) {
            PetImage::create([
                'pet_id' => $pet->id,
                'image_url' => $imageUrl,
                'is_primary' => $index === 0,
            ]);
        }

        return response()->json([
            'status' => 'success',
            'message' => 'Pet listing posted successfully',
            'data' => $pet->load('images'),
        ], 201);
    }

    /**
     * Update Pet Details.
     */
    public function update(Request $request, $id)
    {
        $pet = Pet::where('owner_id', $request->user()->id)->findOrFail($id);
        $request->validate([
            'name' => 'sometimes|required|string|max:100',
            'species' => 'sometimes|required|string|max:50',
            'breed' => 'sometimes|required|string|max:100',
            'age_months' => 'sometimes|required|integer|min:1|max:600',
            'gender' => 'sometimes|required|in:male,female,unknown',
            'size' => 'sometimes|required|in:small,medium,large,giant',
            'vaccination_status' => 'sometimes|required|string|max:100',
            'is_spayed_neutered' => 'sometimes|boolean',
            'description' => 'sometimes|required|string',
            'medical_history' => 'nullable|string',
            'adoption_status' => 'sometimes|required|in:available,pending,adopted',
            'location_city' => 'nullable|string|max:150',
            'location_lat' => 'nullable|numeric|between:-90,90',
            'location_lng' => 'nullable|numeric|between:-180,180',
        ]);
        $pet->update($request->only([
            'name',
            'species',
            'breed',
            'age_months',
            'gender',
            'size',
            'vaccination_status',
            'is_spayed_neutered',
            'description',
            'medical_history',
            'adoption_status',
            'location_city',
            'location_lat',
            'location_lng',
        ]));

        return response()->json([
            'status' => 'success',
            'message' => 'Pet updated successfully',
            'data' => $pet->load('images'),
        ], 200);
    }

    /**
     * Delete Pet.
     */
    public function destroy(Request $request, $id)
    {
        $pet = Pet::where('owner_id', $request->user()->id)->findOrFail($id);
        $pet->delete();

        return response()->json([
            'status' => 'success',
            'message' => 'Pet listing deleted successfully',
        ], 200);
    }
}

