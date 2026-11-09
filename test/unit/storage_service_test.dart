import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:adoptmatch/core/services/storage_service.dart';
import 'package:adoptmatch/core/network/api_client.dart';
import '../helpers/fake_dio_adapter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('StorageService Tests', () {
    test('googleAvatarPresets contains high-quality profile avatars', () {
      expect(StorageService.googleAvatarPresets.isNotEmpty, true);
      for (final url in StorageService.googleAvatarPresets) {
        expect(url.startsWith('https://'), true);
      }
    });

    test('upload fails closed when no provider confirms the write', () async {
      final api = ApiClient(baseUrl: 'https://api.example.test/api/v1')
        ..dio.httpClientAdapter = FakeDioAdapter((_) async => (503, {'status': 'error'}));
      StorageService.apiClientFactoryForTesting = () => api;
      addTearDown(() => StorageService.apiClientFactoryForTesting = null);
      await expectLater(StorageService.uploadProfileImage(
        bytes: Uint8List.fromList([1, 2, 3]), fileName: 'avatar.png', userId: 'u-test'),
        throwsException);
    });

    test('upload returns only a server-confirmed URL', () async {
      final api = ApiClient(baseUrl: 'https://api.example.test/api/v1')
        ..dio.httpClientAdapter = FakeDioAdapter((_) async => (201, {
          'status': 'success', 'url': 'https://cdn.example.test/confirmed.png'}));
      StorageService.apiClientFactoryForTesting = () => api;
      addTearDown(() => StorageService.apiClientFactoryForTesting = null);
      final url = await StorageService.uploadPetImage(
        bytes: Uint8List.fromList([1, 2, 3]), fileName: 'pet.png');
      expect(url, 'https://cdn.example.test/confirmed.png');
    });

    test('profile upload still fails closed without a Supabase session', () async {
      // The avatars bucket only accepts objects under `{auth.uid()}/...`.
      // With no session the upload must fall through to the REST backend and
      // then fail, rather than returning a URL nothing was written to.
      final api = ApiClient(baseUrl: 'https://api.example.test/api/v1')
        ..dio.httpClientAdapter =
            FakeDioAdapter((_) async => (500, {'status': 'error'}));
      StorageService.apiClientFactoryForTesting = () => api;
      addTearDown(() => StorageService.apiClientFactoryForTesting = null);

      await expectLater(
        StorageService.uploadProfileImage(
          bytes: Uint8List.fromList([1, 2, 3]),
          fileName: 'avatar.png',
          userId: 'u-test',
        ),
        throwsException,
      );
    });

    test('getDirectGooglePhotoUrl safely handles uninitialized or unauthenticated state', () {
      final googlePhoto = StorageService.getDirectGooglePhotoUrl();
      // Should safely return null without throwing exceptions
      expect(googlePhoto == null || googlePhoto.startsWith('https://'), true);
    });
  });
}

