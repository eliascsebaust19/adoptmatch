import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:adoptmatch/core/services/storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('StorageService Tests', () {
    test('googleAvatarPresets contains high-quality profile avatars', () {
      expect(StorageService.googleAvatarPresets.isNotEmpty, true);
      for (final url in StorageService.googleAvatarPresets) {
        expect(url.startsWith('https://'), true);
      }
    });

    test('uploadProfileImage returns resilient data URI when Supabase uninitialized in test', () async {
      final dummyBytes = Uint8List.fromList([1, 2, 3, 4, 5]);
      final result = await StorageService.uploadProfileImage(
        bytes: dummyBytes,
        fileName: 'my_avatar.png',
        userId: 'u-test-99',
      );

      expect(result.isNotEmpty, true);
      // In offline / unit test mode, resilient base64 URI is produced without crashing
      expect(result.startsWith('data:image') || result.startsWith('https://'), true);
    });

    test('getDirectGooglePhotoUrl safely handles uninitialized or unauthenticated state', () {
      final googlePhoto = StorageService.getDirectGooglePhotoUrl();
      // Should safely return null without throwing exceptions
      expect(googlePhoto == null || googlePhoto.startsWith('https://'), true);
    });
  });
}

