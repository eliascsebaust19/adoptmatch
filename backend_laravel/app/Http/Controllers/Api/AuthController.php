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
        $request->validate([
            'id_token' => 'required|string',
            'device_name' => 'nullable|string',
        ]);

        try {
            $clientId = config('services.google.client_id');
            $client = new GoogleClient(['client_id' => $clientId]);
            $payload = $client->verifyIdToken($request->id_token);

            if (!$payload) {
                return response()->json([
                    'status' => 'error',
                    'message' => 'Invalid or expired Google Token.',
                ], 401);
            }

            $googleId = $payload['sub'];
            $email = $payload['email'];
            $name = $payload['name'] ?? 'AdoptMatch User';
            $avatar = $payload['picture'] ?? null;

            $user = User::where('google_id', $googleId)
                ->orWhere('email', $email)
                ->first();

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
            'role' => 'nullable|in:adopter,pet_owner,shelter',
        ]);

        $user = User::create([
            'name' => $request->name,
            'email' => $request->email,
            'password' => Hash::make($request->password),
            'phone' => $request->phone,
            'role' => $request->role ?? 'adopter',
            'avatar' => 'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?auto=format&fit=crop&w=400&q=80',
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

