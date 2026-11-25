import 'dart:convert';
import 'package:dio/dio.dart' as dio;
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../network/api_client.dart';
import 'supabase_service.dart';

class StorageService {
  static final ImagePicker _picker = ImagePicker();

  /// Vercel Blob Read/Write Token (Injected securely via --dart-define or empty by default)
  static const String vercelBlobToken = String.fromEnvironment(
    'BLOB_READ_WRITE_TOKEN',
    defaultValue: '',
  );

  @visibleForTesting
  static ApiClient Function()? apiClientFactoryForTesting;

  /// Curated Google-authenticated profile avatar presets
  static const List<String> googleAvatarPresets = [
    'https://3kht7mdtcvdag9ff.private.blob.vercel-storage.com/pets/pet_1.jpg',
    'https://3kht7mdtcvdag9ff.private.blob.vercel-storage.com/pets/pet_2.jpg',
    'https://3kht7mdtcvdag9ff.private.blob.vercel-storage.com/pets/pet_3.jpg',
    'https://3kht7mdtcvdag9ff.private.blob.vercel-storage.com/pets/pet_4.jpg',
    'https://3kht7mdtcvdag9ff.private.blob.vercel-storage.com/pets/pet_5.jpg',
  ];

  static const int maxPetImageBytes = 5 * 1024 * 1024; // 5 MB (matches pet-images bucket limit)
  static const Set<String> allowedImageExtensions = {'jpg', 'jpeg', 'png', 'webp'};

  /// Validates image size & format (JPG, JPEG, PNG, WebP) and returns the MIME type.
  static String validateAndDetectPetImage({
    required Uint8List bytes,
    required String fileName,
  }) {
    if (bytes.isEmpty) {
      throw const FormatException('Selected image file is empty.');
    }
    if (bytes.length > maxPetImageBytes) {
      final mb = (bytes.length / (1024 * 1024)).toStringAsFixed(1);
      throw FormatException('Image is too large ($mb MB). Maximum allowed size is 5 MB.');
    }

    // Check magic bytes first for reliable format detection on web/mobile pickers.
    if (bytes.length >= 3 && bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF) {
      return 'image/jpeg';
    }
    if (bytes.length >= 4 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47) {
      return 'image/png';
    }
    if (bytes.length >= 12 &&
        bytes[0] == 0x52 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46 &&
        bytes[3] == 0x46 &&
        bytes[8] == 0x57 &&
        bytes[9] == 0x45 &&
        bytes[10] == 0x42 &&
        bytes[11] == 0x50) {
      return 'image/webp';
    }

    final ext = fileName.contains('.') ? fileName.split('.').last.toLowerCase().trim() : '';
    if (ext == 'png') return 'image/png';
    if (ext == 'webp') return 'image/webp';
    if (ext == 'jpg' || ext == 'jpeg') return 'image/jpeg';

    throw const FormatException('Unsupported image format. Please choose a JPG, JPEG, PNG, or WebP file.');
  }

  /// Pick an image from device gallery
  static Future<XFile?> pickImageFromGallery() async {
    try {
      final file = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1280,
        maxHeight: 1280,
        imageQuality: 85,
      );
      return file;
    } catch (e) {
      debugPrint('[StorageService] pickImageFromGallery error: $e');
      return null;
    }
  }

  /// Pick multiple images from device gallery for pet galleries
  static Future<List<XFile>> pickMultipleImagesFromGallery() async {
    try {
      final files = await _picker.pickMultiImage(
        maxWidth: 1280,
        maxHeight: 1280,
        imageQuality: 85,
      );
      return files;
    } catch (e) {
      debugPrint('[StorageService] pickMultipleImagesFromGallery error: $e');
      return const [];
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

  /// Uploads a user profile photo through Supabase or the authenticated backend.
  ///
  /// Objects must live under `{auth.uid()}/...`: the `avatars` bucket policy in
  /// 20261109091200_storage_buckets.sql rejects any other prefix, so a path
  /// like `profiles/...` always failed and every upload quietly fell through to
  /// the REST backend.
  ///
  /// Throws when no provider accepts the bytes; never returns a fabricated URL.
  static Future<String> uploadProfileImage({
    required Uint8List bytes,
    required String fileName,
    String? userId,
  }) async {
    final sanitizedFileName =
        fileName.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');

    final owner = SupabaseService.isInitialized
        ? (SupabaseService.auth.currentUser?.id ?? userId)
        : userId;

    if (SupabaseService.isInitialized && owner != null && owner.isNotEmpty) {
      try {
        final storage = SupabaseService.client.storage.from('avatars');
        final uniquePath =
            '$owner/avatar_${DateTime.now().millisecondsSinceEpoch}_$sanitizedFileName';
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
          debugPrint(
              '[StorageService] Uploaded to Supabase Storage: $publicUrl');
          return publicUrl;
        }
      } on StorageException catch (e) {
        debugPrint('[StorageService] Supabase upload rejected: ${e.message}');
      } catch (e) {
        debugPrint('[StorageService] Supabase upload notice: $e');
      }
    }

    // Fallback: the REST backend, when its upload endpoint is configured.
    try {
      final backendUrl = await uploadToCloudinaryOrBackend(
        bytes: bytes,
        fileName: sanitizedFileName,
      );
      if (backendUrl != null && backendUrl.isNotEmpty) {
        return backendUrl;
      }
    } catch (_) {}

    throw Exception('Photo upload failed: no storage provider accepted the file.');
  }

  /// Uploads a pet photo through Supabase Storage or the authenticated backend.
  /// Validates JPG/JPEG/PNG/WebP format and 5 MB max file size before upload.
  static Future<String> uploadPetImage({
    required Uint8List bytes,
    required String fileName,
    String? petId,
    bool allowLocalFallback = true,
  }) async {
    final mimeType = validateAndDetectPetImage(bytes: bytes, fileName: fileName);
    final sanitizedFileName = fileName.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    String? lastError;

    // 1. Primary: Upload to Supabase Storage 'pet-images' public bucket
    if (SupabaseService.isInitialized) {
      try {
        final storage = SupabaseService.client.storage.from('pet-images');
        final owner = SupabaseService.auth.currentUser?.id ?? 'admin';
        final petFolder = (petId != null && petId.isNotEmpty) ? '${petId}_' : '';
        final uniquePath =
            '$owner/pet_$petFolder${DateTime.now().millisecondsSinceEpoch}_$sanitizedFileName';
        await storage.uploadBinary(
          uniquePath,
          bytes,
          fileOptions: FileOptions(
            contentType: mimeType,
            upsert: true,
          ),
        );
        final publicUrl = storage.getPublicUrl(uniquePath);
        if (publicUrl.isNotEmpty) {
          debugPrint('[StorageService] Uploaded pet image to Supabase: $publicUrl');
          return publicUrl;
        }
      } catch (e) {
        lastError = e.toString();
        debugPrint('[StorageService] Supabase pet-images upload error: $e');
      }
    }

    // 2. Secondary: authenticated backend upload
    try {
      final backendUrl = await uploadToCloudinaryOrBackend(
        bytes: bytes,
        fileName: sanitizedFileName,
      );
      if (backendUrl != null && backendUrl.isNotEmpty) {
        return backendUrl;
      }
    } catch (e) {
      lastError ??= e.toString();
    }

    if (!allowLocalFallback) {
      throw Exception(
        'Cloud image upload failed${lastError != null ? ": $lastError" : ". Ensure you are signed in with staff upload permissions."}',
      );
    }

    // 3. Fallback: Base64 data URL ensures local preview during offline/demo sessions
    return 'data:$mimeType;base64,${base64Encode(bytes)}';
  }

  /// Deletes an obsolete pet image stored in Supabase `pet-images` bucket.
  static Future<void> deletePetImageByUrl(String publicUrl) async {
    if (!SupabaseService.isInitialized || publicUrl.isEmpty) return;
    const marker = '/storage/v1/object/public/pet-images/';
    final idx = publicUrl.indexOf(marker);
    if (idx == -1) return;
    final objectPath = Uri.decodeComponent(publicUrl.substring(idx + marker.length).split('?').first);
    if (objectPath.isEmpty) return;
    try {
      await SupabaseService.client.storage.from('pet-images').remove([objectPath]);
      debugPrint('[StorageService] Deleted obsolete cloud image: $objectPath');
    } catch (e) {
      debugPrint('[StorageService] Could not remove obsolete image ($objectPath): $e');
    }
  }

  /// Upload image bytes directly to Laravel Backend & Cloudinary Multi-Image CDN
  static Future<String?> uploadToCloudinaryOrBackend({
    required Uint8List bytes,
    required String fileName,
  }) async {
    try {
      final client = (apiClientFactoryForTesting ?? () => ApiClient())();
      final formData = dio.FormData.fromMap({
        'image': dio.MultipartFile.fromBytes(bytes, filename: fileName),
      });

      final response = await client.dio.post('/upload/image', data: formData);
      if ((response.statusCode == 200 || response.statusCode == 201) &&
          response.data['status'] == 'success' && response.data['url'] != null) {
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
