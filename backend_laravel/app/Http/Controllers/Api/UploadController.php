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
     * Upload an image to Vercel Blob, Cloudinary Multi-Image CDN, or Local Storage.
     */
    public function uploadImage(Request $request)
    {
        $request->validate([
            'image' => 'required', // Can be file upload, base64 data URI, or external URL
            'folder' => 'nullable|string',
        ]);

        $folder = $request->folder ?? 'adoptmatch/pets';

        // 1. Primary: Vercel Blob High-Speed Global CDN upload
        $vercelToken = env('BLOB_READ_WRITE_TOKEN', 'vercel_blob_rw_3kHT7mDTcvdaG9fF_Q2HYrNy68uqXIFyT9NpMdXM22v6cvQ');
        $storeId = env('VERCEL_BLOB_STORE_ID', '3kHT7mDTcvdaG9fF');

        if (!empty($vercelToken)) {
            try {
                $filename = 'uploads/' . time() . '_' . Str::random(10) . '.jpg';
                $contentType = 'image/jpeg';
                $binaryContent = null;

                if ($request->hasFile('image')) {
                    $file = $request->file('image');
                    $binaryContent = file_get_contents($file->getRealPath());
                    $contentType = $file->getMimeType() ?: 'image/jpeg';
                } else {
                    $imageData = $request->input('image');
                    if (str_starts_with($imageData, 'data:image')) {
                        $parts = explode(',', $imageData);
                        $binaryContent = base64_decode($parts[1] ?? $parts[0]);
                    } elseif (filter_var($imageData, FILTER_VALIDATE_URL)) {
                        $binaryContent = Http::get($imageData)->body();
                    } else {
                        $binaryContent = base64_decode($imageData);
                    }
                }

                if ($binaryContent) {
                    $pathname = urlencode($filename);
                    $response = Http::withHeaders([
                        'x-api-version' => '13',
                        'x-vercel-blob-store-id' => $storeId,
                        'authorization' => 'Bearer ' . $vercelToken,
                        'x-vercel-blob-access' => 'private',
                        'x-allow-overwrite' => '1',
                        'content-type' => $contentType,
                    ])->withBody($binaryContent, $contentType)
                      ->put("https://vercel.com/api/blob/?pathname={$pathname}");

                    if ($response->successful()) {
                        $result = $response->json();
                        return response()->json([
                            'status' => 'success',
                            'message' => 'Image uploaded to Vercel Blob successfully',
                            'url' => $result['url'],
                            'public_id' => $result['pathname'] ?? $filename,
                        ], 200);
                    } else {
                        Log::warning("[Vercel Blob Upload Warning] HTTP {$response->status()}: " . $response->body());
                    }
                }
            } catch (\Exception $e) {
                Log::error("[Vercel Blob Upload Exception] " . $e->getMessage());
            }
        }

        // 2. Secondary: Cloudinary upload if configured
        $cloudinaryUrl = env('CLOUDINARY_URL');
        $cloudName = config('services.cloudinary.cloud_name');
        $apiKey = config('services.cloudinary.api_key');
        $uploadPreset = config('services.cloudinary.upload_preset', 'ml_default');

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

        // 3. Fallback to Local Public Storage or Direct URL
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
