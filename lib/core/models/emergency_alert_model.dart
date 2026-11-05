import 'package:equatable/equatable.dart';

class EmergencyAlert extends Equatable {
  final String id;
  final String petId;
  final String petName;
  final String petBreed;
  final String imageUrl;
  final String lastSeenLocation;
  final double lat;
  final double lng;
  final int radiusKm; // 5 or 10 km
  final int rewardBdt;
  final DateTime reportedTime;
  final String description;
  final String contactPhone; // Masked for public safety
  final bool isActive;

  const EmergencyAlert({
    required this.id,
    required this.petId,
    required this.petName,
    required this.petBreed,
    required this.imageUrl,
    required this.lastSeenLocation,
    required this.lat,
    required this.lng,
    this.radiusKm = 5,
    this.rewardBdt = 5000,
    required this.reportedTime,
    required this.description,
    required this.contactPhone,
    this.isActive = true,
  });

  @override
  List<Object?> get props => [
        id,
        petId,
        petName,
        petBreed,
        imageUrl,
        lastSeenLocation,
        lat,
        lng,
        radiusKm,
        rewardBdt,
        reportedTime,
        description,
        contactPhone,
        isActive,
      ];
}

class VetClinic extends Equatable {
  final String id;
  final String name;
  final String address;
  final String phone;
  final bool is24Hours;
  final double distanceKm;
  final double rating;
  final String services;

  const VetClinic({
    required this.id,
    required this.name,
    required this.address,
    required this.phone,
    this.is24Hours = true,
    required this.distanceKm,
    this.rating = 4.8,
    required this.services,
  });

  @override
  List<Object?> get props => [
        id,
        name,
        address,
        phone,
        is24Hours,
        distanceKm,
        rating,
        services,
      ];
}

