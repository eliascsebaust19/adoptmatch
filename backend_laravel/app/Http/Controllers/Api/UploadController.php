<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Str;

class UploadController extends Controller
{
    /** Authenticated image upload. Never accept a caller-supplied URL as proof of storage. */
    public function uploadImage(Request $request)
    {
        $request->validate([
            'image' => 'required|file|mimes:jpg,jpeg,png,webp,gif|max:5120',
            'folder' => 'nullable|in:avatars,pets',
        ]);

        $file = $request->file('image');
        $bytes = file_get_contents($file->getRealPath());
        $mime = $file->getMimeType();
        $allowed = ['image/jpeg', 'image/png', 'image/webp', 'image/gif'];
        if ($bytes === false || strlen($bytes) === 0 || strlen($bytes) > 5242880 ||
            !in_array($mime, $allowed, true) || @getimagesizefromstring($bytes) === false) {
            return response()->json(['status' => 'error', 'message' => 'A genuine image of at most 5 MB is required.'], 415);
        }

        $extensions = ['image/jpeg' => 'jpg', 'image/png' => 'png', 'image/webp' => 'webp', 'image/gif' => 'gif'];
        $folder = $request->input('folder', 'pets');
        $filename = $request->user()->id . '-' . Str::uuid() . '.' . $extensions[$mime];
        $path = 'uploads/' . $folder . '/' . $filename;
        $cloud = config('services.cloudinary');

        if (!empty($cloud['cloud_name']) && !empty($cloud['api_key']) && !empty($cloud['api_secret'])) {
            $timestamp = time();
            $folderName = 'adoptmatch/' . $folder;
            $publicId = $request->user()->id . '-' . Str::uuid();
            // Signed uploads do not depend on an unrestricted unsigned preset.
            $signature = sha1('folder=' . $folderName . '&public_id=' . $publicId . '&timestamp=' . $timestamp . $cloud['api_secret']);
            try {
                $response = Http::timeout(20)
                    ->attach('file', $bytes, $filename)
                    ->post('https://api.cloudinary.com/v1_1/' . $cloud['cloud_name'] . '/image/upload', [
                        'api_key' => $cloud['api_key'],
                        'timestamp' => $timestamp,
                        'signature' => $signature,
                        'folder' => $folderName,
                        'public_id' => $publicId,
                    ]);
                $result = $response->json();
                if ($response->successful() && !empty($result['secure_url']) &&
                    ($result['bytes'] ?? null) === strlen($bytes)) {
                    return response()->json([
                        'status' => 'success', 'url' => $result['secure_url'],
                        'public_id' => $result['public_id'], 'provider' => 'cloudinary',
                    ], 201);
                }
                Log::warning('Cloudinary did not confirm the image upload.', ['status' => $response->status()]);
            } catch (\Exception $e) {
                Log::warning('Cloudinary upload failed.', ['error' => $e->getMessage()]);
            }
        }

        // Laravel's public directory is served directly; no missing storage symlink fallback.
        $directory = public_path('uploads/' . $folder);
        if (!is_dir($directory) && !mkdir($directory, 0755, true) && !is_dir($directory)) {
            return response()->json(['status' => 'error', 'message' => 'Image storage is unavailable.'], 503);
        }
        $destination = $directory . '/' . $filename;
        if (file_put_contents($destination, $bytes, LOCK_EX) !== strlen($bytes) ||
            !is_file($destination) || filesize($destination) !== strlen($bytes)) {
            return response()->json(['status' => 'error', 'message' => 'Image storage did not confirm the write.'], 503);
        }

        return response()->json([
            'status' => 'success', 'url' => asset($path), 'public_id' => $filename,
            'provider' => 'local', 'bytes' => strlen($bytes),
        ], 201);
    }
}
