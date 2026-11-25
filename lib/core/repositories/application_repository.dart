import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/application_model.dart';
import '../services/local_storage_service.dart';
import '../storage/secure_storage_service.dart';
import '../network/api_client.dart';
import '../services/api_pet_service.dart';

class ApplicationRepository {
  static final ApplicationRepository _instance = ApplicationRepository._internal();
  factory ApplicationRepository() => _instance;
  ApplicationRepository._internal();

  final _storage = LocalStorageService.instance;
  ApiPetService _remote = ApiPetService();
  http.Client _client = http.Client();
  Future<String?> Function() _readToken = SecureStorageService.instance.getAuthToken;
  bool _isDemoToken(String? token) => token != null && token.startsWith('demo_');

  void configureForTesting(ApiPetService remote, {http.Client? client,
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
    if (_isDemoToken(token)) {
      try {
        final remoteRows = await _remote.getMyAdoptionRequests(received: received);
        if (remoteRows.isNotEmpty) {
          _applications = remoteRows;
          await _storage.saveApplications(_applications);
          _appStreamController.add(List.unmodifiable(_applications));
          return List.unmodifiable(_applications);
        }
      } catch (e) {
        debugPrint('[ApplicationRepository] Demo mode remote notice: $e');
      }
      if (_applications.isEmpty) {
        _applications = _buildDemoPendingApplications();
        await _storage.saveApplications(_applications);
      }
      _appStreamController.add(List.unmodifiable(_applications));
      return List.unmodifiable(_applications);
    }
    _applications = await _remote.getMyAdoptionRequests(received: received);
    await _storage.saveApplications(_applications);
    _appStreamController.add(List.unmodifiable(_applications));
    return List.unmodifiable(_applications);
  }

  List<AdoptionApplication> _buildDemoPendingApplications() {
    final now = DateTime.now();
    return [
      AdoptionApplication(
        id: 'AM-DEMO-101',
        serverId: 'demo-app-101',
        petId: 'p1',
        petName: 'Buddy',
        petBreed: 'Golden Retriever',
        petImageUrl:
            'https://images.unsplash.com/photo-1552053831-71594a27632d?w=600&auto=format&fit=crop',
        applicantName: 'Nadia Rahman',
        applicantPhone: '+880 1712-445566',
        applicantEmail: 'nadia.rahman@demo.adoptmatch.app',
        nidNumber: '1996-4410-8821-0012',
        emergencyContactName: 'Tariq Rahman',
        emergencyContactPhone: '+880 1811-223344',
        address: 'House 18, Road 7, Dhanmondi, Dhaka',
        housingType: 'Independent House',
        ownershipStatus: 'Owned',
        landlordAllowsPets: true,
        yardType: 'Private Fenced Yard',
        petLivingSpace: 'Indoor with Yard Access',
        totalAdults: 3,
        hasKids: true,
        childrenAges: '8 yrs',
        hasAllergies: false,
        hasOtherPets: false,
        dailyHoursAlone: '2-3 hours',
        primaryCaregiver: 'Nadia Rahman',
        petExperience: 'Raised a Golden Retriever for 6 years',
        emergencyVetFund: true,
        monthlyBudget: '8000',
        whyAdopt: 'Looking for an affectionate family companion for our home.',
        status: ApplicationStatus.submitted,
        submittedAt: now.subtract(const Duration(hours: 3)),
        reviewerNotes: 'Pending initial admin document verification.',
        isESigned: true,
        signatureData: '{"strokes":[[[10,12],[48,18]]]}',
      ),
      AdoptionApplication(
        id: 'AM-DEMO-102',
        serverId: 'demo-app-102',
        petId: 'p2',
        petName: 'Milo',
        petBreed: 'British Shorthair',
        petImageUrl:
            'https://images.unsplash.com/photo-1514888286974-6c03e2ca1dba?w=600&auto=format&fit=crop',
        applicantName: 'Farhan Ahmed',
        applicantPhone: '+880 1911-778899',
        applicantEmail: 'farhan.ahmed@demo.adoptmatch.app',
        nidNumber: '1994-8821-5530-0041',
        emergencyContactName: 'Sadia Ahmed',
        emergencyContactPhone: '+880 1715-667788',
        address: 'Flat 5B, Banani Road 11, Dhaka',
        housingType: 'Apartment',
        ownershipStatus: 'Rented',
        landlordAllowsPets: true,
        landlordContact: '+880 1700-998877',
        yardType: 'Screened Balcony',
        petLivingSpace: 'Indoor Only',
        totalAdults: 2,
        hasKids: false,
        hasAllergies: false,
        hasOtherPets: true,
        otherPetsDetails: '1 neutered indoor tabby cat',
        dailyHoursAlone: '3-4 hours',
        primaryCaregiver: 'Farhan Ahmed',
        petExperience: 'Current indoor cat parent (3 years)',
        emergencyVetFund: true,
        monthlyBudget: '5500',
        whyAdopt: 'Want a gentle indoor companion for our cat.',
        status: ApplicationStatus.underReview,
        submittedAt: now.subtract(const Duration(days: 1, hours: 2)),
        reviewerNotes: 'Landlord NOC attached; awaiting final admin approval.',
        isESigned: true,
        signatureData: '{"strokes":[[[14,20],[52,16]]]}',
      ),
      AdoptionApplication(
        id: 'AM-DEMO-103',
        serverId: 'demo-app-103',
        petId: 'p3',
        petName: 'Simba',
        petBreed: 'Persian Cat',
        petImageUrl:
            'https://images.unsplash.com/photo-1573865526739-10659fec78a5?w=600&auto=format&fit=crop',
        applicantName: 'Tasnim Chowdhury',
        applicantPhone: '+880 1614-332211',
        applicantEmail: 'tasnim.c@demo.adoptmatch.app',
        nidNumber: '1998-3301-7712-0087',
        emergencyContactName: 'Mahmud Chowdhury',
        emergencyContactPhone: '+880 1819-445511',
        address: 'Nasirabad Housing Society, Chattogram',
        housingType: 'Apartment',
        ownershipStatus: 'Owned',
        landlordAllowsPets: true,
        yardType: 'Balcony',
        petLivingSpace: 'Indoor Only',
        totalAdults: 2,
        hasKids: false,
        hasAllergies: false,
        hasOtherPets: false,
        dailyHoursAlone: '1-2 hours',
        primaryCaregiver: 'Tasnim Chowdhury',
        petExperience: 'First-time adopter (completed care quiz)',
        emergencyVetFund: true,
        monthlyBudget: '6000',
        whyAdopt: 'Working from home and ready to adopt a calm indoor cat.',
        status: ApplicationStatus.submitted,
        submittedAt: now.subtract(const Duration(minutes: 45)),
        reviewerNotes: 'Newly submitted adoption application awaiting review.',
        isESigned: true,
        signatureData: '{"strokes":[[[8,15],[42,22]]]}',
      ),
      AdoptionApplication(
        id: 'AM-DEMO-104',
        serverId: 'demo-app-104',
        petId: 'p4',
        petName: 'Cookie',
        petBreed: 'Deshi Rescue Pup',
        petImageUrl:
            'https://images.unsplash.com/photo-1587300003388-59208cc962cb?w=600&auto=format&fit=crop',
        applicantName: 'Rafiul Islam',
        applicantPhone: '+880 1511-909080',
        applicantEmail: 'rafiul.islam@demo.adoptmatch.app',
        nidNumber: '1993-7120-9914-0023',
        emergencyContactName: 'Kamrul Islam',
        emergencyContactPhone: '+880 1718-303020',
        address: 'Sector 4, Uttara, Dhaka',
        housingType: 'Duplex',
        ownershipStatus: 'Owned',
        landlordAllowsPets: true,
        yardType: 'Private Fenced Yard',
        petLivingSpace: 'Indoor & Outdoor',
        totalAdults: 4,
        hasKids: true,
        childrenAges: '12 yrs',
        hasAllergies: false,
        hasOtherPets: false,
        dailyHoursAlone: '2 hours',
        primaryCaregiver: 'Rafiul Islam & Family',
        petExperience: 'Adopted rescue dogs before',
        emergencyVetFund: true,
        monthlyBudget: '7000',
        whyAdopt: 'Home visit scheduled to introduce Cookie to the family.',
        status: ApplicationStatus.homeVisitScheduled,
        submittedAt: now.subtract(const Duration(days: 2)),
        homeVisitDate: now.add(const Duration(days: 1)),
        reviewerNotes: 'Home visit assigned for tomorrow at 4:00 PM.',
        isESigned: true,
        signatureData: '{"strokes":[[[12,10],[55,24]]]}',
      ),
    ];
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
    final token = await _readToken();
    final isDemoRecord =
        (app.serverId?.startsWith('demo-') ?? false) && _isDemoToken(token);
    if (!isDemoRecord) {
      await _remote.updateAdoptionStatus(app.serverId!, status, notes: notes, homeVisitDate: homeVisitDate);
    }
    _applications[index] = app.copyWith(status: status,
      reviewerNotes: notes ?? app.reviewerNotes, homeVisitDate: homeVisitDate ?? app.homeVisitDate);
    await _storage.saveApplications(_applications);
    _appStreamController.add(List.unmodifiable(_applications));
  }

  void dispose() {
    _appStreamController.close();
  }
}
