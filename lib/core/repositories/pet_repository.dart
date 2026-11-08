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

  List<Pet> _pets = [
    const Pet(
      id: 'p1',
      name: 'Luna',
      species: 'Dog',
      breed: 'Lab Mix',
      ageDisplay: '2 yrs',
      ageMonths: 24,
      gender: 'Female',
      weightKg: 18.5,
      distanceKm: 2.4,
      matchScore: 95,
      imageUrl: 'https://images.unsplash.com/photo-1552053831-71594a27632d?auto=format&fit=crop&w=800&q=80',
      galleryUrls: [
        'https://images.unsplash.com/photo-1552053831-71594a27632d?auto=format&fit=crop&w=800&q=80',
        'https://images.unsplash.com/photo-1537151625747-768eb6cf92b2?auto=format&fit=crop&w=800&q=80',
        'https://images.unsplash.com/photo-1583511655857-d19b40a7a54e?auto=format&fit=crop&w=800&q=80',
      ],
      isFavorite: true,
      isUrgent: false,
      isFoster: false,
      isVaccinated: true,
      isNeutered: true,
      isHouseTrained: true,
      isKidSafe: true,
      isApartmentFriendly: true,
      shelterName: 'Dhaka Animal Rescue',
      shelterPhone: '+880 17•• ••••12',
      shelterAddress: 'Dhanmondi 27, Dhaka',
      shelterRating: 4.9,
      story: 'Luna was found near Dhanmondi Lake and nurtured by loving volunteers. She is gentle, loves belly rubs, and is completely house-trained and kid-friendly!',
      medicalHistory: 'DHPP Core Vaccines (Done Dec 2025), Rabies booster due Nov 2026, Dewormed monthly.',
      qrHash: 'ADOPT-PET-LUNA-DHAKA-2026-X99',
    ),
    const Pet(
      id: 'p2',
      name: 'Mochi',
      species: 'Cat',
      breed: 'Calico',
      ageDisplay: '1 yr',
      ageMonths: 12,
      gender: 'Female',
      weightKg: 3.8,
      distanceKm: 4.1,
      matchScore: 88,
      imageUrl: 'https://images.unsplash.com/photo-1514888286974-6c03e2ca1dba?auto=format&fit=crop&w=800&q=80',
      galleryUrls: [
        'https://images.unsplash.com/photo-1514888286974-6c03e2ca1dba?auto=format&fit=crop&w=800&q=80',
        'https://images.unsplash.com/photo-1573865526739-10659fec78a5?auto=format&fit=crop&w=800&q=80',
      ],
      isFavorite: false,
      isUrgent: false,
      isFoster: true,
      isVaccinated: true,
      isNeutered: true,
      isHouseTrained: true,
      isKidSafe: true,
      isApartmentFriendly: true,
      shelterName: 'Care For Paws BD',
      shelterPhone: '+880 18•• ••••45',
      shelterAddress: 'Gulshan 2, Dhaka',
      shelterRating: 4.8,
      story: 'Mochi is a calm and affectionate calico cat who enjoys sunny windowsills and quiet lap naps. Ideal for apartment living.',
      medicalHistory: 'FVRCP Triple Vaccine up-to-date, Rabies vaccinated, negative for FeLV/FIV.',
      qrHash: 'ADOPT-PET-MOCHI-GULSHAN-2026-M44',
    ),
    const Pet(
      id: 'p3',
      name: 'Cooper',
      species: 'Dog',
      breed: 'Golden Retriever',
      ageDisplay: '6 mos',
      ageMonths: 6,
      gender: 'Male',
      weightKg: 14.2,
      distanceKm: 6.8,
      matchScore: 91,
      imageUrl: 'https://images.unsplash.com/photo-1558788353-f76d92427f16?auto=format&fit=crop&w=800&q=80',
      galleryUrls: [
        'https://images.unsplash.com/photo-1558788353-f76d92427f16?auto=format&fit=crop&w=800&q=80',
        'https://images.unsplash.com/photo-1530281700549-e82e7bf110d6?auto=format&fit=crop&w=800&q=80',
      ],
      isFavorite: true,
      isUrgent: false,
      isFoster: false,
      isVaccinated: true,
      isNeutered: false,
      isHouseTrained: false,
      isKidSafe: true,
      isApartmentFriendly: false,
      shelterName: 'Pawfect Shelter BD',
      shelterPhone: '+880 19•• ••••77',
      shelterAddress: 'Uttara Sector 7, Dhaka',
      shelterRating: 5.0,
      story: 'Cooper is an energetic pup with a heart of gold. He loves running around and playing fetch with kids.',
      medicalHistory: 'Puppy core vaccination course completed, next booster due July 2026.',
      qrHash: 'ADOPT-PET-COOPER-UTTARA-2026-C88',
    ),
    const Pet(
      id: 'p4',
      name: 'Sage',
      species: 'Cat',
      breed: 'Grey Tabby',
      ageDisplay: '3 yrs',
      ageMonths: 36,
      gender: 'Male',
      weightKg: 4.5,
      distanceKm: 3.2,
      matchScore: 84,
      imageUrl: 'https://images.unsplash.com/photo-1574158622682-e40e69881006?auto=format&fit=crop&w=800&q=80',
      galleryUrls: [
        'https://images.unsplash.com/photo-1574158622682-e40e69881006?auto=format&fit=crop&w=800&q=80',
      ],
      isFavorite: false,
      isUrgent: false,
      isFoster: false,
      isVaccinated: true,
      isNeutered: true,
      isHouseTrained: true,
      isKidSafe: false,
      isApartmentFriendly: true,
      shelterName: 'Dhaka Animal Rescue',
      shelterPhone: '+880 17•• ••••12',
      shelterAddress: 'Dhanmondi, Dhaka',
      shelterRating: 4.9,
      story: 'Sage is an independent thinker who enjoys peaceful environments and bird watching from balconies.',
      medicalHistory: 'Fully immunized, microchip ID #BD99281747.',
      qrHash: 'ADOPT-PET-SAGE-DHANMONDI-2026-S12',
    ),
    const Pet(
      id: 'p5',
      name: 'Gizmo',
      species: 'Dog',
      breed: 'French Bulldog',
      ageDisplay: '4 yrs',
      ageMonths: 48,
      gender: 'Male',
      weightKg: 12.0,
      distanceKm: 1.8,
      matchScore: 92,
      imageUrl: 'https://images.unsplash.com/photo-1583511655857-d19b40a7a54e?auto=format&fit=crop&w=800&q=80',
      galleryUrls: [
        'https://images.unsplash.com/photo-1583511655857-d19b40a7a54e?auto=format&fit=crop&w=800&q=80',
      ],
      isFavorite: false,
      isUrgent: false,
      isFoster: false,
      isVaccinated: true,
      isNeutered: true,
      isHouseTrained: true,
      isKidSafe: true,
      isApartmentFriendly: true,
      shelterName: 'Banani Pet Care League',
      shelterPhone: '+880 16•• ••••99',
      shelterAddress: 'Banani Block C, Dhaka',
      shelterRating: 4.7,
      story: 'Gizmo is a couch potato at heart! He loves short walks, snacking on carrots, and snoozing next to his human.',
      medicalHistory: 'All seasonal boosters up-to-date, allergy-screened hypoallergenic diet.',
      qrHash: 'ADOPT-PET-GIZMO-BANANI-2026-G55',
    ),
    const Pet(
      id: 'p6',
      name: 'Peach',
      species: 'Cat',
      breed: 'Orange Tabby',
      ageDisplay: '2 yrs',
      ageMonths: 24,
      gender: 'Female',
      weightKg: 3.5,
      distanceKm: 5.5,
      matchScore: 89,
      imageUrl: 'https://images.unsplash.com/photo-1533738363-b7f9aef128ce?auto=format&fit=crop&w=800&q=80',
      galleryUrls: [
        'https://images.unsplash.com/photo-1533738363-b7f9aef128ce?auto=format&fit=crop&w=800&q=80',
      ],
      isFavorite: false,
      isUrgent: false,
      isFoster: false,
      isVaccinated: true,
      isNeutered: true,
      isHouseTrained: true,
      isKidSafe: true,
      isApartmentFriendly: true,
      shelterName: 'Care For Paws BD',
      shelterPhone: '+880 18•• ••••45',
      shelterAddress: 'Gulshan 2, Dhaka',
      shelterRating: 4.8,
      story: 'Sweet Peach is a chatterbox who purrs the moment you walk into the room. Loves feathers and catnip toys.',
      medicalHistory: 'All vaccinations verified, spayed, microchipped.',
      qrHash: 'ADOPT-PET-PEACH-GULSHAN-2026-P33',
    ),
    const Pet(
      id: 'p7',
      name: 'Daisy',
      species: 'Dog',
      breed: 'Beagle Mix',
      ageDisplay: '1 yr',
      ageMonths: 12,
      gender: 'Female',
      weightKg: 10.5,
      distanceKm: 8.2,
      matchScore: 86,
      imageUrl: 'https://images.unsplash.com/photo-1505628346881-b72b27e84530?auto=format&fit=crop&w=800&q=80',
      galleryUrls: [
        'https://images.unsplash.com/photo-1505628346881-b72b27e84530?auto=format&fit=crop&w=800&q=80',
      ],
      isFavorite: false,
      isUrgent: false,
      isFoster: true,
      isVaccinated: true,
      isNeutered: true,
      isHouseTrained: true,
      isKidSafe: true,
      isApartmentFriendly: true,
      shelterName: 'Mirpur Animal Sanctuary',
      shelterPhone: '+880 17•• ••••55',
      shelterAddress: 'Mirpur 10, Dhaka',
      shelterRating: 4.6,
      story: 'Daisy has an inquisitive nose and a joyful spirit. She loves sniffing games and long park walks.',
      medicalHistory: 'Rabies vaccine valid until March 2027.',
      qrHash: 'ADOPT-PET-DAISY-MIRPUR-2026-D22',
    ),
    const Pet(
      id: 'p8',
      name: 'Onyx',
      species: 'Cat',
      breed: 'British Shorthair',
      ageDisplay: '5 yrs',
      ageMonths: 60,
      gender: 'Male',
      weightKg: 5.2,
      distanceKm: 12.0,
      matchScore: 90,
      imageUrl: 'https://images.unsplash.com/photo-1518791841217-8f162f1e1131?auto=format&fit=crop&w=800&q=80',
      galleryUrls: [
        'https://images.unsplash.com/photo-1518791841217-8f162f1e1131?auto=format&fit=crop&w=800&q=80',
      ],
      isFavorite: false,
      isUrgent: false,
      isFoster: false,
      isVaccinated: true,
      isNeutered: true,
      isHouseTrained: true,
      isKidSafe: true,
      isApartmentFriendly: true,
      shelterName: 'Uttara Cat Rescue',
      shelterPhone: '+880 19•• ••••02',
      shelterAddress: 'Uttara Sector 3, Dhaka',
      shelterRating: 4.9,
      story: 'Onyx is a regal gentleman with stunning plush coat. He is very tranquil and gets along with other felines.',
      medicalHistory: 'Senior health screening passed with flying colors.',
      qrHash: 'ADOPT-PET-ONYX-UTTARA-2026-O77',
    ),
    const Pet(
      id: 'p9',
      name: 'Bella',
      species: 'Dog',
      breed: 'Poodle Mix',
      ageDisplay: '3 yrs',
      ageMonths: 36,
      gender: 'Female',
      weightKg: 8.0,
      distanceKm: 3.8,
      matchScore: 94,
      imageUrl: 'https://images.unsplash.com/photo-1516734212186-a967f81ad0d7?auto=format&fit=crop&w=800&q=80',
      galleryUrls: [
        'https://images.unsplash.com/photo-1516734212186-a967f81ad0d7?auto=format&fit=crop&w=800&q=80',
      ],
      isFavorite: true,
      isUrgent: false,
      isFoster: false,
      isVaccinated: true,
      isNeutered: true,
      isHouseTrained: true,
      isKidSafe: true,
      isApartmentFriendly: true,
      shelterName: 'Dhaka Animal Rescue',
      shelterPhone: '+880 17•• ••••12',
      shelterAddress: 'Dhanmondi, Dhaka',
      shelterRating: 4.9,
      story: 'Bella is hypoallergenic, very intelligent, knows 8 voice commands, and gives the sweetest cuddles.',
      medicalHistory: 'Vaccinated and dental cleaning performed Jan 2026.',
      qrHash: 'ADOPT-PET-BELLA-DHANMONDI-2026-B81',
    ),
    const Pet(
      id: 'p10',
      name: 'Jasper',
      species: 'Cat',
      breed: 'Siamese',
      ageDisplay: '2 yrs',
      ageMonths: 24,
      gender: 'Male',
      weightKg: 4.0,
      distanceKm: 7.0,
      matchScore: 87,
      imageUrl: 'https://images.unsplash.com/photo-1561948955-570b270e7c36?auto=format&fit=crop&w=800&q=80',
      galleryUrls: [
        'https://images.unsplash.com/photo-1561948955-570b270e7c36?auto=format&fit=crop&w=800&q=80',
      ],
      isFavorite: false,
      isUrgent: false,
      isFoster: false,
      isVaccinated: true,
      isNeutered: true,
      isHouseTrained: true,
      isKidSafe: true,
      isApartmentFriendly: true,
      shelterName: 'Care For Paws BD',
      shelterPhone: '+880 18•• ••••45',
      shelterAddress: 'Gulshan 2, Dhaka',
      shelterRating: 4.8,
      story: 'Jasper has mesmerizing sapphire eyes and vocal charm. He greets you enthusiastically at the door.',
      medicalHistory: 'Complete vaccination records documented.',
      qrHash: 'ADOPT-PET-JASPER-GULSHAN-2026-J19',
    ),
    const Pet(
      id: 'p11',
      name: 'Max',
      species: 'Dog',
      breed: 'Golden Retriever',
      ageDisplay: '1.5 yrs',
      ageMonths: 18,
      gender: 'Male',
      weightKg: 22.0,
      distanceKm: 4.5,
      matchScore: 93,
      imageUrl: 'https://images.unsplash.com/photo-1552053831-71594a27632d?auto=format&fit=crop&w=800&q=80',
      galleryUrls: [
        'https://images.unsplash.com/photo-1552053831-71594a27632d?auto=format&fit=crop&w=800&q=80',
      ],
      isFavorite: false,
      isUrgent: true,
      isFoster: false,
      isVaccinated: true,
      isNeutered: true,
      isHouseTrained: true,
      isKidSafe: true,
      isApartmentFriendly: false,
      shelterName: 'Dhaka Paws Foundation',
      shelterPhone: '+880 15•• ••••33',
      shelterAddress: 'Bashundhara R/A, Dhaka',
      shelterRating: 5.0,
      story: 'Max is looking for an active family with a yard. He is obedient, leash-trained, and extremely friendly.',
      medicalHistory: 'Full vaccination certificate issued by Central Vet Hospital.',
      qrHash: 'ADOPT-PET-MAX-BASHUNDHARA-2026-M01',
    ),
    const Pet(
      id: 'p12',
      name: 'Charlie',
      species: 'Bird',
      breed: 'Parakeet',
      ageDisplay: '1 yr',
      ageMonths: 12,
      gender: 'Male',
      weightKg: 0.1,
      distanceKm: 3.5,
      matchScore: 85,
      imageUrl: 'https://images.unsplash.com/photo-1552728089-57bdde30beb3?auto=format&fit=crop&w=800&q=80',
      galleryUrls: [
        'https://images.unsplash.com/photo-1552728089-57bdde30beb3?auto=format&fit=crop&w=800&q=80',
      ],
      isFavorite: false,
      isUrgent: false,
      isFoster: false,
      isVaccinated: true,
      isNeutered: false,
      isHouseTrained: true,
      isKidSafe: true,
      isApartmentFriendly: true,
      shelterName: 'Dhaka Avian Sanctuary',
      shelterPhone: '+880 17•• ••••88',
      shelterAddress: 'Tejgaon, Dhaka',
      shelterRating: 4.7,
      story: 'Charlie sings cheerful melodies and whistles tunes. Very gentle and loves perching on shoulders.',
      medicalHistory: 'Avian health checkup done Dec 2025.',
      qrHash: 'ADOPT-PET-CHARLIE-TEJGAON-2026-C11',
    ),
    const Pet(
      id: 'p13',
      name: 'Pip',
      species: 'Small',
      breed: 'Holland Lop Bunny',
      ageDisplay: '8 mos',
      ageMonths: 8,
      gender: 'Female',
      weightKg: 1.4,
      distanceKm: 5.0,
      matchScore: 92,
      imageUrl: 'https://images.unsplash.com/photo-1585110396000-c9ffd4e4b308?auto=format&fit=crop&w=800&q=80',
      galleryUrls: [
        'https://images.unsplash.com/photo-1585110396000-c9ffd4e4b308?auto=format&fit=crop&w=800&q=80',
      ],
      isFavorite: false,
      isUrgent: false,
      isFoster: false,
      isVaccinated: true,
      isNeutered: true,
      isHouseTrained: true,
      isKidSafe: true,
      isApartmentFriendly: true,
      shelterName: 'Care For Paws BD',
      shelterPhone: '+880 18•• ••••45',
      shelterAddress: 'Gulshan 2, Dhaka',
      shelterRating: 4.8,
      story: 'Pip has floppy ears and loves nibbling on fresh hay and parsley. Litter-box trained and very gentle.',
      medicalHistory: 'RHDV2 vaccination current, spayed.',
      qrHash: 'ADOPT-PET-PIP-GULSHAN-2026-P02',
    ),
    const Pet(
      id: 'p14',
      name: 'Barnaby',
      species: 'Senior',
      breed: 'Basset Hound',
      ageDisplay: '9 yrs',
      ageMonths: 108,
      gender: 'Male',
      weightKg: 24.0,
      distanceKm: 8.5,
      matchScore: 95,
      imageUrl: 'https://images.unsplash.com/photo-1543466835-00a7907e9de1?auto=format&fit=crop&w=800&q=80',
      galleryUrls: [
        'https://images.unsplash.com/photo-1543466835-00a7907e9de1?auto=format&fit=crop&w=800&q=80',
      ],
      isFavorite: false,
      isUrgent: true,
      isFoster: false,
      isVaccinated: true,
      isNeutered: true,
      isHouseTrained: true,
      isKidSafe: true,
      isApartmentFriendly: true,
      shelterName: 'Senior Paws Haven',
      shelterPhone: '+880 17•• ••••99',
      shelterAddress: 'Uttara, Dhaka',
      shelterRating: 5.0,
      story: 'Barnaby is a wise, sleepy sweetheart waiting for a quiet retirement home. He loves short sniffs and long snoozes.',
      medicalHistory: 'Arthritis managed with glucosamine treats, heart and liver panels normal.',
      qrHash: 'ADOPT-PET-BARNABY-UTTARA-2026-B99',
    ),
    const Pet(
      id: 'p15',
      name: 'Bubbles',
      species: 'Fish',
      breed: 'Red Cap Goldfish',
      ageDisplay: '1 yr',
      ageMonths: 12,
      gender: 'Male',
      weightKg: 0.15,
      distanceKm: 3.5,
      matchScore: 92,
      imageUrl: 'https://images.unsplash.com/photo-1522069169874-c58ec4b76be5?auto=format&fit=crop&w=800&q=80',
      galleryUrls: [
        'https://images.unsplash.com/photo-1522069169874-c58ec4b76be5?auto=format&fit=crop&w=800&q=80',
        'https://images.unsplash.com/photo-1535591273668-578e31182c4f?auto=format&fit=crop&w=800&q=80',
      ],
      isFavorite: false,
      isUrgent: false,
      isFoster: false,
      isVaccinated: true,
      isNeutered: false,
      isHouseTrained: true,
      isKidSafe: true,
      isApartmentFriendly: true,
      shelterName: 'Dhaka Aquatic Sanctuary',
      shelterPhone: '+880 17•• ••••33',
      shelterAddress: 'Katabon, Dhaka',
      shelterRating: 4.8,
      story: 'Bubbles is an active, healthy Red Cap Oranda goldfish with a vibrant red crown. Peaceful and soothing for any home aquarium.',
      medicalHistory: 'Quarantine cleared, healthy finnage, swim-bladder healthy, fed high-grade pellet diet.',
      qrHash: 'ADOPT-PET-BUBBLES-KATABON-2026-F15',
    ),
    const Pet(
      id: 'p16',
      name: 'Crimson',
      species: 'Fish',
      breed: 'Betta Fish',
      ageDisplay: '8 mos',
      ageMonths: 8,
      gender: 'Male',
      weightKg: 0.05,
      distanceKm: 2.9,
      matchScore: 90,
      imageUrl: 'https://images.unsplash.com/photo-1535591273668-578e31182c4f?auto=format&fit=crop&w=800&q=80',
      galleryUrls: [
        'https://images.unsplash.com/photo-1535591273668-578e31182c4f?auto=format&fit=crop&w=800&q=80',
      ],
      isFavorite: false,
      isUrgent: false,
      isFoster: false,
      isVaccinated: true,
      isNeutered: false,
      isHouseTrained: true,
      isKidSafe: true,
      isApartmentFriendly: true,
      shelterName: 'Aquatic Life BD',
      shelterPhone: '+880 18•• ••••66',
      shelterAddress: 'Mirpur 10, Dhaka',
      shelterRating: 4.9,
      story: 'Crimson is a gorgeous Halfmoon Betta fish with stunning deep ruby fins. Extremely low-maintenance and ideal for compact study desks.',
      medicalHistory: 'Parasite-free, flared healthily, acclimated to conditioned tap water.',
      qrHash: 'ADOPT-PET-CRIMSON-MIRPUR-2026-F16',
    ),
    const Pet(
      id: 'p17',
      name: 'Shelly',
      species: 'Turtle',
      breed: 'Red-Eared Slider Turtle',
      ageDisplay: '3 yrs',
      ageMonths: 36,
      gender: 'Female',
      weightKg: 1.2,
      distanceKm: 4.6,
      matchScore: 89,
      imageUrl: 'https://images.unsplash.com/photo-1437622368342-7a3d73a34c8f?auto=format&fit=crop&w=800&q=80',
      galleryUrls: [
        'https://images.unsplash.com/photo-1437622368342-7a3d73a34c8f?auto=format&fit=crop&w=800&q=80',
      ],
      isFavorite: false,
      isUrgent: false,
      isFoster: false,
      isVaccinated: true,
      isNeutered: false,
      isHouseTrained: true,
      isKidSafe: true,
      isApartmentFriendly: true,
      shelterName: 'Reptile & Wildlife Rescue BD',
      shelterPhone: '+880 19•• ••••88',
      shelterAddress: 'Mohammadpur, Dhaka',
      shelterRating: 4.7,
      story: 'Shelly is a friendly semi-aquatic turtle who loves basking under her UVB lamp and greeting you at feeding time.',
      medicalHistory: 'Shell hardening excellent, no respiratory symptoms, regular calcium and multivitamin supplemented.',
      qrHash: 'ADOPT-PET-SHELLY-MOHAMMADPUR-2026-T17',
    ),
    const Pet(
      id: 'p18',
      name: 'Ziggy',
      species: 'Gecko',
      breed: 'Leopard Gecko',
      ageDisplay: '1 yr',
      ageMonths: 14,
      gender: 'Male',
      weightKg: 0.08,
      distanceKm: 5.2,
      matchScore: 91,
      imageUrl: 'https://images.unsplash.com/photo-1504450874802-0ba2bcd9b5ae?auto=format&fit=crop&w=800&q=80',
      galleryUrls: [
        'https://images.unsplash.com/photo-1504450874802-0ba2bcd9b5ae?auto=format&fit=crop&w=800&q=80',
      ],
      isFavorite: false,
      isUrgent: false,
      isFoster: false,
      isVaccinated: true,
      isNeutered: false,
      isHouseTrained: true,
      isKidSafe: true,
      isApartmentFriendly: true,
      shelterName: 'Exotic Pets Care Dhaka',
      shelterPhone: '+880 17•• ••••55',
      shelterAddress: 'Banani, Dhaka',
      shelterRating: 4.9,
      story: 'Ziggy is a calm and docile Leopard Gecko with yellow and lavender spots. Loves eating mealworms and resting on warm hides.',
      medicalHistory: 'Healthy fat tail reserves, clear shedding history, free of metabolic bone disease.',
      qrHash: 'ADOPT-PET-ZIGGY-BANANI-2026-G18',
    ),
    const Pet(
      id: 'p19',
      name: 'Draco',
      species: 'Gecko',
      breed: 'Bearded Dragon',
      ageDisplay: '2 yrs',
      ageMonths: 24,
      gender: 'Male',
      weightKg: 0.45,
      distanceKm: 6.1,
      matchScore: 88,
      imageUrl: 'https://images.unsplash.com/photo-1574063413132-355dbfd83e25?auto=format&fit=crop&w=800&q=80',
      galleryUrls: [
        'https://images.unsplash.com/photo-1574063413132-355dbfd83e25?auto=format&fit=crop&w=800&q=80',
      ],
      isFavorite: false,
      isUrgent: false,
      isFoster: false,
      isVaccinated: true,
      isNeutered: false,
      isHouseTrained: true,
      isKidSafe: true,
      isApartmentFriendly: true,
      shelterName: 'Exotic Pets Care Dhaka',
      shelterPhone: '+880 17•• ••••55',
      shelterAddress: 'Banani, Dhaka',
      shelterRating: 4.9,
      story: 'Draco is an interactive bearded dragon who loves head tilts, shoulder perches, and snacking on fresh greens and crickets.',
      medicalHistory: 'MBD screened negative, active joint mobility, pristine scales and healthy appetite.',
      qrHash: 'ADOPT-PET-DRACO-BANANI-2026-G19',
    ),
    const Pet(
      id: 'p20',
      name: 'Clover',
      species: 'Rabbit',
      breed: 'Holland Lop Rabbit',
      ageDisplay: '10 mos',
      ageMonths: 10,
      gender: 'Female',
      weightKg: 1.8,
      distanceKm: 3.2,
      matchScore: 93,
      imageUrl: 'https://images.unsplash.com/photo-1585110396000-c9ffd4e4b308?auto=format&fit=crop&w=800&q=80',
      galleryUrls: [
        'https://images.unsplash.com/photo-1585110396000-c9ffd4e4b308?auto=format&fit=crop&w=800&q=80',
      ],
      isFavorite: false,
      isUrgent: false,
      isFoster: false,
      isVaccinated: true,
      isNeutered: true,
      isHouseTrained: true,
      isKidSafe: true,
      isApartmentFriendly: true,
      shelterName: 'Care For Paws BD',
      shelterPhone: '+880 18•• ••••45',
      shelterAddress: 'Gulshan 2, Dhaka',
      shelterRating: 4.8,
      story: 'Clover is a sweet bunny with droopy lop ears. She is litter-trained, gentle with kids, and loves timothy hay and fresh cilantro.',
      medicalHistory: 'RHDV2 vaccinated, teeth alignment checked by vet, spayed and healthy.',
      qrHash: 'ADOPT-PET-CLOVER-GULSHAN-2026-R20',
    ),
    const Pet(
      id: 'p21',
      name: 'Simba',
      species: 'Cat',
      breed: 'Persian',
      ageDisplay: '2 yrs',
      ageMonths: 24,
      gender: 'Male',
      weightKg: 4.5,
      distanceKm: 3.8,
      matchScore: 94,
      imageUrl: 'https://images.unsplash.com/photo-1518791841217-8f162f1e1131?auto=format&fit=crop&w=800&q=80',
      galleryUrls: [
        'https://images.unsplash.com/photo-1518791841217-8f162f1e1131?auto=format&fit=crop&w=800&q=80',
      ],
      isFavorite: false,
      isUrgent: false,
      isFoster: false,
      isVaccinated: true,
      isNeutered: true,
      isHouseTrained: true,
      isKidSafe: true,
      isApartmentFriendly: true,
      shelterName: 'Dhaka Animal Rescue',
      shelterPhone: '+880 17•• ••••12',
      shelterAddress: 'Dhanmondi, Dhaka',
      shelterRating: 4.9,
      story: 'Simba is a majestic white Persian cat with a silky plush coat. Calm, docile, and enjoys quiet apartment snoozing.',
      medicalHistory: 'FVRCP vaccinated, Rabies booster complete, eyes and coat professionally groomed.',
      qrHash: 'ADOPT-PET-SIMBA-DHANMONDI-2026-C21',
    ),
    const Pet(
      id: 'p22',
      name: 'Leo',
      species: 'Cat',
      breed: 'Bengal',
      ageDisplay: '1 yr',
      ageMonths: 15,
      gender: 'Male',
      weightKg: 4.8,
      distanceKm: 5.8,
      matchScore: 92,
      imageUrl: 'https://images.unsplash.com/photo-1603775020644-eb8decd79994?auto=format&fit=crop&w=800&q=80',
      galleryUrls: [
        'https://images.unsplash.com/photo-1603775020644-eb8decd79994?auto=format&fit=crop&w=800&q=80',
      ],
      isFavorite: false,
      isUrgent: false,
      isFoster: false,
      isVaccinated: true,
      isNeutered: true,
      isHouseTrained: true,
      isKidSafe: true,
      isApartmentFriendly: true,
      shelterName: 'Care For Paws BD',
      shelterPhone: '+880 18•• ••••45',
      shelterAddress: 'Gulshan 2, Dhaka',
      shelterRating: 4.8,
      story: 'Leo is an intelligent, leopard-spotted Bengal cat with playful energy. Loves interactive feather wands and cat towers.',
      medicalHistory: 'Full vaccination certificate, microchipped, negative for genetic cardiac conditions.',
      qrHash: 'ADOPT-PET-LEO-GULSHAN-2026-C22',
    ),
    const Pet(
      id: 'p23',
      name: 'Mimi',
      species: 'Cat',
      breed: 'Domestic Shorthair (দেশি বিড়াল)',
      ageDisplay: '8 mos',
      ageMonths: 8,
      gender: 'Female',
      weightKg: 3.2,
      distanceKm: 2.1,
      matchScore: 96,
      imageUrl: 'https://images.unsplash.com/photo-1543852786-1cf6624b9987?auto=format&fit=crop&w=800&q=80',
      galleryUrls: [
        'https://images.unsplash.com/photo-1543852786-1cf6624b9987?auto=format&fit=crop&w=800&q=80',
      ],
      isFavorite: true,
      isUrgent: true,
      isFoster: false,
      isVaccinated: true,
      isNeutered: true,
      isHouseTrained: true,
      isKidSafe: true,
      isApartmentFriendly: true,
      shelterName: 'Dhaka Animal Rescue',
      shelterPhone: '+880 17•• ••••12',
      shelterAddress: 'Dhanmondi, Dhaka',
      shelterRating: 4.9,
      story: 'Mimi is an energetic and affectionate rescued Deshi cat. Resilient, healthy, loving, and very loyal to her humans.',
      medicalHistory: 'Fully vaccinated, dewormed, spayed, ready for loving adoption.',
      qrHash: 'ADOPT-PET-MIMI-DHANMONDI-2026-C23',
    ),
  ];


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

