import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:adoptmatch/core/models/application_model.dart';
import 'package:adoptmatch/core/repositories/application_repository.dart';
import 'package:adoptmatch/core/services/local_storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    LocalStorageService.instance.resetForTesting();
    ApplicationRepository().resetForTesting();
    SharedPreferences.setMockInitialValues({});
  });

  group('Adoption Application Persistence & Drafts', () {
    test('Submitting an application persists and is retrievable from local storage', () async {
      final repo = ApplicationRepository();
      final storage = LocalStorageService.instance;

      final initialApps = await repo.getApplications();
      expect(initialApps.isEmpty, isTrue);

      final newApp = await repo.submitApplication(
        petId: 'p23',
        petName: 'Mimi',
        petBreed: 'Domestic Shorthair',
        petImageUrl: 'https://images.unsplash.com/photo-1514888286974-6c03e2ca1dba',
        applicantName: 'Elias Ahmed',
        applicantPhone: '+880 1711 234567',
        applicantEmail: 'elias3224@gmail.com',
        nidNumber: '1995-2692-4581-0023',
        emergencyContactName: 'Farhana Ahmed',
        emergencyContactPhone: '+880 1812 345678',
        address: 'House 42, Road 11, Banani, Dhaka-1213',
        housingType: 'Apartment',
        ownershipStatus: 'Owned',
        landlordAllowsPets: true,
        yardType: 'Balcony with Safety Netting',
        petLivingSpace: 'Indoor Only',
        totalAdults: 2,
        hasKids: false,
        hasAllergies: false,
        hasOtherPets: false,
        dailyHoursAlone: '2-4 hours',
        primaryCaregiver: 'Self & Family',
        petExperience: 'Experienced pet parent',
        emergencyVetFund: true,
        monthlyBudget: '5,000 - 10,000 BDT',
        whyAdopt: 'We want to provide a loving home for Mimi.',
      );

      expect(newApp.petName, 'Mimi');
      expect(newApp.petId, 'p23');

      // Verify in-memory repository has it
      final inMemory = await repo.getApplications();
      expect(inMemory.first.id, newApp.id);
      expect(inMemory.first.petName, 'Mimi');

      // Verify direct storage loading deserializes without errors
      final loadedFromStorage = await storage.loadApplications();
      expect(loadedFromStorage, isNotNull);
      expect(loadedFromStorage!.any((a) => a.id == newApp.id), isTrue);
      expect(loadedFromStorage.first.petName, 'Mimi');
    });

    test('Draft saving and loading retains all housing, yard, and progress fields', () async {
      final repo = ApplicationRepository();

      final fullDraft = {
        'name': 'Elias Ahmed',
        'phone': '+880 1711 234567',
        'email': 'elias3224@gmail.com',
        'nid': '1995-2692-4581-0023',
        'emergencyName': 'Farhana Ahmed',
        'emergencyPhone': '+880 1812 345678',
        'address': 'Banani, Dhaka',
        'housingType': 'Apartment',
        'ownershipStatus': 'Owned',
        'landlordAllowsPets': true,
        'yardType': 'Balcony with Safety Netting',
        'petLivingSpace': 'Indoor Only',
        'totalAdults': 3,
        'hasKids': true,
        'childrenAges': '5 & 8',
        'hasAllergies': false,
        'hasOtherPets': true,
        'otherPetsDetails': 'One senior cat',
        'dailyHoursAlone': '2-4 hours',
        'primaryCaregiver': 'Whole Family',
        'petExperience': '10 years with rescue cats',
        'emergencyVetFund': true,
        'monthlyBudget': '5,000 - 10,000 BDT',
        'whyAdopt': 'A companion for our current cat.',
        'currentStep': 2,
        'declarationAgreed': true,
        'hasSignature': true,
        'signatureData': 'SIG_BASE64_DATA',
        'savedAt': DateTime.now().toIso8601String(),
      };

      await repo.saveDraft('p23', fullDraft);

      final retrieved = await repo.getDraft('p23');
      expect(retrieved, isNotNull);
      expect(retrieved!['yardType'], 'Balcony with Safety Netting');
      expect(retrieved['petLivingSpace'], 'Indoor Only');
      expect(retrieved['currentStep'], 2);
      expect(retrieved['hasOtherPets'], isTrue);
      expect(retrieved['otherPetsDetails'], 'One senior cat');

      // Clear draft works
      await repo.clearDraft('p23');
      final cleared = await repo.getDraft('p23');
      expect(cleared, isNull);
    });

    test('AdoptionApplication.fromJson handles null/partial data without throwing', () {
      final minimalJson = {
        'id': 'AM-APP-TEST',
        'petId': 'p99',
      };

      final app = AdoptionApplication.fromJson(minimalJson);
      expect(app.id, 'AM-APP-TEST');
      expect(app.petId, 'p99');
      expect(app.petName, 'Adoptable Pet');
      expect(app.status, ApplicationStatus.submitted);
      expect(app.housingType, 'Apartment');
      expect(app.yardType, 'Private Fenced Yard');
    });
  });
}

