<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\AdoptionRequest;
use App\Models\Pet;
use App\Services\FcmService;
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

        $pet = Pet::with('owner')->findOrFail($request->pet_id);
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

        // Push notification to pet owner / shelter
        if ($pet->owner && !empty($pet->owner->fcm_token)) {
            FcmService::sendNotification(
                $pet->owner->fcm_token,
                "New Adoption Application for {$pet->name}!",
                "{$request->applicant_data['applicantName']} just submitted an adoption application.",
                ['type' => 'adoption_request', 'reference_no' => $referenceNo, 'pet_id' => (string)$pet->id]
            );
        }

        return response()->json([
            'status' => 'success',
            'message' => 'Adoption application successfully recorded',
            'reference_no' => $referenceNo,
            'data' => $application->load(['pet', 'owner']),
        ], 201);
    }

    /**
     * List user submitted or received applications.
     */
    public function index(Request $request)
    {
        $user = $request->user();
        $type = $request->query('type', 'submitted'); // 'submitted' or 'received'

        $query = AdoptionRequest::with(['pet.images', 'requester', 'owner']);

        if ($type === 'received') {
            $query->where('owner_id', $user->id);
        } else {
            $query->where('requester_id', $user->id);
        }

        if ($request->filled('status')) {
            $query->where('status', $request->status);
        }

        $applications = $query->orderBy('created_at', 'desc')->paginate(15);

        return response()->json([
            'status' => 'success',
            'data' => $applications,
        ], 200);
    }

    /**
     * Application Details by ID.
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

        $application = AdoptionRequest::with(['pet', 'requester'])->where('owner_id', $user->id)->findOrFail($id);

        $application->update([
            'status' => $request->status,
            'reviewer_notes' => $request->reviewer_notes ?? $application->reviewer_notes,
            'home_visit_date' => $request->home_visit_date ?? $application->home_visit_date,
        ]);

        // If approved, mark the pet status as adopted
        if ($request->status === 'approved') {
            $application->pet->update(['adoption_status' => 'adopted']);
        }

        // Push notification to applicant
        if ($application->requester && !empty($application->requester->fcm_token)) {
            $petName = $application->pet ? $application->pet->name : 'your pet';
            $title = $request->status === 'approved' ? "🎉 Application Approved!" : "Update on your adoption of {$petName}";
            $body = "Your application status has been updated to: " . strtoupper($request->status);

            FcmService::sendNotification(
                $application->requester->fcm_token,
                $title,
                $body,
                ['type' => 'status_update', 'application_id' => (string)$application->id, 'status' => $request->status]
            );
        }

        return response()->json([
            'status' => 'success',
            'message' => "Application status updated to {$request->status}",
            'data' => $application->load(['pet', 'requester']),
        ], 200);
    }
}
