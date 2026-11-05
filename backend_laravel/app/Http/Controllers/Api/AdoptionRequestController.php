<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\AdoptionRequest;
use App\Models\Pet;
use Illuminate\Http\Request;

class AdoptionRequestController extends Controller
{
    /**
     * Submit a Formal Adoption Application Dossier.
     */
    public function store(Request $request)
    {
        $request->validate([
            'pet_id' => 'required|exists:pets,id',
            'applicant_data' => 'required|array',
            'applicant_data.applicantName' => 'required|string',
            'applicant_data.applicantPhone' => 'required|string',
            'applicant_data.address' => 'required|string',
            'applicant_data.housingType' => 'required|string',
            'signature_data' => 'nullable|string',
        ]);

        $pet = Pet::findOrFail($request->pet_id);
        $user = $request->user();

        // Prevent duplicate pending applications for the same pet
        $existing = AdoptionRequest::where('pet_id', $pet->id)
            ->where('requester_id', $user->id)
            ->whereNotIn('status', ['rejected'])
            ->first();

        if ($existing) {
            return response()->json([
                'status' => 'error',
                'message' => 'You already have an active application (' . $existing->reference_no . ') for this pet.',
                'data' => $existing,
            ], 409);
        }

        $referenceNo = 'AM-APP-' . rand(10000, 99999);

        $application = AdoptionRequest::create([
            'reference_no' => $referenceNo,
            'pet_id' => $pet->id,
            'requester_id' => $user->id,
            'owner_id' => $pet->owner_id,
            'status' => 'submitted',
            'applicant_data' => $request->applicant_data,
            'reviewer_notes' => 'Application received. Pending initial background verification.',
            'is_signed' => true,
            'signature_data' => $request->signature_data ?? 'DIGITAL_SIGNATURE_VERIFIED',
        ]);

        return response()->json([
            'status' => 'success',
            'message' => 'Adoption application successfully recorded',
            'data' => $application->load(['pet.images', 'owner']),
        ], 201);
    }

    /**
     * List User's Adoption Applications (Both sent and received).
     */
    public function index(Request $request)
    {
        $user = $request->user();
        $type = $request->query('type', 'sent'); // 'sent' or 'received'

        if ($type === 'received' || $user->role === 'shelter' || $user->role === 'admin') {
            $applications = AdoptionRequest::where('owner_id', $user->id)
                ->with(['pet.images', 'requester'])
                ->orderBy('created_at', 'desc')
                ->get();
        } else {
            $applications = AdoptionRequest::where('requester_id', $user->id)
                ->with(['pet.images', 'owner'])
                ->orderBy('created_at', 'desc')
                ->get();
        }

        return response()->json([
            'status' => 'success',
            'count' => $applications->count(),
            'data' => $applications,
        ], 200);
    }

    /**
     * View Single Application Dossier.
     */
    public function show(Request $request, $id)
    {
        $user = $request->user();

        $application = AdoptionRequest::with(['pet.images', 'requester', 'owner'])
            ->where(function ($q) use ($user) {
                $q->where('requester_id', $user->id)
                  ->orWhere('owner_id', $user->id);
            })
            ->findOrFail($id);

        return response()->json([
            'status' => 'success',
            'data' => $application,
        ], 200);
    }

    /**
     * Update Application Review Status (Shelter/Owner Action).
     */
    public function updateStatus(Request $request, $id)
    {
        $request->validate([
            'status' => 'required|in:submitted,under_review,home_visit,foster_trial,approved,rejected',
            'reviewer_notes' => 'nullable|string',
            'home_visit_date' => 'nullable|date',
        ]);

        $user = $request->user();

        $application = AdoptionRequest::where('owner_id', $user->id)->findOrFail($id);

        $application->update([
            'status' => $request->status,
            'reviewer_notes' => $request->reviewer_notes ?? $application->reviewer_notes,
            'home_visit_date' => $request->home_visit_date ?? $application->home_visit_date,
        ]);

        // If approved, mark the pet status as adopted
        if ($request->status === 'approved') {
            $application->pet->update(['adoption_status' => 'adopted']);
        }

        return response()->json([
            'status' => 'success',
            'message' => "Application status updated to {$request->status}",
            'data' => $application->load(['pet', 'requester']),
        ], 200);
    }
}

