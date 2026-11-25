import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:adoptmatch/core/models/pet_model.dart';
import 'package:adoptmatch/core/repositories/pet_repository.dart';
import 'package:adoptmatch/core/services/api_pet_service.dart';
import 'package:adoptmatch/core/services/storage_service.dart';
import 'package:adoptmatch/features/adoption_match/bloc/pet_match_bloc.dart';

class _MockApiPetService extends Mock implements ApiPetService {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('PetMatchBloc updates live when PetRepository applies admin image update', () async {
    final mockRemote = _MockApiPetService();
    const initialPet = Pet(
      id: 'pet-live-1',
      name: 'Leo',
      species: 'Cat',
      breed: 'Bengal',
      ageDisplay: '1 yr',
      ageMonths: 12,
      gender: 'Male',
      weightKg: 4.5,
      distanceKm: 2.0,
      matchScore: 95,
      imageUrl: 'https://example.com/old_photo.jpg',
      galleryUrls: ['https://example.com/old_photo.jpg'],
      shelterName: 'Dhaka Paws',
      shelterPhone: '+8801700000000',
      shelterAddress: 'Dhaka',
      story: 'Friendly Bengal cat',
    );

    when(() => mockRemote.getPets(species: any(named: 'species'), search: any(named: 'search')))
        .thenAnswer((_) async => [initialPet]);

    final repo = PetRepository();
    repo.setRemoteServiceForTesting(mockRemote);

    final bloc = PetMatchBloc(repository: repo);
    addTearDown(bloc.close);

    bloc.add(const LoadPetsEvent());
    await expectLater(
      bloc.stream,
      emitsThrough(
        isA<PetMatchLoaded>().having(
          (s) => s.pets.firstWhere((p) => p.id == 'pet-live-1').imageUrl,
          'initial imageUrl',
          'https://example.com/old_photo.jpg',
        ),
      ),
    );

    const updatedUrl = 'https://example.com/new_cat_photo.jpg';
    final updatedPet = initialPet.copyWith(
      imageUrl: updatedUrl,
      galleryUrls: [updatedUrl],
    );

    await repo.applyAdminPetUpdate(updatedPet, syncedToServer: false);

    await expectLater(
      bloc.stream,
      emitsThrough(
        isA<PetMatchLoaded>().having(
          (s) => s.pets.firstWhere((p) => p.id == 'pet-live-1').imageUrl,
          'live updated imageUrl',
          updatedUrl,
        ),
      ),
    );

    // Even if remote still returns the stale row, session override keeps the new photo.
    final refetched = await repo.fetchAvailablePets();
    expect(
      refetched.firstWhere((p) => p.id == 'pet-live-1').imageUrl,
      updatedUrl,
    );

    // Archiving removes pet from user listings live; restoring brings it back.
    await repo.applyAdminPetUpdate(
      updatedPet.copyWith(adoptionStatus: 'archived'),
      syncedToServer: false,
    );
    await expectLater(
      bloc.stream,
      emitsThrough(
        isA<PetMatchLoaded>().having(
          (s) => s.pets.any((p) => p.id == 'pet-live-1'),
          'archived pet hidden from user list',
          isFalse,
        ),
      ),
    );

    await repo.applyAdminPetUpdate(
      updatedPet.copyWith(adoptionStatus: 'available'),
      syncedToServer: false,
    );
    await expectLater(
      bloc.stream,
      emitsThrough(
        isA<PetMatchLoaded>().having(
          (s) => s.pets.any((p) => p.id == 'pet-live-1'),
          'restored pet visible again',
          isTrue,
        ),
      ),
    );
  });

  test('StorageService validates JPG/PNG/WebP formats and 5 MB max size', () {
    final jpegBytes = Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0, 0x00]);
    expect(
      StorageService.validateAndDetectPetImage(bytes: jpegBytes, fileName: 'cat.jpg'),
      'image/jpeg',
    );

    final pngBytes = Uint8List.fromList([0x89, 0x50, 0x4E, 0x47, 0x0D]);
    expect(
      StorageService.validateAndDetectPetImage(bytes: pngBytes, fileName: 'dog.png'),
      'image/png',
    );

    final webpBytes = Uint8List.fromList([
      0x52, 0x49, 0x46, 0x46, 0, 0, 0, 0, 0x57, 0x45, 0x42, 0x50,
    ]);
    expect(
      StorageService.validateAndDetectPetImage(bytes: webpBytes, fileName: 'bird.webp'),
      'image/webp',
    );

    expect(
      () => StorageService.validateAndDetectPetImage(
        bytes: Uint8List.fromList([1, 2, 3, 4]),
        fileName: 'document.pdf',
      ),
      throwsA(isA<FormatException>()),
    );

    final oversized = Uint8List(StorageService.maxPetImageBytes + 1);
    expect(
      () => StorageService.validateAndDetectPetImage(
        bytes: oversized,
        fileName: 'huge.jpg',
      ),
      throwsA(isA<FormatException>()),
    );
  });
}
