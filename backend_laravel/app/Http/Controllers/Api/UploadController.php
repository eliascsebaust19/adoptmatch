<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Str;

class UploadController extends Controller
{
    /**
     * Upload an image to Cloudinary Multi-Image CDN or Local Storage.
     */
    public function uploadImage(Request $request)
    {
        $request->validate([
            'image' => 'required', // Can be file upload, base64 data URI, or external URL
            'folder' => 'nullable|string',
        ]);

        $folder = $request->folder ?? 'adoptmatch/pets';

        // 1. Cloudinary upload if CLOUDINARY_URL or cloud_name is configured
        $cloudinaryUrl = env('CLOUDINARY_URL');
        $cloudName = config('services.cloudinary.cloud_name');
        $apiKey = config('services.cloudinary.api_key');
        $uploadPreset = config('services.cloudinary.upload_preset', 'ml_default');

        // Extract cloud name and api key from cloudinary:// url if provided
        if (!empty($cloudinaryUrl) && preg_match('/cloudinary:\/\/([^:]+):([^@]+)@(.+)/', $cloudinaryUrl, $matches)) {
            $apiKey = $matches[1];
            $cloudName = $matches[3];
        }

        if (!empty($cloudName)) {
            try {
                $endpoint = "https://api.cloudinary.com/v1_1/{$cloudName}/image/upload";

                if ($request->hasFile('image')) {
                    $file = $request->file('image');
                    $response = Http::attach('file', file_get_contents($file), $file->getClientOriginalName())
                        ->post($endpoint, [
                            'upload_preset' => $uploadPreset,
                            'folder' => $folder,
                        ]);
                } else {
                    $imageData = $request->input('image');
                    $response = Http::post($endpoint, [
                        'file' => $imageData,
                        'upload_preset' => $uploadPreset,
                        'folder' => $folder,
                    ]);
                }

                if ($response->successful()) {
                    $result = $response->json();
                    return response()->json([
                        'status' => 'success',
                        'message' => 'Image uploaded to Cloudinary successfully',
                        'url' => $result['secure_url'],
                        'public_id' => $result['public_id'] ?? null,
                    ], 200);
                } else {
                    Log::warning("[Cloudinary Error] " . $response->body());
                }
            } catch (\Exception $e) {
                Log::error("[Cloudinary Exception] " . $e->getMessage());
            }
        }

        // 2. Fallback to Local Public Storage or Direct URL
        if ($request->hasFile('image')) {
            $file = $request->file('image');
            $filename = Str::uuid() . '.' . $file->getClientOriginalExtension();
            $path = $file->storeAs('public/uploads', $filename);
            $url = url('storage/uploads/' . $filename);

            return response()->json([
                'status' => 'success',
                'message' => 'Image stored on server storage',
                'url' => $url,
                'public_id' => $filename,
            ], 200);
        }

        $inputStr = $request->input('image');
        return response()->json([
            'status' => 'success',
            'message' => 'Image URL accepted',
            'url' => $inputStr,
            'public_id' => 'url_' . md5($inputStr),
        ], 200);
    }
}
