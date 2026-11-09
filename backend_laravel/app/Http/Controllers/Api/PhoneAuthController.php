<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\User;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Str;

/** Phone OTP is delegated to the configured Supabase SMS provider. */
class PhoneAuthController extends Controller
{
    private function provider(): array
    {
        $url = rtrim((string) config('services.supabase.url'), '/');
        $key = (string) config('services.supabase.anon_key');
        if ($url === '' || $key === '') {
            throw new \Illuminate\Http\Exceptions\HttpResponseException(response()->json([
                'status' => 'error', 'message' => 'Phone OTP is not configured on this server.'], 503));
        }
        return [$url, $key];
    }

    public function requestOtp(Request $request)
    {
        $request->validate(['phone' => ['required', 'regex:/^\+[1-9]\d{7,14}$/']]);
        [$url, $key] = $this->provider();
        $response = Http::timeout(12)->withHeaders(['apikey' => $key,
            'Authorization' => 'Bearer '.$key])->acceptJson()
            ->post($url.'/auth/v1/otp', ['phone' => $request->phone]);
        if (!$response->successful()) {
            return response()->json(['status' => 'error',
                'message' => 'The SMS provider rejected the OTP request.'], 502);
        }
        return response()->json(['status' => 'success', 'message' => 'OTP sent.']);
    }

    public function verifyOtp(Request $request)
    {
        $request->validate([
            'phone' => ['required', 'regex:/^\+[1-9]\d{7,14}$/'],
            'token' => 'required|string|size:6',
        ]);
        [$url, $key] = $this->provider();
        $response = Http::timeout(12)->withHeaders(['apikey' => $key,
            'Authorization' => 'Bearer '.$key])->acceptJson()
            ->post($url.'/auth/v1/verify', [
                'type' => 'sms', 'phone' => $request->phone, 'token' => $request->token,
            ]);
        $data = $response->json();
        if (!$response->successful() || empty($data['user']['id']) || empty($data['access_token'])) {
            return response()->json(['status' => 'error', 'message' => 'Invalid or expired OTP.'], 401);
        }
        $verifiedPhone = preg_replace('/\D/', '', (string) ($data['user']['phone'] ?? ''));
        $requestedPhone = preg_replace('/\D/', '', $request->phone);
        if ($verifiedPhone === '' || !hash_equals($requestedPhone, $verifiedPhone)) {
            return response()->json(['status' => 'error', 'message' => 'OTP phone mismatch.'], 401);
        }
        $providerId = (string) $data['user']['id'];
        $user = User::where('supabase_id', $providerId)->first();
        if (!$user) {
            // Phone-only Supabase accounts need a unique, non-deliverable local identifier.
            $email = 'phone-'.hash('sha256', $providerId).'@users.noreply.adoptmatch.invalid';
            if (User::where('email', $email)->exists()) {
                return response()->json(['status' => 'error',
                    'message' => 'Account linking requires support.'], 409);
            }
            $user = User::create([
                'name' => $data['user']['user_metadata']['full_name'] ?? 'AdoptMatch User',
                'email' => $email, 'phone' => $request->phone, 'supabase_id' => $providerId,
                'role' => 'adopter', 'password' => Hash::make(Str::random(40)),
                'phone_verified_at' => now(),
            ]);
        } else {
            $user->update(['phone' => $request->phone, 'phone_verified_at' => now()]);
        }
        $token = $user->createToken($request->input('device_name', 'phone_otp'))->plainTextToken;
        return response()->json(['status' => 'success', 'access_token' => $token,
            'token_type' => 'Bearer', 'user' => $user], 200);
    }
}
