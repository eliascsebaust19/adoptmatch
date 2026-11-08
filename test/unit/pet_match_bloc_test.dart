import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:adoptmatch/features/adoption_match/bloc/pet_match_bloc.dart';
import 'package:adoptmatch/core/models/pet_model.dart';
import 'package:adoptmatch/core/repositories/pet_repository.dart';

class MockPetRepository extends Mock implements PetRepository {}

void main() {
  late MockPetRepository petRepository;
  const mockPets = [
    Pet(
      id: 'p1',
      name: 'Milo',
      species: 'Cat',
      breed: 'Deshi Cat',
      ageDisplay: '2 yrs',
      ageMonths: 24,
      gender: 'Male',
      weightKg: 4.0,
      distanceKm: 2.0,
      matchScore: 96,
      imageUrl: 'https://images.unsplash.com/photo-1514888286974-6c03e2ca1dba',
      shelterName: 'Dhaka Rescue',
      shelterPhone: '+880 17•• ••••11',
      shelterAddress: 'Dhanmondi',
      story: 'Sweet rescue cat.',
      medicalHistory: 'Vaccinated',
      qrHash: 'HASH1',
    ),
    Pet(
      id: 'p2',
      name: 'Bruno',
      species: 'Dog',
      breed: 'Labrador',
      ageDisplay: '3 yrs',
      ageMonths: 36,
      gender: 'Male',
      weightKg: 25.0,
      distanceKm: 5.0,
      matchScore: 90,
      imageUrl: 'https://images.unsplash.com/photo-1552053831-71594a27632d',
      shelterName: 'Care For Paws',
      shelterPhone: '+880 18•• ••••22',
      shelterAddress: 'Gulshan',
      story: 'Loyal companion dog.',
      medicalHistory: 'Vaccinated & Neutered',
      qrHash: 'HASH2',
    ),
  ];

  setUp(() {
    petRepository = MockPetRepository();
    when(() => petRepository.hasCompletedQuiz).thenReturn(false);
    when(() => petRepository.recordSwipe(any(), isLike: any(named: 'isLike'))).thenAnswer((_) async {});
  });

  group('PetMatchBloc Unit Tests', () {
    blocTest<PetMatchBloc, PetMatchState>(
      'emits [PetMatchLoading, PetMatchLoaded] when LoadPetsEvent succeeds',
      build: () {
        when(() => petRepository.fetchAvailablePets(
          category: any(named: 'category'),
          searchQuery: any(named: 'searchQuery'),
          maxDistanceKm: any(named: 'maxDistanceKm'),
          kidSafeOnly: any(named: 'kidSafeOnly'),
          apartmentOnly: any(named: 'apartmentOnly'),
          vaccinatedOnly: any(named: 'vaccinatedOnly'),
        )).thenAnswer((_) async => mockPets);
        return PetMatchBloc(repository: petRepository);
      },
      act: (bloc) => bloc.add(const LoadPetsEvent()),
      expect: () => [
        isA<PetMatchLoading>(),
        isA<PetMatchLoaded>().having((s) => s.pets.length, 'pets.length', 2),
      ],
    );

    blocTest<PetMatchBloc, PetMatchState>(
      'increments swipe index when SwipePetLeft is added',
      build: () => PetMatchBloc(repository: petRepository),
      seed: () => const PetMatchLoaded(pets: mockPets, currentSwipeIndex: 0),
      act: (bloc) => bloc.add(const SwipePetLeft('p1')),
      expect: () => [
        isA<PetMatchLoaded>().having((s) => s.currentSwipeIndex, 'currentSwipeIndex', 1),
      ],
    );

    blocTest<PetMatchBloc, PetMatchState>(
      'records a like without changing saved favorites when SwipePetRight is added',
      build: () {
        when(() => petRepository.recordSwipe('p1', isLike: true)).thenAnswer((_) async {});
        return PetMatchBloc(repository: petRepository);
      },
      seed: () => const PetMatchLoaded(pets: mockPets, currentSwipeIndex: 0),
      act: (bloc) => bloc.add(const SwipePetRight('p1')),
      expect: () => [
        isA<PetMatchLoaded>()
            .having((s) => s.currentSwipeIndex, 'currentSwipeIndex', 1)
            .having((s) => s.lastMatchedPet?.id, 'lastMatchedPet.id', 'p1'),
      ],
      verify: (_) {
        verify(() => petRepository.recordSwipe('p1', isLike: true)).called(1);
        verifyNever(() => petRepository.toggleFavorite(any()));
      },
    );
  });
}

