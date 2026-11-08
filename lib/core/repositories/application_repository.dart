import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/application_model.dart';
import '../services/local_storage_service.dart';
import '../storage/secure_storage_service.dart';
import '../network/api_client.dart';
import '../services/laravel_pet_service.dart';

class ApplicationRepository {
  static final ApplicationRepository _instance = ApplicationRepository._internal();
  factory ApplicationRepository() => _instance;
  ApplicationRepository._internal();

  final _storage = LocalStorageService.instance;
  LaravelPetService _remote = LaravelPetService();
  http.Client _client = http.Client();
  Future<String?> Function() _readToken = SecureStorageService.instance.getAuthToken;
  void configureForTesting(LaravelPetService remote, {http.Client? client,
      Future<String?> Function()? tokenReader}) {
    _remote = remote;
    if (client != null) _client = client;
    if (tokenReader != null) _readToken = tokenReader;
    resetForTesting();
  }
  final _appStreamController = StreamController<List<AdoptionApplication>>.broadcast();
  Stream<List<AdoptionApplication>> get applicationsStream => _appStreamController.stream;

  List<AdoptionApplication> _applications = [];
  bool _initialized = false;
  Future<void>? _initFuture;

  Future<void> _init() {
    if (_initialized) return Future.value();
    _initFuture ??= _doInit();
    return _initFuture!;
  }

  Future<void> _doInit() async {
    try {
      final saved = await _storage.loadApplications();
      if (saved != null) {
        _applications = saved;
      } else {
        _applications = [];
      }
    } catch (_) {
      _applications = [];
    } finally {
      _initialized = true;
      _initFuture = null;
      _appStreamController.add(List.unmodifiable(_applications));
    }
  }

  void resetForTesting() {
    _initialized = false;
    _initFuture = null;
    _applications = [];
  }

  Future<List<AdoptionApplication>> getApplications({bool received = false}) async {
    if (!_initialized) await _init();
    final token = await _readToken();
    if (token == null || token.isEmpty) return const [];
    _applications = await _remote.getMyAdoptionRequests(received: received);
    await _storage.saveApplications(_applications);
    _appStreamController.add(List.unmodifiable(_applications));
    return List.unmodifiable(_applications);
  }

  Future<void> clearCache() async {
    await _storage.saveApplications([]);
    resetForTesting();
    _appStreamController.add(const []);
  }

  Future<AdoptionApplication?> getApplicationById(String id) async {
    if (!_initialized) await _init();
    try {
      return _applications.firstWhere((a) => a.id == id);
    } catch (_) {
      return null;
    }
  }

  Future<bool> hasActiveApplicationForPet(String petId) async {
    final applications = await getApplications();
    return applications.any(
      (a) => a.petId == petId &&
             a.status != ApplicationStatus.rejected &&
             a.status != ApplicationStatus.draft,
    );
  }

  Future<AdoptionApplication> submitApplication({
    required String petId,
    required String petName,
    required String petBreed,
    required String petImageUrl,
    required String applicantName,
    required String applicantPhone,
    required String applicantEmail,
    required String nidNumber,
    required String emergencyContactName,
    required String emergencyContactPhone,
    required String address,
    required String housingType,
    required String ownershipStatus,
    required bool landlordAllowsPets,
    String? landlordContact,
    required String yardType,
    required String petLivingSpace,
    required int totalAdults,
    required bool hasKids,
    String? childrenAges,
    required bool hasAllergies,
    required bool hasOtherPets,
    String? otherPetsDetails,
    required String dailyHoursAlone,
    required String primaryCaregiver,
    required String petExperience,
    required bool emergencyVetFund,
    required String monthlyBudget,
    required String whyAdopt,
    String? signatureData,
  }) async {
    if (!_initialized) await _init();

    final token = await _readToken();
    if (token == null || token.isEmpty) {
      throw Exception('Sign in before submitting an adoption application.');
    }

    final numericPetId = int.tryParse(petId);
    if (numericPetId == null) {
      throw Exception(
        'This listing is not published on the server yet, so an application cannot be submitted.',
      );
    }

    // The dossier must reach the backend before the app claims it was submitted.
    if (signatureData == null || signatureData.trim().isEmpty) {
      throw Exception('A recorded applicant signature is required.');
    }
    final String referenceId;
    Map<String, dynamic>? payload;
    try {
      final res = await _client.post(
        Uri.parse('${ApiClient.rootUrl}/api/v1/adoption-requests'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'pet_id': numericPetId,
          'applicant_data': {
            'applicantName': applicantName,
            'applicantPhone': applicantPhone,
            'applicantEmail': applicantEmail,
            'address': address,
            'housingType': housingType,
            'ownershipStatus': ownershipStatus,
            'landlordAllowsPets': landlordAllowsPets,
            'landlordContact': landlordContact,
            'yardType': yardType,
            'petLivingSpace': petLivingSpace,
            'totalAdults': totalAdults,
            'hasKids': hasKids,
            'childrenAges': childrenAges,
            'hasAllergies': hasAllergies,
            'hasOtherPets': hasOtherPets,
            'otherPetsDetails': otherPetsDetails,
            'dailyHoursAlone': dailyHoursAlone,
            'primaryCaregiver': primaryCaregiver,
            'petExperience': petExperience,
            'emergencyVetFund': emergencyVetFund,
            'monthlyBudget': monthlyBudget,
            'whyAdopt': whyAdopt,
            'nidNumber': nidNumber,
            'emergencyContactName': emergencyContactName,
            'emergencyContactPhone': emergencyContactPhone,
          },
          'signature_data': signatureData,
        }),
      ).timeout(const Duration(seconds: 10));

      if (res.statusCode != 200 && res.statusCode != 201) {
        String message = 'The server rejected the application (HTTP ${res.statusCode}).';
        try {
          final body = jsonDecode(res.body) as Map<String, dynamic>;
          message = (body['message'] ?? body['error'] ?? message).toString();
        } catch (_) {}
        throw Exception(message);
      }

      final data = jsonDecode(res.body) as Map<String, dynamic>;
      payload = data['data'] as Map<String, dynamic>?;
      if (data['status'] != 'success') throw Exception('The server did not confirm submission.');
      final reference = payload?['reference_no'] ?? data['reference_no'];
      if (reference == null) {
        throw Exception('The server did not return an application reference.');
      }
      referenceId = reference.toString();
    } catch (e) {
      debugPrint('[ApplicationRepository] Submission failed: $e');
      rethrow;
    }

    final newApp = AdoptionApplication(
      id: referenceId,
      serverId: payload?['id']?.toString(),
      petId: petId,
      petName: petName,
      petBreed: petBreed,
      petImageUrl: petImageUrl,
      applicantName: applicantName,
      applicantPhone: applicantPhone,
      applicantEmail: applicantEmail,
      nidNumber: nidNumber,
      emergencyContactName: emergencyContactName,
      emergencyContactPhone: emergencyContactPhone,
      address: address,
      housingType: housingType,
      ownershipStatus: ownershipStatus,
      landlordAllowsPets: landlordAllowsPets,
      landlordContact: landlordContact,
      yardType: yardType,
      petLivingSpace: petLivingSpace,
      totalAdults: totalAdults,
      hasKids: hasKids,
      childrenAges: childrenAges,
      hasAllergies: hasAllergies,
      hasOtherPets: hasOtherPets,
      otherPetsDetails: otherPetsDetails,
      dailyHoursAlone: dailyHoursAlone,
      primaryCaregiver: primaryCaregiver,
      petExperience: petExperience,
      emergencyVetFund: emergencyVetFund,
      monthlyBudget: monthlyBudget,
      whyAdopt: whyAdopt,
      status: ApplicationStatus.submitted,
      submittedAt: DateTime.now(),
      reviewerNotes: 'Application submitted. Committee assigned for initial document verification.',
      isESigned: true,
      signatureData: signatureData,
    );

    _applications.insert(0, newApp);
    await _storage.saveApplications(_applications);
    await _storage.clearApplicationDraft(petId);
    _appStreamController.add(List.unmodifiable(_applications));
    return newApp;
  }

  Future<void> saveDraft(String petId, Map<String, dynamic> draftData) async {
    await _storage.saveApplicationDraft(petId, draftData);
  }

  Future<Map<String, dynamic>?> getDraft(String petId) async {
    return _storage.loadApplicationDraft(petId);
  }

  Future<void> clearDraft(String petId) async {
    await _storage.clearApplicationDraft(petId);
  }

  Future<void> updateApplicationStatus(String appId, ApplicationStatus status,
      {String? notes, DateTime? homeVisitDate}) async {
    await _init();
    final index = _applications.indexWhere((a) => a.id == appId);
    if (index == -1 || _applications[index].serverId == null) {
      throw Exception('Load the server application before changing its status.');
    }
    final app = _applications[index];
    await _remote.updateAdoptionStatus(app.serverId!, status, notes: notes, homeVisitDate: homeVisitDate);
    _applications[index] = app.copyWith(status: status,
      reviewerNotes: notes ?? app.reviewerNotes, homeVisitDate: homeVisitDate ?? app.homeVisitDate);
    await _storage.saveApplications(_applications);
    _appStreamController.add(List.unmodifiable(_applications));
  }

  void dispose() {
    _appStreamController.close();
  }
}
