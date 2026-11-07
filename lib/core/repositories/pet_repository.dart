import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/pet_model.dart';
import '../services/local_storage_service.dart';
import '../services/laravel_pet_service.dart';

class PetRepository {
  static final PetRepository _instance = PetRepository._internal();
  factory PetRepository() => _instance;
  PetRepository._internal() {
    _initStorage();
  }

  final _laravelPetService = LaravelPetService();
  final _storage = LocalStorageService.instance;
  final _petStreamController = StreamController<List<Pet>>.broadcast();
  Stream<List<Pet>> get petsStream => _petStreamController.stream;
  List<Pet> get pets => List.unmodifiable(_pets);

  bool _hasCompletedQuiz = false;
  bool get hasCompletedQuiz => _hasCompletedQuiz;

  Map<String, dynamic>? _quizAnswers;
  Map<String, dynamic>? get quizAnswers => _quizAnswers;

  Future<void> _initStorage() async {
    final favIds = await _storage.loadFavorites();
    if (favIds.isNotEmpty) {
      _pets = _pets.map((p) => p.copyWith(isFavorite: favIds.contains(p.id))).toList();
    }
    _hasCompletedQuiz = await _storage.loadQuizCompleted();
    _quizAnswers = await _storage.loadQuizAnswers();
    if (_hasCompletedQuiz && _quizAnswers != null) {
      _applyCompatibilityAlgorithm(
        housing: _quizAnswers!['housing'] as String? ?? 'Apartment',
        hasKids: _quizAnswers!['hasKids'] as bool? ?? false,
        hasPets: _quizAnswers!['hasPets'] as bool? ?? false,
        hoursAlone: _quizAnswers!['hoursAlone'] as int? ?? 4,
        experience: _quizAnswers!['experience'] as String? ?? 'Intermediate',
        persist: false,
      );
    } else {
      _petStreamController.add(List.unmodifiable(_pets));
    }
  }

  List<Pet> _pets = [];

  /// Sets test fixture pets during unit testing
  void setPetsForTesting(List<Pet> testPets) {
    _pets = List.from(testPets);
    _petStreamController.add(List.unmodifiable(_pets));
  }

  Future<List<Pet>> getAllPets() async {
    return List.unmodifiable(_pets);
  }

  /// Smart keyword and species/breed matching helper
  bool _matchesSmartSearch(Pet pet, String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return true;

    final name = pet.name.toLowerCase();
    final breed = pet.breed.toLowerCase();
    final species = pet.species.toLowerCase();
    final shelter = pet.shelterName.toLowerCase();
    final address = pet.shelterAddress.toLowerCase();
    final story = pet.story.toLowerCase();

    // Direct match against pet metadata
    if (name.contains(q) ||
        breed.contains(q) ||
        species.contains(q) ||
        shelter.contains(q) ||
        address.contains(q) ||
        story.contains(q)) {
      return true;
    }

    // Smart synonym and species group matching
    // Dog synonyms: dog, dogs, puppy, puppies, canine, hound, kukur, কুকুর
    if (q == 'dog' || q == 'dogs' || q == 'puppy' || q == 'puppies' || q == 'canine' || q == 'hound' || q == 'কুকুর') {
      return species == 'dog' ||
          breed.contains('retriever') ||
          breed.contains('hound') ||
          breed.contains('lab') ||
          breed.contains('poodle') ||
          breed.contains('terrier');
    }

    // Cat synonyms: cat, cats, kitten, kittens, feline, kitty, biral, বিড়াল, বিড়াল
    if (q == 'cat' || q == 'cats' || q == 'kitten' || q == 'kittens' || q == 'feline' || q == 'kitty' || q == 'বিড়াল' || q == 'বিড়াল') {
      return species == 'cat' ||
          breed.contains('calico') ||
          breed.contains('persian') ||
          breed.contains('siamese') ||
          breed.contains('bengal') ||
          breed.contains('shorthair');
    }

    // Bird synonyms: bird, birds, parakeet, parrot, avian, পাখি
    if (q == 'bird' || q == 'birds' || q == 'parakeet' || q == 'parrot' || q == 'avian' || q == 'পাখি') {
      return species == 'bird' || breed.contains('parakeet') || breed.contains('parrot');
    }

    // Fish synonyms: fish, fishes, goldfish, betta, aquatic, mach, মাছ
    if (q == 'fish' || q == 'fishes' || q == 'goldfish' || q == 'betta' || q == 'aquatic' || q == 'মাছ') {
      return species == 'fish' || breed.contains('goldfish') || breed.contains('betta');
    }

    // Turtle synonyms: turtle, turtles, tortoise, terrapin, kochchop, কচ্ছপ
    if (q == 'turtle' || q == 'turtles' || q == 'tortoise' || q == 'terrapin' || q == 'কচ্ছপ') {
      return species == 'turtle' || breed.contains('turtle') || breed.contains('slider');
    }

    // Gecko / Lizard synonyms: gecko, geckos, lizard, lizards, bearded dragon, dragon, reptiles, টিকটিকি
    if (q == 'gecko' || q == 'geckos' || q == 'lizard' || q == 'lizards' || q == 'dragon' || q == 'bearded dragon' || q == 'reptile' || q == 'reptiles') {
      return species == 'gecko' || breed.contains('gecko') || breed.contains('dragon');
    }

    // Rabbit / Bunny synonyms: rabbit, rabbits, bunny, bunnies, hare, khorgosh, খরগোশ
    if (q == 'rabbit' || q == 'rabbits' || q == 'bunny' || q == 'bunnies' || q == 'hare' || q == 'খরগোশ') {
      return species == 'rabbit' ||
          species == 'small' ||
          breed.contains('lop') ||
          breed.contains('bunny') ||
          breed.contains('rabbit');
    }

    return false;
  }

  /// Searches pets using smart species, breed, name, and synonym logic
  Future<List<Pet>> searchPets(String query) async {
    return fetchAvailablePets(searchQuery: query);
  }

  Future<List<Pet>> fetchAvailablePets({
    String? category,
    String? searchQuery,
    double? maxDistanceKm,
    bool? kidSafeOnly,
    bool? apartmentOnly,
    bool? vaccinatedOnly,
  }) async {
    try {
      final remotePets = await _laravelPetService.getPets(
        species: (category != null && category != 'All Pets' && !category.toLowerCase().startsWith('all'))
            ? category.toLowerCase()
            : null,
        search: searchQuery,
      );
      if (remotePets.isNotEmpty) {
        var result = List<Pet>.from(remotePets);
        if (kidSafeOnly == true) {
          result = result.where((p) => p.isKidSafe).toList();
        }
        if (apartmentOnly == true) {
          result = result.where((p) => p.isApartmentFriendly).toList();
        }
        if (vaccinatedOnly == true) {
          result = result.where((p) => p.isVaccinated).toList();
        }
        return result;
      }
    } catch (e) {
      debugPrint('[PetRepository] Live fetch fallback to local list: ');
    }
    await Future.delayed(const Duration(milliseconds: 150));
    var result = List<Pet>.from(_pets);

    if (category != null && category != 'All Pets' && !category.toLowerCase().startsWith('all')) {
      final cat = category.toLowerCase();
      if (cat.contains('dog')) {
        result = result.where((p) => p.species.toLowerCase() == 'dog').toList();
      } else if (cat.contains('cat')) {
        result = result.where((p) => p.species.toLowerCase() == 'cat').toList();
      } else if (cat.contains('bird')) {
        result = result.where((p) => p.species.toLowerCase() == 'bird').toList();
      } else if (cat.contains('fish') || cat.contains('goldfish')) {
        result = result.where((p) => p.species.toLowerCase() == 'fish').toList();
      } else if (cat.contains('turtle') || cat.contains('কচ্ছপ')) {
        result = result.where((p) => p.species.toLowerCase() == 'turtle').toList();
      } else if (cat.contains('gecko') || cat.contains('dragon')) {
        result = result.where((p) => p.species.toLowerCase() == 'gecko').toList();
      } else if (cat.contains('rabbit') || cat.contains('bunny')) {
        result = result.where((p) => p.species.toLowerCase() == 'rabbit' || p.species.toLowerCase() == 'small').toList();
      } else if (cat.contains('small')) {
        result = result.where((p) => p.species.toLowerCase() == 'small' || p.species.toLowerCase() == 'rabbit').toList();
      } else if (cat.contains('senior')) {
        result = result.where((p) => p.species.toLowerCase() == 'senior' || p.ageMonths >= 84).toList();
      }
    }

    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      result = result.where((p) => _matchesSmartSearch(p, searchQuery)).toList();
    }

    if (maxDistanceKm != null && maxDistanceKm < 50) {
      result = result.where((p) => p.distanceKm <= maxDistanceKm).toList();
    }

    if (kidSafeOnly == true) {
      result = result.where((p) => p.isKidSafe).toList();
    }
    if (apartmentOnly == true) {
      result = result.where((p) => p.isApartmentFriendly).toList();
    }
    if (vaccinatedOnly == true) {
      result = result.where((p) => p.isVaccinated).toList();
    }

    // Sort by match score descending
    result.sort((a, b) => b.matchScore.compareTo(a.matchScore));
    return result;
  }

  Future<Pet?> getPetById(String id) async {
    try {
      return _pets.firstWhere((p) => p.id == id);
    } catch (_) {
      return null;
    }
  }

  Future<void> toggleFavorite(String id) async {
    final index = _pets.indexWhere((p) => p.id == id);
    if (index != -1) {
      final pet = _pets[index];
      _pets[index] = pet.copyWith(isFavorite: !pet.isFavorite);
      final favIds = _pets.where((p) => p.isFavorite).map((p) => p.id).toSet();
      await _storage.saveFavorites(favIds);
      _petStreamController.add(List.unmodifiable(_pets));
    }
  }

  Future<void> addPet(Pet pet) async {
    _pets.insert(0, pet);
    _petStreamController.add(List.unmodifiable(_pets));
  }

  Future<void> updatePet(Pet pet) async {
    final index = _pets.indexWhere((p) => p.id == pet.id);
    if (index != -1) {
      _pets[index] = pet;
      _petStreamController.add(List.unmodifiable(_pets));
    }
  }

  Future<void> deletePet(String petId) async {
    _pets.removeWhere((p) => p.id == petId);
    _petStreamController.add(List.unmodifiable(_pets));
  }

  Future<void> markAsAdopted(String petId) async {
    final index = _pets.indexWhere((p) => p.id == petId);
    if (index != -1) {
      // mark as non-urgent, foster false, update story
      _pets[index] = _pets[index].copyWith(
        story: '[ADOPTED] ${_pets[index].story}',
      );
      _petStreamController.add(List.unmodifiable(_pets));
    }
  }

  Future<List<Pet>> getFavoritePets() async {
    return _pets.where((p) => p.isFavorite).toList();
  }

  void updateCompatibilityScoreFromQuiz({
    required String housing,
    required bool hasKids,
    required bool hasPets,
    required int hoursAlone,
    required String experience,
  }) {
    _applyCompatibilityAlgorithm(
      housing: housing,
      hasKids: hasKids,
      hasPets: hasPets,
      hoursAlone: hoursAlone,
      experience: experience,
      persist: true,
    );
  }

  void _applyCompatibilityAlgorithm({
    required String housing,
    required bool hasKids,
    required bool hasPets,
    required int hoursAlone,
    required String experience,
    bool persist = true,
  }) {
    _hasCompletedQuiz = true;
    _quizAnswers = {
      'housing': housing,
      'hasKids': hasKids,
      'hasPets': hasPets,
      'hoursAlone': hoursAlone,
      'experience': experience,
    };

    if (persist) {
      _storage.saveQuizCompleted(true);
      _storage.saveQuizAnswers(_quizAnswers!);
    }

    final housingLower = housing.toLowerCase();
    final isApt = housingLower.contains('apartment');
    final isYard = housingLower.contains('yard');
    final isFarm = housingLower.contains('farm') || housingLower.contains('rural');

    final expLower = experience.toLowerCase();
    final isFirstTime = expLower.contains('first');
    final isExpert = expLower.contains('expert') || expLower.contains('foster');

    _pets = _pets.map((pet) {
      // Base score starts neutral at 72
      double score = 72.0;

      // 1. Housing Compatibility (±14%)
      if (isApt) {
        if (pet.isApartmentFriendly) {
          score += 12;
        } else {
          score -= 16;
        }
      } else if (isYard) {
        if (pet.species == 'Dog') {
          score += 10;
        } else {
          score += 6;
        }
      } else if (isFarm) {
        if (pet.species == 'Dog' && pet.weightKg > 15) {
          score += 14;
        } else {
          score += 8;
        }
      }

      // 2. Children Compatibility (±16%)
      if (hasKids) {
        if (pet.isKidSafe) {
          score += 14;
        } else {
          score -= 20;
        }
      } else {
        score += 4;
      }

      // 3. Other Pets (±8%)
      if (hasPets) {
        if (pet.species == 'Cat' || (pet.species == 'Dog' && pet.isKidSafe)) {
          score += 8;
        } else {
          score -= 4;
        }
      } else {
        score += 4;
      }

      // 4. Daily Hours Alone (±14%)
      if (hoursAlone >= 7) {
        // High alone time: independent cats & older pets score higher
        if (pet.species == 'Cat' || pet.species == 'Senior' || pet.ageMonths >= 36) {
          score += 14;
        } else if (pet.species == 'Dog' && pet.ageMonths < 12) {
          score -= 18; // Puppies should not be alone 7+ hours
        } else {
          score -= 8;
        }
      } else if (hoursAlone <= 3) {
        // Lots of human attention: active dogs & puppies flourish
        if (pet.species == 'Dog') {
          score += 12;
        } else {
          score += 6;
        }
      } else {
        // 4-6 hours: balanced
        if (pet.isHouseTrained) score += 6;
      }

      // 5. Experience (±10%)
      if (isFirstTime) {
        if (pet.isHouseTrained && pet.isVaccinated) {
          score += 10;
        } else {
          score -= 8;
        }
      } else if (isExpert) {
        if (pet.isUrgent || pet.isFoster) {
          score += 10;
        } else {
          score += 6;
        }
      } else {
        score += 6;
      }

      // House trained hygiene bonus
      if (pet.isHouseTrained) score += 4;

      // Clamping between 60% and 99%
      int finalScore = score.round();
      if (finalScore > 99) finalScore = 99;
      if (finalScore < 60) finalScore = 60;

      return pet.copyWith(matchScore: finalScore);
    }).toList();

    // Sort by descending compatibility score
    _pets.sort((a, b) => b.matchScore.compareTo(a.matchScore));
    _petStreamController.add(List.unmodifiable(_pets));
  }

  Future<void> resetQuiz() async {
    _hasCompletedQuiz = false;
    _quizAnswers = null;
    await _storage.clearQuiz();
    _petStreamController.add(List.unmodifiable(_pets));
  }
}

