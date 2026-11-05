import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../network/api_client.dart';
import '../models/pet_model.dart';
import '../models/application_model.dart';

class LaravelPetService {
  final ApiClient _apiClient;

  LaravelPetService({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient();

  /// Tinder-style swipe stack: fetches candidate pets excluding already swiped ones
  Future<List<Pet>> getSwipeStack() async {
    try {
      final response = await _apiClient.dio.get('/pets/swipe-stack');
      if (response.statusCode == 200 && response.data['success'] == true) {
        final List data = response.data['data'] as List;
        return data.map((json) => _petFromJson(json)).toList();
      }
      return [];
    } catch (e) {
      debugPrint('[LaravelPetService] getSwipeStack error: $e');
      return [];
    }
  }

  /// Record user swipe decision ('like' or 'dislike')
  Future<bool> recordSwipe(String petId, {required bool isLike}) async {
    try {
      final response = await _apiClient.dio.post(
        '/pets/$petId/like',
        data: {'direction': isLike ? 'like' : 'dislike'},
      );
      return response.data['success'] == true;
    } catch (e) {
      debugPrint('[LaravelPetService] recordSwipe error: $e');
      return false;
    }
  }

  /// Haversine nearby pets search
  Future<List<Pet>> getNearbyPets({
    required double lat,
    required double lng,
    double radiusKm = 50.0,
  }) async {
    try {
      final response = await _apiClient.dio.get('/pets/nearby', queryParameters: {
        'lat': lat,
        'lng': lng,
        'radius': radiusKm,
      });

      if (response.statusCode == 200 && response.data['success'] == true) {
        final List data = response.data['data'] as List;
        return data.map((json) => _petFromJson(json)).toList();
      }
      return [];
    } catch (e) {
      debugPrint('[LaravelPetService] getNearbyPets error: $e');
      return [];
    }
  }

  /// Submit full 28-field adoption dossier to Laravel backend
  Future<Map<String, dynamic>?> submitAdoptionRequest({
    required String petId,
    required Map<String, dynamic> answersJson,
  }) async {
    try {
      final response = await _apiClient.dio.post('/adoption-requests', data: {
        'pet_id': petId,
        'answers_json': answersJson,
      });

      if (response.statusCode == 201 && response.data['success'] == true) {
        return response.data['data'];
      }
      return null;
    } on DioException catch (e) {
      debugPrint('[LaravelPetService] submitAdoptionRequest Dio error: ${e.response?.data ?? e.message}');
      rethrow;
    }
  }

  /// Fetch user submitted adoption requests
  Future<List<AdoptionApplication>> getMyAdoptionRequests() async {
    try {
      final response = await _apiClient.dio.get('/adoption-requests');
      if (response.statusCode == 200 && response.data['success'] == true) {
        final List data = response.data['data'] as List;
        return data.map((json) {
          final answers = json['answers_json'] is Map<String, dynamic>
              ? json['answers_json'] as Map<String, dynamic>
              : <String, dynamic>{};
          return AdoptionApplication.fromJson({
            'id': json['id']?.toString() ?? '',
            'petId': json['pet_id']?.toString() ?? '',
            'petName': json['pet']?['name'] ?? 'Pet',
            'petBreed': json['pet']?['breed'] ?? '',
            'petImageUrl': json['pet']?['primary_image_url'] ?? '',
            'shelterName': json['pet']?['owner']?['name'] ?? 'AdoptMatch Shelter',
            'status': json['status'] ?? 'pending',
            'submittedAt': json['created_at'] ?? DateTime.now().toIso8601String(),
            ...answers,
          });
        }).toList();
      }
      return [];
    } catch (e) {
      debugPrint('[LaravelPetService] getMyAdoptionRequests error: $e');
      return [];
    }
  }

  Pet _petFromJson(Map<String, dynamic> json) {
    final images = (json['images'] as List?)
            ?.map((img) => img['image_url']?.toString() ?? '')
            .where((url) => url.isNotEmpty)
            .toList() ??
        [];

    final primaryUrl = json['primary_image_url']?.toString() ??
        (images.isNotEmpty
            ? images.first
            : 'https://images.unsplash.com/photo-1543466835-00a7907e9de1?w=800');

    final ageMonths = (json['age_months'] as num?)?.toInt() ?? 12;
    final ageDisplay = ageMonths >= 12
        ? '${(ageMonths / 12).floor()} ${(ageMonths / 12).floor() == 1 ? 'yr' : 'yrs'}'
        : '$ageMonths mos';

    return Pet(
      id: json['id']?.toString() ?? '',
      name: json['name'] ?? '',
      species: json['species'] ?? 'Dog',
      breed: json['breed'] ?? 'Mixed',
      ageDisplay: ageDisplay,
      ageMonths: ageMonths,
      gender: json['gender'] ?? 'Male',
      weightKg: (json['weight_kg'] as num?)?.toDouble() ?? 8.5,
      distanceKm: (json['distance_km'] as num?)?.toDouble() ?? 3.5,
      matchScore: (json['match_score'] as num?)?.toInt() ?? 95,
      imageUrl: primaryUrl,
      galleryUrls: images.isNotEmpty ? images : [primaryUrl],
      isFavorite: false,
      isUrgent: false,
      isFeatured: false,
      isFoster: false,
      isVaccinated: json['vaccination_status'] == true ||
          json['vaccination_status'] == 1,
      isNeutered: true,
      isHouseTrained: true,
      isKidSafe: true,
      isApartmentFriendly: true,
      shelterName: json['owner']?['name'] ?? 'AdoptMatch Shelter',
      shelterPhone: json['owner']?['phone'] ?? '+880 17•• ••••89',
      shelterAddress: 'Dhaka, Bangladesh',
      shelterRating: 4.9,
      story: json['description'] ?? 'Looking for a warm forever home.',
      medicalHistory: 'Up to date on vaccinations and health checks.',
      qrHash: json['qr_hash'] ?? 'ADOPT-PET-${json['id']}',
    );
  }
}
