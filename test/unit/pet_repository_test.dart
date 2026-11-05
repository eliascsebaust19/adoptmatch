import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:adoptmatch/core/repositories/pet_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late PetRepository repository;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    repository = PetRepository();
  });

  group('PetRepository Tests', () {
    test('fetches available pets sorted by match score', () async {
      final pets = await repository.fetchAvailablePets();
      expect(pets.isNotEmpty, isTrue);
      // Verify descending order
      for (int i = 0; i < pets.length - 1; i++) {
        expect(pets[i].matchScore >= pets[i + 1].matchScore, isTrue);
      }
    });

    test('filters pets by species category', () async {
      final dogs = await repository.fetchAvailablePets(category: 'Dogs');
      expect(dogs.every((p) => p.species == 'Dog'), isTrue);

      final cats = await repository.fetchAvailablePets(category: 'Cats');
      expect(cats.every((p) => p.species == 'Cat'), isTrue);
    });

    test('filters pets by search query and smart species matching', () async {
      final results = await repository.fetchAvailablePets(searchQuery: 'Luna');
      expect(results.any((p) => p.name == 'Luna'), isTrue);

      // Smart search for 'fish' should return Bubbles and Crimson
      final fishPets = await repository.searchPets('fish');
      expect(fishPets.isNotEmpty, isTrue);
      expect(fishPets.any((p) => p.name == 'Bubbles' || p.name == 'Crimson'), isTrue);

      // Smart search for 'turtle' and Bengali 'কচ্ছপ' should return Shelly
      final turtlePets = await repository.searchPets('turtle');
      expect(turtlePets.any((p) => p.name == 'Shelly'), isTrue);
      final bnTurtlePets = await repository.searchPets('কচ্ছপ');
      expect(bnTurtlePets.any((p) => p.name == 'Shelly'), isTrue);

      // Smart search for 'gecko' or 'dragon' should return Ziggy and Draco
      final geckoPets = await repository.searchPets('gecko');
      expect(geckoPets.any((p) => p.name == 'Ziggy' || p.name == 'Draco'), isTrue);

      // Smart search for 'cat' should return Deshi, Persian, Siamese, Calico cats
      final catPets = await repository.searchPets('cat');
      expect(catPets.any((p) => p.name == 'Mimi' || p.name == 'Simba' || p.name == 'Mochi'), isTrue);
    });

    test('supports expanded pet categories and exotic breeds', () async {
      final fishCategory = await repository.fetchAvailablePets(category: 'Fish & Goldfish 🐠');
      expect(fishCategory.every((p) => p.species == 'Fish'), isTrue);

      final turtleCategory = await repository.fetchAvailablePets(category: 'Turtles / কচ্ছপ 🐢');
      expect(turtleCategory.every((p) => p.species == 'Turtle'), isTrue);

      final geckoCategory = await repository.fetchAvailablePets(category: 'Geckos & Dragons 🦎');
      expect(geckoCategory.every((p) => p.species == 'Gecko'), isTrue);
    });

    test('toggles pet favorite status', () async {
      final pet = (await repository.fetchAvailablePets()).first;
      final initialFavorite = pet.isFavorite;

      await repository.toggleFavorite(pet.id);
      final updated = await repository.getPetById(pet.id);
      expect(updated?.isFavorite, equals(!initialFavorite));
    });

    test('updates compatibility score based on lifestyle quiz answers', () async {
      repository.updateCompatibilityScoreFromQuiz(
        housing: 'Apartment',
        hasKids: true,
        hasPets: true,
        hoursAlone: 3,
        experience: 'Intermediate',
      );

      final pets = await repository.fetchAvailablePets();
      expect(pets.every((p) => p.matchScore >= 60 && p.matchScore <= 99), isTrue);
    });

    test('tracks quiz completion status and allows resetting', () async {
      await repository.resetQuiz();
      expect(repository.hasCompletedQuiz, isFalse);

      repository.updateCompatibilityScoreFromQuiz(
        housing: 'Apartment',
        hasKids: true,
        hasPets: false,
        hoursAlone: 8,
        experience: 'First-time pet parent',
      );

      expect(repository.hasCompletedQuiz, isTrue);
      final pets = await repository.fetchAvailablePets();
      for (int i = 0; i < pets.length - 1; i++) {
        expect(pets[i].matchScore >= pets[i + 1].matchScore, isTrue);
      }

      await repository.resetQuiz();
      expect(repository.hasCompletedQuiz, isFalse);
    });
  });
}

