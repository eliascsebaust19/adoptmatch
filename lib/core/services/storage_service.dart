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

  /// Uploads a user profile photo through Supabase or the authenticated backend.
  /// Throws when no provider accepts the bytes; never returns a fabricated URL.
  static Future<String> uploadProfileImage({
    required Uint8List bytes,
    required String fileName,
    String? userId,
  }) async {
    final sanitizedFileName = fileName.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    final uniquePath = 'profiles/${userId ?? "usr"}_${DateTime.now().millisecondsSinceEpoch}_$sanitizedFileName';

    // 1. Primary: Upload via Supabase Storage if initialized
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

    throw Exception('Photo upload failed: no storage provider accepted the file.');
  }

  /// Uploads a pet photo through the authenticated backend.
  static Future<String> uploadPetImage({
    required Uint8List bytes,
    required String fileName,
    String? petId,
  }) async {
    final sanitizedFileName = fileName.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');

    // 1. Primary: authenticated backend upload
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
