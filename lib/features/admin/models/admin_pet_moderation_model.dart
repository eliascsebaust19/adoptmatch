import 'package:equatable/equatable.dart';

class FlaggedPetListing extends Equatable {
  final String id;
  final String petName;
  final String species;
  final String breed;
  final String postedBy;
  final String posterRole;
  final String city;
  final String imageUrl;
  final int reportsCount;
  final List<String> reportReasons;
  final bool isBanned;
  final bool isUrgent;
  final bool isFeatured;
  final DateTime listedAt;

  const FlaggedPetListing({
    required this.id,
    required this.petName,
    required this.species,
    required this.breed,
    required this.postedBy,
    required this.posterRole,
    required this.city,
    required this.imageUrl,
    required this.reportsCount,
    required this.reportReasons,
    required this.isBanned,
    required this.isUrgent,
    required this.isFeatured,
    required this.listedAt,
  });

  FlaggedPetListing copyWith({
    String? id,
    String? petName,
    String? species,
    String? breed,
    String? postedBy,
    String? posterRole,
    String? city,
    String? imageUrl,
    int? reportsCount,
    List<String>? reportReasons,
    bool? isBanned,
    bool? isUrgent,
    bool? isFeatured,
    DateTime? listedAt,
  }) {
    return FlaggedPetListing(
      id: id ?? this.id,
      petName: petName ?? this.petName,
      species: species ?? this.species,
      breed: breed ?? this.breed,
      postedBy: postedBy ?? this.postedBy,
      posterRole: posterRole ?? this.posterRole,
      city: city ?? this.city,
      imageUrl: imageUrl ?? this.imageUrl,
      reportsCount: reportsCount ?? this.reportsCount,
      reportReasons: reportReasons ?? this.reportReasons,
      isBanned: isBanned ?? this.isBanned,
      isUrgent: isUrgent ?? this.isUrgent,
      isFeatured: isFeatured ?? this.isFeatured,
      listedAt: listedAt ?? this.listedAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        petName,
        species,
        breed,
        postedBy,
        posterRole,
        city,
        imageUrl,
        reportsCount,
        reportReasons,
        isBanned,
        isUrgent,
        isFeatured,
        listedAt,
      ];
}

