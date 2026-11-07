import 'dart:convert';
import 'package:dio/dio.dart' as dio;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../network/api_client.dart';
import 'supabase_service.dart';

class StorageService {
  static final ImagePicker _picker = ImagePicker();

  /// Vercel Blob Read/Write Token
  static const String vercelBlobToken = String.fromEnvironment(
    'BLOB_READ_WRITE_TOKEN',
    defaultValue: 'vercel_blob_rw_3kHT7mDTcvdaG9fF_Q2HYrNy68uqXIFyT9NpMdXM22v6cvQ',
  );

  static const String vercelBlobStoreId = '3kHT7mDTcvdaG9fF';

  /// Curated Google-authenticated profile avatar presets
  static const List<String> googleAvatarPresets = [
    'https://3kht7mdtcvdag9ff.private.blob.vercel-storage.com/pets/pet_1.jpg',
    'https://3kht7mdtcvdag9ff.private.blob.vercel-storage.com/pets/pet_2.jpg',
    'https://3kht7mdtcvdag9ff.private.blob.vercel-storage.com/pets/pet_3.jpg',
    'https://3kht7mdtcvdag9ff.private.blob.vercel-storage.com/pets/pet_4.jpg',
    'https://3kht7mdtcvdag9ff.private.blob.vercel-storage.com/pets/pet_5.jpg',
  ];

  /// Pick an image from device gallery
  static Future<XFile?> pickImageFromGallery() async {
    try {
      final file = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      return file;
    } catch (e) {
      debugPrint('[StorageService] pickImageFromGallery error: $e');
      return null;
    }
  }

  /// Take a new photo using device camera
  static Future<XFile?> pickImageFromCamera() async {
    try {
      final file = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      return file;
    } catch (e) {
      debugPrint('[StorageService] pickImageFromCamera error: $e');
      return null;
    }
  }

  /// Uploads image bytes directly to Vercel Blob Store (Global High-Speed Edge Storage)
  static Future<String?> uploadToVercelBlob({
    required Uint8List bytes,
    required String fileName,
    String contentType = 'image/jpeg',
  }) async {
    try {
      final sanitized = fileName.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
      final pathname = 'uploads/${DateTime.now().millisecondsSinceEpoch}_$sanitized';
      final uri = Uri.parse('https://vercel.com/api/blob/?pathname=${Uri.encodeComponent(pathname)}');

      final response = await http.put(
        uri,
        headers: {
          'x-api-version': '13',
          'x-vercel-blob-store-id': vercelBlobStoreId,
          'authorization': 'Bearer $vercelBlobToken',
          'x-vercel-blob-access': 'private',
          'x-allow-overwrite': '1',
          'content-type': contentType,
        },
        body: bytes,
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final blobUrl = data['url'] as String?;
        if (blobUrl != null && blobUrl.isNotEmpty) {
          debugPrint('[StorageService] Uploaded successfully to Vercel Blob: $blobUrl');
          return blobUrl;
        }
      } else {
        debugPrint('[StorageService] Vercel Blob upload HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      debugPrint('[StorageService] Vercel Blob upload notice: $e');
    }
    return null;
  }

  /// Uploads user profile photo:
  /// 1. Vercel Blob (Fast Edge Storage)
  /// 2. Supabase Storage (Bucket: 'avatars')
  /// 3. Laravel 11 Backend / Cloudinary CDN
  /// 4. Resilient Base64 Fallback
  static Future<String> uploadProfileImage({
    required Uint8List bytes,
    required String fileName,
    String? userId,
  }) async {
    final sanitizedFileName = fileName.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    final uniquePath = 'profiles/${userId ?? "usr"}_${DateTime.now().millisecondsSinceEpoch}_$sanitizedFileName';

    // 1. Primary: Upload to high-speed Vercel Blob Storage
    final vercelUrl = await uploadToVercelBlob(
      bytes: bytes,
      fileName: uniquePath,
      contentType: 'image/jpeg',
    );
    if (vercelUrl != null && vercelUrl.isNotEmpty) {
      return vercelUrl;
    }

    // 2. Secondary: Upload via Supabase Storage if initialized
    if (SupabaseService.isInitialized) {
      try {
        final storage = SupabaseService.client.storage.from('avatars');
        await storage.uploadBinary(
          uniquePath,
          bytes,
          fileOptions: const FileOptions(
            contentType: 'image/jpeg',
            upsert: true,
          ),
        );

        final publicUrl = storage.getPublicUrl(uniquePath);
        if (publicUrl.isNotEmpty) {
          debugPrint('[StorageService] Uploaded successfully to Supabase Storage: $publicUrl');
          return publicUrl;
        }
      } catch (e) {
        debugPrint('[StorageService] Supabase upload notice: $e');
      }
    }

    // 3. Tertiary: Upload to Laravel 11 Backend & Cloudinary CDN
    try {
      final backendUrl = await uploadToCloudinaryOrBackend(
        bytes: bytes,
        fileName: sanitizedFileName,
      );
      if (backendUrl != null && backendUrl.isNotEmpty) {
        return backendUrl;
      }
    } catch (_) {}

    // 4. Resilient Base64 Data URI Fallback
    final base64String = base64Encode(bytes);
    return 'data:image/jpeg;base64,$base64String';
  }

  /// Uploads pet photo directly to Vercel Blob Store (Global High-Speed Edge Storage)
  static Future<String> uploadPetImage({
    required Uint8List bytes,
    required String fileName,
    String? petId,
  }) async {
    final sanitizedFileName = fileName.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    final uniquePath = 'pets/${petId ?? "pet"}_${DateTime.now().millisecondsSinceEpoch}_$sanitizedFileName';

    // 1. Primary: Upload directly to high-speed Vercel Blob Edge CDN
    final vercelUrl = await uploadToVercelBlob(
      bytes: bytes,
      fileName: uniquePath,
      contentType: 'image/jpeg',
    );
    if (vercelUrl != null && vercelUrl.isNotEmpty) {
      return vercelUrl;
    }

    // 2. Secondary: Cloudinary / Backend upload
    try {
      final backendUrl = await uploadToCloudinaryOrBackend(
        bytes: bytes,
        fileName: sanitizedFileName,
      );
      if (backendUrl != null && backendUrl.isNotEmpty) {
        return backendUrl;
      }
    } catch (_) {}

    // 3. Fallback: Base64 Data URI
    final base64String = base64Encode(bytes);
    return 'data:image/jpeg;base64,$base64String';
  }

  /// Upload image bytes directly to Laravel Backend & Cloudinary Multi-Image CDN
  static Future<String?> uploadToCloudinaryOrBackend({
    required Uint8List bytes,
    required String fileName,
  }) async {
    try {
      final client = ApiClient();
      final formData = dio.FormData.fromMap({
        'image': dio.MultipartFile.fromBytes(bytes, filename: fileName),
      });

      final response = await client.dio.post('/upload/image', data: formData);
      if (response.statusCode == 200 && response.data['url'] != null) {
        return response.data['url'] as String;
      }
    } catch (e) {
      debugPrint('[StorageService] Cloudinary/Backend upload error: $e');
    }
    return null;
  }

  /// Retrieves the direct Google Profile Photo from Supabase OAuth session metadata
  static String? getDirectGooglePhotoUrl() {
    if (!SupabaseService.isInitialized) return null;
    final currentUser = SupabaseService.auth.currentUser;
    if (currentUser == null) return null;

    final metadata = currentUser.userMetadata;
    if (metadata == null) return null;

    final photo = metadata['picture'] ?? metadata['avatar_url'];
    if (photo is String && photo.isNotEmpty) {
      return photo;
    }
    return null;
  }
}
