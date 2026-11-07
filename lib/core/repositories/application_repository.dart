import 'dart:async';
import '../models/application_model.dart';
import '../services/local_storage_service.dart';

class ApplicationRepository {
  static final ApplicationRepository _instance = ApplicationRepository._internal();
  factory ApplicationRepository() => _instance;
  ApplicationRepository._internal();

  final _storage = LocalStorageService.instance;
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

  Future<List<AdoptionApplication>> getApplications() async {
    if (!_initialized) await _init();
    return List.unmodifiable(_applications);
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
    if (!_initialized) await _init();
    return _applications.any(
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

    final newId = 'AM-APP-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';

    final newApp = AdoptionApplication(
      id: newId,
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

  Future<void> updateApplicationStatus(
    String appId,
    ApplicationStatus status, {
    String? notes,
    DateTime? homeVisitDate,
  }) async {
    if (!_initialized) await _init();
    final index = _applications.indexWhere((a) => a.id == appId);
    if (index != -1) {
      _applications[index] = _applications[index].copyWith(
        status: status,
        reviewerNotes: notes ?? _applications[index].reviewerNotes,
        homeVisitDate: homeVisitDate ?? _applications[index].homeVisitDate,
      );
      await _storage.saveApplications(_applications);
      _appStreamController.add(List.unmodifiable(_applications));
    }
  }

  void dispose() {
    _appStreamController.close();
  }
}
