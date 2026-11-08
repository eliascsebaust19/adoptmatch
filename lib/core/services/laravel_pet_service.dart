import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../network/api_client.dart';
import '../models/pet_model.dart';
import '../models/application_model.dart';

class LaravelPetService {
  final ApiClient _apiClient;

  LaravelPetService({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient();

  /// Fetch public pet catalog
  Future<List<Pet>> getPets({String? species, String? search, int page = 1}) async {
    try {
      final response = await _apiClient.dio.get(
        '/pets',
        queryParameters: {
          if (species != null && species != 'all') 'species': species,
          if (search != null && search.isNotEmpty) 'search': search,
          'page': page,
        },
        options: Options(
          receiveTimeout: const Duration(seconds: 4),
          sendTimeout: const Duration(seconds: 4),
        ),
      );

      if (response.statusCode == 200 &&
          (response.data['status'] == 'success' || response.data['success'] == true)) {
        final paginated = response.data['data'];
        final List data = paginated is Map ? (paginated['data'] as List? ?? []) : (paginated as List? ?? []);
        return data.map((json) => _petFromJson(json as Map<String, dynamic>)).toList();
      }
      throw Exception('The pet catalog response was invalid.');
    } catch (e) {
      debugPrint('[LaravelPetService] getPets error: $e');
      rethrow;
    }
  }

  Future<List<Pet>> getMyPets() async {
    final response = await _apiClient.dio.get('/my-pets');
    final raw = response.data['data'];
    if (response.statusCode != 200 || response.data['status'] != 'success') {
      throw Exception('Could not load your server listings.');
    }
    final List rows = raw is Map ? (raw['data'] as List? ?? []) : (raw as List? ?? []);
    return rows.map((json) => _petFromJson(Map<String, dynamic>.from(json as Map))).toList();
  }

  Future<Pet> createPet(Map<String, dynamic> payload) async {
    final response = await _apiClient.dio.post('/pets', data: payload);
    if ((response.statusCode != 200 && response.statusCode != 201) ||
        response.data['status'] != 'success' || response.data['data'] == null) {
      throw Exception('The server did not create the listing.');
    }
    return _petFromJson(Map<String, dynamic>.from(response.data['data'] as Map));
  }

  Future<void> updatePetStatus(String id, String status) async {
    final response = await _apiClient.dio.put('/pets/$id', data: {'adoption_status': status});
    if (response.statusCode != 200 || response.data['status'] != 'success') {
      throw Exception('The server did not update the listing.');
    }
  }

  Future<void> deletePet(String id) async {
    final response = await _apiClient.dio.delete('/pets/$id');
    if (response.statusCode != 200 || response.data['status'] != 'success') {
      throw Exception('The server did not delete the listing.');
    }
  }

  /// Fetch detailed information for a single pet by ID
  Future<Pet?> getPetDetails(String id) async {
    try {
      final response = await _apiClient.dio.get('/pets/$id');
      if (response.statusCode == 200 &&
          (response.data['status'] == 'success' || response.data['success'] == true)) {
        final data = response.data['data'] as Map<String, dynamic>;
        return _petFromJson(data);
      }
      throw Exception('The pet detail response was invalid.');
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      rethrow;
    } catch (e) {
      debugPrint('[LaravelPetService] getPetDetails error: $e');
      rethrow;
    }
  }

  /// Tinder-style swipe stack: fetches candidate pets excluding already swiped ones
  Future<List<Pet>> getSwipeStack() async {
    try {
      final response = await _apiClient.dio.get('/pets/swipe-stack');
      if (response.statusCode == 200 &&
          (response.data['status'] == 'success' || response.data['success'] == true)) {
        final List data = response.data['data'] as List;
        return data.map((json) => _petFromJson(json as Map<String, dynamic>)).toList();
      }
      throw Exception('The swipe catalog response was invalid.');
    } catch (e) {
      debugPrint('[LaravelPetService] getSwipeStack error: $e');
      rethrow;
    }
  }

  /// Record user swipe decision ('like' or 'dislike')
  Future<bool> recordSwipe(String petId, {required bool isLike}) async {
    try {
      final response = await _apiClient.dio.post(
        '/pets/$petId/like',
        data: {'direction': isLike ? 'like' : 'dislike'},
      );
      return response.data['status'] == 'success' || response.data['success'] == true;
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
        'latitude': lat,
        'longitude': lng,
        'radius_km': radiusKm,
      });

      if (response.statusCode == 200 &&
          (response.data['status'] == 'success' || response.data['success'] == true)) {
        final rawData = response.data['data'];
        final List data = rawData is Map ? (rawData['data'] as List? ?? []) : (rawData as List? ?? []);
        return data.map((json) => _petFromJson(json as Map<String, dynamic>)).toList();
      }
      throw Exception('The nearby catalog response was invalid.');
    } catch (e) {
      debugPrint('[LaravelPetService] getNearbyPets error: $e');
      rethrow;
    }
  }

  /// Submit full 28-field adoption dossier to Laravel backend
  Future<Map<String, dynamic>?> submitAdoptionRequest({
    required String petId,
    required Map<String, dynamic> answersJson,
    required String signatureData,
  }) async {
    try {
      final response = await _apiClient.dio.post('/adoption-requests', data: {
        'pet_id': int.tryParse(petId) ?? petId,
        'applicant_data': answersJson,
        'signature_data': signatureData,
      });

      if ((response.statusCode == 200 || response.statusCode == 201) &&
          (response.data['status'] == 'success' || response.data['success'] == true)) {
        return Map<String, dynamic>.from(response.data['data'] as Map);
      }
      throw Exception('The server did not confirm the application.');
    } on DioException catch (e) {
      debugPrint('[LaravelPetService] submitAdoptionRequest Dio error: ${e.response?.data ?? e.message}');
      rethrow;
    }
  }

  /// Fetch user submitted adoption requests
  Future<List<AdoptionApplication>> getMyAdoptionRequests({bool received = false}) async {
    try {
      final response = await _apiClient.dio.get('/adoption-requests',
        queryParameters: {'type': received ? 'received' : 'submitted'});
      if (response.statusCode == 200 &&
          (response.data['status'] == 'success' || response.data['success'] == true)) {
        final rawData = response.data['data'];
        final List data = rawData is Map ? (rawData['data'] as List? ?? []) : (rawData as List? ?? []);
        return data.map((json) {
          final answers = Map<String, dynamic>.from(json['applicant_data'] as Map? ?? {});
          return AdoptionApplication.fromJson({
            'id': json['reference_no']?.toString() ?? json['id']?.toString() ?? '',
            'serverId': json['id']?.toString(),
            'petId': json['pet_id']?.toString() ?? '',
            'petName': json['pet']?['name'] ?? 'Pet',
            'petBreed': json['pet']?['breed'] ?? '',
            'petImageUrl': json['pet']?['primary_image_url'] ?? '',
            'shelterName': json['pet']?['owner']?['name'] ?? 'AdoptMatch Shelter',
            'status': const {'submitted': 'submitted', 'under_review': 'underReview',
              'home_visit': 'homeVisitScheduled', 'foster_trial': 'fosterTrial',
              'approved': 'approved', 'rejected': 'rejected'}[json['status']] ?? 'submitted',
            'reviewerNotes': json['reviewer_notes'],
            'homeVisitDate': json['home_visit_date'],
            'signatureData': json['signature_data'],
            'isESigned': json['is_signed'] == true || json['is_signed'] == 1,
            'submittedAt': json['created_at'] ?? DateTime.now().toIso8601String(),
            ...answers,
          });
        }).toList();
      }
      throw Exception('The application list response was invalid.');
    } catch (e) {
      debugPrint('[LaravelPetService] getMyAdoptionRequests error: $e');
      rethrow;
    }
  }

  Future<void> updateAdoptionStatus(String serverId, ApplicationStatus status,
      {String? notes, DateTime? homeVisitDate}) async {
    const names = {'submitted': 'submitted', 'underReview': 'under_review',
      'homeVisitScheduled': 'home_visit', 'fosterTrial': 'foster_trial',
      'approved': 'approved', 'rejected': 'rejected'};
    final response = await _apiClient.dio.patch('/adoption-requests/$serverId/status', data: {
      'status': names[status.name], if (notes != null) 'reviewer_notes': notes,
      if (homeVisitDate != null) 'home_visit_date': homeVisitDate.toIso8601String(),
    });
    if (response.statusCode != 200 || response.data['status'] != 'success') {
      throw Exception('The server did not confirm the application status change.');
    }
  }

  Future<List<Pet>> getFavorites() async {
    final response = await _apiClient.dio.get('/favorites');
    final data = response.data['data'];
    if (response.statusCode != 200 || data is! List) {
      throw Exception('Could not load saved pets.');
    }
    return data.map((json) => _petFromJson(Map<String, dynamic>.from(json as Map))
        .copyWith(isFavorite: true)).toList();
  }

  Future<bool> getFavoriteStatus(String petId) async {
    final response = await _apiClient.dio.get('/pets/$petId/favorite');
    final data = response.data['data'];
    if (response.statusCode != 200 || data is! Map || data['is_favorite'] is! bool) {
      throw Exception('Could not verify saved-pet status.');
    }
    return data['is_favorite'] as bool;
  }

  Future<bool> setFavorite(String petId, bool favorite) async {
    final response = await _apiClient.dio.request(
      '/pets/$petId/favorite',
      options: Options(method: favorite ? 'PUT' : 'DELETE'),
    );
    final data = response.data['data'];
    if (!(response.statusCode == 200 || response.statusCode == 201) ||
        data is! Map || data['is_favorite'] != favorite) {
      throw Exception('The server did not confirm the favorite change.');
    }
    return favorite;
  }

  Pet _petFromJson(Map<String, dynamic> json) {
    final images = (json['images'] as List?)
            ?.map((img) {
              if (img is Map) return img['image_url']?.toString() ?? '';
              return img.toString();
            })
            .where((url) => url.isNotEmpty)
            .toList() ??
        [];

    final primaryUrl = json['primary_image_url']?.toString() ??
        (images.isNotEmpty ? images.first : '');
    final ageMonths = (json['age_months'] as num?)?.toInt() ?? 0;
    final ageDisplay = ageMonths <= 0 ? 'Age not provided' : ageMonths >= 12
        ? '${(ageMonths / 12).floor()} ${(ageMonths / 12).floor() == 1 ? 'yr' : 'yrs'}'
        : '$ageMonths mos';
    final vStatus = json['vaccination_status'];
    final bool isVaccinated = vStatus == true || vStatus == 1 ||
        (vStatus is String && const {'fully_vaccinated', 'vaccinated', 'up_to_date'}.contains(vStatus.toLowerCase()));

    return Pet(
      id: json['id']?.toString() ?? '',
      ownerId: (json['owner_id'] ?? json['user_id'] ?? json['owner']?['id'])?.toString(),
      name: json['name'] ?? '',
      species: json['species'] ?? 'Unknown',
      breed: json['breed'] ?? 'Mixed',
      ageDisplay: ageDisplay,
      ageMonths: ageMonths,
      gender: json['gender'] ?? 'Unknown',
      weightKg: (json['weight_kg'] as num?)?.toDouble() ?? 0,
      distanceKm: (json['distance_km'] as num?)?.toDouble() ?? double.infinity,
      matchScore: (json['match_score'] as num?)?.toInt() ?? 0,
      imageUrl: primaryUrl,
      galleryUrls: images,
      isFavorite: json['is_favorite'] == true || json['is_favorite'] == 1,
      isUrgent: false,
      isFeatured: false,
      isFoster: false,
      isVaccinated: isVaccinated,
      isNeutered: json['is_spayed_neutered'] == true || json['is_spayed_neutered'] == 1,
      isHouseTrained: json['is_house_trained'] == true || json['is_house_trained'] == 1,
      isKidSafe: json['is_kid_safe'] == true || json['is_kid_safe'] == 1,
      isApartmentFriendly: json['is_apartment_friendly'] == true || json['is_apartment_friendly'] == 1,
      shelterName: json['owner']?['name'] ?? 'Unknown shelter',
      shelterPhone: json['owner']?['phone'] ?? '',
      shelterAddress: json['location_city'] ?? 'Location not provided',
      shelterRating: (json['owner']?['rating'] as num?)?.toDouble() ?? 0,
      story: json['description'] ?? 'No description provided.',
      medicalHistory: json['medical_history'] ?? 'Medical history not provided.',
      qrHash: json['qr_hash'] ?? 'ADOPT-PET-${json['id']}',
      adoptionStatus: json['adoption_status']?.toString() ?? 'available',
    );
  }
}
