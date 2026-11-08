import 'package:equatable/equatable.dart';

class Pet extends Equatable {
  final String id;
  final String name;
  final String species; // 'Dog', 'Cat', 'Bird', 'Small', 'Senior'
  final String breed;
  final String ageDisplay; // '2 yrs', '6 mos', '1 yr', etc.
  final int ageMonths;
  final String gender; // 'Male', 'Female'
  final double weightKg;
  final double distanceKm;
  final int matchScore; // e.g., 95, 88, 91
  final String imageUrl;
  final List<String> galleryUrls;
  final bool isFavorite;
  final bool isUrgent;
  final bool isFeatured;
  final bool isFoster;
  final bool isVaccinated;
  final bool isNeutered;
  final bool isHouseTrained;
  final bool isKidSafe;
  final bool isApartmentFriendly;
  final String shelterName;
  final String shelterPhone; // Masked for privacy (e.g. "+880 17•• ••••89")
  final String shelterAddress;
  final double shelterRating;
  final String story;
  final String medicalHistory;
  final String qrHash;
  final String adoptionStatus;

  /// Server-side id of the listing owner, required to send them a message.
  final String? ownerId;

  const Pet({
    required this.id,
    required this.name,
    required this.species,
    required this.breed,
    required this.ageDisplay,
    required this.ageMonths,
    required this.gender,
    required this.weightKg,
    required this.distanceKm,
    required this.matchScore,
    required this.imageUrl,
    this.galleryUrls = const [],
    this.isFavorite = false,
    this.isUrgent = false,
    this.isFeatured = false,
    this.isFoster = false,
    this.isVaccinated = false,
    this.isNeutered = false,
    this.isHouseTrained = false,
    this.isKidSafe = false,
    this.isApartmentFriendly = false,
    required this.shelterName,
    required this.shelterPhone,
    required this.shelterAddress,
    this.shelterRating = 0,
    required this.story,
    this.medicalHistory = 'Medical history not provided.',
    this.qrHash = '',
    this.adoptionStatus = 'available',
    this.ownerId,
  });

  String get distanceLabel => distanceKm.isFinite ? '$distanceKm km' : 'Distance unavailable';

  Pet copyWith({
    String? id,
    String? name,
    String? species,
    String? breed,
    String? ageDisplay,
    int? ageMonths,
    String? gender,
    double? weightKg,
    double? distanceKm,
    int? matchScore,
    String? imageUrl,
    List<String>? galleryUrls,
    bool? isFavorite,
    bool? isUrgent,
    bool? isFeatured,
    bool? isFoster,
    bool? isVaccinated,
    bool? isNeutered,
    bool? isHouseTrained,
    bool? isKidSafe,
    bool? isApartmentFriendly,
    String? shelterName,
    String? shelterPhone,
    String? shelterAddress,
    double? shelterRating,
    String? story,
    String? medicalHistory,
    String? qrHash,
    String? adoptionStatus,
    String? ownerId,
  }) {
    return Pet(
      id: id ?? this.id,
      name: name ?? this.name,
      species: species ?? this.species,
      breed: breed ?? this.breed,
      ageDisplay: ageDisplay ?? this.ageDisplay,
      ageMonths: ageMonths ?? this.ageMonths,
      gender: gender ?? this.gender,
      weightKg: weightKg ?? this.weightKg,
      distanceKm: distanceKm ?? this.distanceKm,
      matchScore: matchScore ?? this.matchScore,
      imageUrl: imageUrl ?? this.imageUrl,
      galleryUrls: galleryUrls ?? this.galleryUrls,
      isFavorite: isFavorite ?? this.isFavorite,
      isUrgent: isUrgent ?? this.isUrgent,
      isFeatured: isFeatured ?? this.isFeatured,
      isFoster: isFoster ?? this.isFoster,
      isVaccinated: isVaccinated ?? this.isVaccinated,
      isNeutered: isNeutered ?? this.isNeutered,
      isHouseTrained: isHouseTrained ?? this.isHouseTrained,
      isKidSafe: isKidSafe ?? this.isKidSafe,
      isApartmentFriendly: isApartmentFriendly ?? this.isApartmentFriendly,
      shelterName: shelterName ?? this.shelterName,
      shelterPhone: shelterPhone ?? this.shelterPhone,
      shelterAddress: shelterAddress ?? this.shelterAddress,
      shelterRating: shelterRating ?? this.shelterRating,
      story: story ?? this.story,
      medicalHistory: medicalHistory ?? this.medicalHistory,
      qrHash: qrHash ?? this.qrHash,
      adoptionStatus: adoptionStatus ?? this.adoptionStatus,
      ownerId: ownerId ?? this.ownerId,
    );
  }

  @override
  List<Object?> get props => [
        id,
        name,
        species,
        breed,
        ageDisplay,
        ageMonths,
        gender,
        weightKg,
        distanceKm,
        matchScore,
        imageUrl,
        galleryUrls,
        isFavorite,
        isUrgent,
        isFeatured,
        isFoster,
        isVaccinated,
        isNeutered,
        isHouseTrained,
        isKidSafe,
        isApartmentFriendly,
        shelterName,
        shelterPhone,
        shelterAddress,
        shelterRating,
        story,
        medicalHistory,
        qrHash,
        adoptionStatus,
        ownerId,
      ];
}

