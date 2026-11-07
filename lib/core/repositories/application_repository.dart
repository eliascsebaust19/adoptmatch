import 'dart:async';
import '../models/application_model.dart';
import '../services/local_storage_service.dart';

class ApplicationRepository {
  static final ApplicationRepository _instance = ApplicationRepository._internal();
  factory ApplicationRepository() => _instance;
  ApplicationRepository._internal() {
    _init();
  }

  final _storage = LocalStorageService.instance;
  final _appStreamController = StreamController<List<AdoptionApplication>>.broadcast();
  Stream<List<AdoptionApplication>> get applicationsStream => _appStreamController.stream;

  List<AdoptionApplication> _applications = [];
  bool _initialized = false;

  final List<AdoptionApplication> _defaultApplications = [
    AdoptionApplication(
      id: 'AM-APP-89214',
      petId: 'p11',
      petName: 'Max',
      petBreed: 'Golden Retriever',
      petImageUrl: 'https://3kht7mdtcvdag9ff.private.blob.vercel-storage.com/pets/pet_1.jpg',
      applicantName: 'Elias Ahmed',
      applicantPhone: '+880 1711 234567',
      applicantEmail: 'elias3224@gmail.com',
      nidNumber: '1995-2692-4581-0023',
      emergencyContactName: 'Farhana Ahmed (Spouse)',
      emergencyContactPhone: '+880 1812 345678',
      address: 'House 42, Road 11, Banani, Dhaka-1213',
      housingType: 'Independent House',
      ownershipStatus: 'Owned',
      landlordAllowsPets: true,
      yardType: 'Private Fenced Yard',
      petLivingSpace: 'Indoor with Yard Access',
      totalAdults: 3,
      hasKids: true,
      childrenAges: '6 & 9 years old',
      hasAllergies: false,
      hasOtherPets: false,
      dailyHoursAlone: '2-4 hours',
      primaryCaregiver: 'Applicant & Family',
      petExperience: 'Experienced pet parent (Owned Labradors for 8 years)',
      emergencyVetFund: true,
      monthlyBudget: '5,000 - 10,000 BDT',
      whyAdopt: 'We have a spacious garden and 2 children who adore dogs. We are committed to lifelong care, regular vet visits, and daily park walks.',
      status: ApplicationStatus.homeVisitScheduled,
      submittedAt: DateTime.now().subtract(const Duration(days: 3)),
      reviewerNotes: 'Verification call passed. Virtual home tour scheduled for Sunday 4:00 PM with Shelter Officer Tanvir.',
      homeVisitDate: DateTime.now().add(const Duration(days: 2)),
      isESigned: true,
    ),
    AdoptionApplication(
      id: 'AM-APP-76342',
      petId: 'p2',
      petName: 'Mochi',
      petBreed: 'Calico Cat',
      petImageUrl: 'https://3kht7mdtcvdag9ff.private.blob.vercel-storage.com/pets/pet_4.jpg',
      applicantName: 'Elias Ahmed',
      applicantPhone: '+880 1711 234567',
      applicantEmail: 'elias3224@gmail.com',
      nidNumber: '1995-2692-4581-0023',
      emergencyContactName: 'Farhana Ahmed (Spouse)',
      emergencyContactPhone: '+880 1812 345678',
      address: 'House 42, Road 11, Banani, Dhaka-1213',
      housingType: 'Apartment',
      ownershipStatus: 'Owned',
      landlordAllowsPets: true,
      yardType: 'Balcony with Cat Netting',
      petLivingSpace: 'Indoor Only',
      totalAdults: 2,
      hasKids: false,
      hasAllergies: false,
      hasOtherPets: false,
      dailyHoursAlone: '4-6 hours',
      primaryCaregiver: 'Applicant',
      petExperience: 'Experienced pet parent',
      emergencyVetFund: true,
      monthlyBudget: '3,000 - 5,000 BDT',
      whyAdopt: 'Looking for a calm, affectionate indoor companion to join our quiet home.',
      status: ApplicationStatus.fosterTrial,
      submittedAt: DateTime.now().subtract(const Duration(days: 10)),
      reviewerNotes: 'Day 7 of 14-day trial foster. Adopter reports seamless transition and good appetite.',
      isESigned: true,
    ),
  ];

  Future<void> _init() async {
    if (_initialized) return;
    try {
      final saved = await _storage.loadApplications();
      if (saved != null && saved.isNotEmpty) {
        _applications = saved;
      } else if (_applications.isEmpty) {
        _applications = List.from(_defaultApplications);
      }
    } catch (_) {
      if (_applications.isEmpty) {
        _applications = List.from(_defaultApplications);
      }
    } finally {
      _initialized = true;
      _appStreamController.add(List.unmodifiable(_applications));
    }
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
