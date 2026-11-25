import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:adoptmatch/core/models/pet_model.dart';
import 'package:adoptmatch/core/repositories/pet_repository.dart';
import 'package:adoptmatch/core/services/laravel_pet_service.dart';
import 'package:adoptmatch/features/adoption_match/bloc/pet_match_bloc.dart';

class _MockLaravelPetService extends Mock implements LaravelPetService {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('PetMatchBloc updates live when PetRepository applies admin image update', () async {
    final mockRemote = _MockLaravelPetService();
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
  });
}
