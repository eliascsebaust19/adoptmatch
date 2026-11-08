<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\User;
use Google\Client as GoogleClient;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Str;

class AuthController extends Controller
{
    /**
     * Direct Google OAuth2 Token Verification (No Firebase Required).
     */
    public function googleLogin(Request $request)
    {
        $idToken = $request->input('id_token') ?? $request->input('idToken');

        if (empty($idToken)) {
            return response()->json([
                'status' => 'error',
                'message' => 'A Google id_token is required.',
            ], 422);
        }

        try {
            $payload = null;
            $clientId = config('services.google.client_id');

            // Without an audience the signature alone does not prove the token
            // was issued for this application.
            if (empty($clientId)) {
                return response()->json([
                    'status' => 'error',
                    'message' => 'Google sign-in is not configured on this server.',
                ], 503);
            }

            try {
                $client = new GoogleClient(['client_id' => $clientId]);
                $payload = $client->verifyIdToken($idToken);
            } catch (\Exception $e) {
                \Illuminate\Support\Facades\Log::warning('Google verifyIdToken failed: ' . $e->getMessage());
                $payload = null;
            }

            if (!$payload || empty($payload['email'])) {
                return response()->json([
                    'status' => 'error',
                    'message' => 'Cryptographically valid Google ID token required. Verification failed.',
                ], 401);
            }

            // A missing claim is not proof of verification.
            $emailVerified = $payload['email_verified'] ?? false;
            if (!filter_var($emailVerified, FILTER_VALIDATE_BOOLEAN)) {
                return response()->json([
                    'status' => 'error',
                    'message' => 'Google account email is not verified.',
                ], 403);
            }

            $issuer = $payload['iss'] ?? '';
            if (!in_array($issuer, ['accounts.google.com', 'https://accounts.google.com'], true) ||
                empty($payload['sub']) || empty($payload['exp']) || (int) $payload['exp'] <= time()) {
                return response()->json(['status' => 'error',
                    'message' => 'Google token issuer, subject or expiry is invalid.'], 401);
            }
            $googleId = $payload['sub'];
            $email = $payload['email'];
            $name = $payload['name'] ?? 'AdoptMatch User';
            $avatar = $payload['picture'] ?? '';

            $user = User::where('google_id', $googleId)->first();
            if (!$user) {
                $byEmail = User::where('email', $email)->first();
                if ($byEmail && (in_array($byEmail->role, ['admin', 'shelter'], true) || !empty($byEmail->google_id))) {
                    return response()->json(['status' => 'error',
                        'message' => 'This account cannot be linked automatically. Contact support.'], 409);
                }
                $user = $byEmail;
            }
            $isNewUser = !$user;

            if (!$user) {
                $user = User::create([
                    'name' => $name,
                    'email' => $email,
                    'google_id' => $googleId,
                    'avatar' => $avatar,
                    'role' => 'adopter',
                    'password' => Hash::make(Str::random(24)),
                    'email_verified_at' => now(),
                ]);
            } else {
                $user->update([
                    'google_id' => $user->google_id ?? $googleId,
                    'avatar' => $avatar ?? $user->avatar,
                ]);
            }

            $deviceName = $request->device_name ?? 'mobile_device';
            $token = $user->createToken($deviceName)->plainTextToken;

            return response()->json([
                'status' => 'success',
                'message' => 'Google Authentication Successful',
                'access_token' => $token,
                'token_type' => 'Bearer',
                'is_new_user' => $isNewUser,
                'user' => $user->load('shelter'),
            ], 200);

        } catch (\Exception $e) {
            return response()->json([
                'status' => 'error',
                'message' => 'Google verification failed: ' . $e->getMessage(),
            ], 500);
        }
    }

    /**
     * Standard Email & Password Login.
     */
    public function emailLogin(Request $request)
    {
        $request->validate([
            'email' => 'required|email',
            'password' => 'required|string',
            'device_name' => 'nullable|string',
        ]);

        $user = User::where('email', $request->email)->first();

        if (!$user || !Hash::check($request->password, $user->password)) {
            return response()->json([
                'status' => 'error',
                'message' => 'Invalid email or password.',
            ], 401);
        }

        $deviceName = $request->device_name ?? 'mobile_app';
        $token = $user->createToken($deviceName)->plainTextToken;

        return response()->json([
            'status' => 'success',
            'message' => 'Login successful',
            'access_token' => $token,
            'token_type' => 'Bearer',
            'user' => $user->load('shelter'),
        ], 200);
    }

    /**
     * Adopter Registration.
     */
    public function register(Request $request)
    {
        $request->validate([
            'name' => 'required|string|max:255',
            'email' => 'required|email|unique:users,email',
            'password' => 'required|string|min:6',
            'phone' => 'nullable|string|max:20',
            'role' => 'nullable|in:adopter,pet_owner',
        ]);

        $user = User::create([
            'name' => $request->name,
            'email' => $request->email,
            'password' => Hash::make($request->password),
            'phone' => $request->phone,
            'role' => $request->role ?? 'adopter',
            'avatar' => null,
        ]);

        $token = $user->createToken('mobile_app')->plainTextToken;

        return response()->json([
            'status' => 'success',
            'message' => 'User registered successfully',
            'access_token' => $token,
            'token_type' => 'Bearer',
            'user' => $user,
        ], 201);
    }

    /**
     * Get Authenticated User Profile.
     */
    public function me(Request $request)
    {
        return response()->json([
            'status' => 'success',
            'user' => $request->user()->load('shelter'),
        ], 200);
    }

    /**
     * Register or Update FCM Device Token for Push Notifications.
     */
    public function updateFcmToken(Request $request)
    {
        $request->validate([
            'fcm_token' => 'required|string',
        ]);

        $request->user()->update([
            'fcm_token' => $request->fcm_token,
        ]);

        return response()->json([
            'status' => 'success',
            'message' => 'FCM Device Token registered successfully',
        ], 200);
    }

    /**
     * Token Revocation on Logout.
     */
    public function logout(Request $request)
    {
        $request->user()->currentAccessToken()->delete();

        return response()->json([
            'status' => 'success',
            'message' => 'Successfully logged out and token invalidated.',
        ], 200);
    }
}
