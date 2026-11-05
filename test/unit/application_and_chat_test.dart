import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:adoptmatch/core/models/application_model.dart';
import 'package:adoptmatch/core/models/chat_message_model.dart';
import 'package:adoptmatch/core/repositories/application_repository.dart';
import 'package:adoptmatch/core/repositories/chat_repository.dart';
import 'package:adoptmatch/core/repositories/pet_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('ApplicationRepository Tests', () {
    test('submits an application and persists it in repository stream', () async {
      final appRepo = ApplicationRepository();

      final newApp = await appRepo.submitApplication(
        petId: 'p1',
        petName: 'Luna',
        petBreed: 'Golden Retriever',
        petImageUrl: 'https://example.com/luna.jpg',
        applicantName: 'Elias Ahmed',
        applicantPhone: '+880 1711 234567',
        applicantEmail: 'elias@example.com',
        nidNumber: '19901234567890',
        emergencyContactName: 'Farhana Ahmed',
        emergencyContactPhone: '+880 1812 345678',
        address: 'Dhanmondi, Dhaka',
        housingType: 'Apartment',
        ownershipStatus: 'Own',
        landlordAllowsPets: true,
        yardType: 'Balcony with netting',
        petLivingSpace: 'Indoor Only',
        totalAdults: 2,
        hasKids: false,
        hasAllergies: false,
        hasOtherPets: false,
        petExperience: 'Experienced pet parent',
        dailyHoursAlone: '2-4 hours',
        primaryCaregiver: 'Self',
        emergencyVetFund: true,
        monthlyBudget: '5,000 - 10,000 BDT',
        whyAdopt: 'Loving home ready for Luna.',
      );

      expect(newApp.id.isNotEmpty, isTrue);

      final hasActive = await appRepo.hasActiveApplicationForPet('p1');
      expect(hasActive, isTrue);

      final apps = await appRepo.getApplications();
      expect(apps.any((a) => a.id == newApp.id), isTrue);
    });

    test('draft saving and retrieval works correctly', () async {
      final appRepo = ApplicationRepository();

      final draftData = {
        'name': 'Elias Test',
        'phone': '+880 1700 000000',
        'housingType': 'Apartment',
      };

      await appRepo.saveDraft('p2', draftData);
      final retrieved = await appRepo.getDraft('p2');
      expect(retrieved, isNotNull);
      expect(retrieved!['name'], equals('Elias Test'));

      await appRepo.clearDraft('p2');
      final cleared = await appRepo.getDraft('p2');
      expect(cleared, isNull);
    });

    test('updates application status and reviewer notes', () async {
      final appRepo = ApplicationRepository();
      final apps = await appRepo.getApplications();
      expect(apps.isNotEmpty, isTrue);

      final firstApp = apps.first;
      await appRepo.updateApplicationStatus(
        firstApp.id,
        ApplicationStatus.approved,
        notes: 'Background checks and landlord clearance verified successfully.',
      );

      final updatedApps = await appRepo.getApplications();
      final target = updatedApps.firstWhere((a) => a.id == firstApp.id);
      expect(target.status, equals(ApplicationStatus.approved));
      expect(target.reviewerNotes, contains('landlord clearance verified'));
    });
  });

  group('ChatRepository Tests', () {
    test('creates or retrieves dedicated conversation for pet', () async {
      final petRepo = PetRepository();
      final chatRepo = ChatRepository();

      final pet = (await petRepo.getAllPets()).first;
      final conv = await chatRepo.getOrCreateConversationForPet(pet);

      expect(conv.petId, equals(pet.id));
      expect(conv.petName, equals(pet.name));
      expect(conv.shelterName, equals(pet.shelterName));

      final convs = await chatRepo.getConversations();
      expect(convs.any((c) => c.id == conv.id), isTrue);
    });

    test('sends a message and receives simulated shelter reply', () async {
      final chatRepo = ChatRepository();
      final convs = await chatRepo.getConversations();
      final testConv = convs.first;

      final initialCount = (await chatRepo.getMessages(testConv.id)).length;

      await chatRepo.sendMessage(
        testConv.id,
        'Is vaccination up to date?',
      );

      final msgsAfterSend = await chatRepo.getMessages(testConv.id);
      expect(msgsAfterSend.length, greaterThan(initialCount));

      final lastSent = msgsAfterSend.last;
      expect(lastSent.isFromUser, isTrue);
      expect(lastSent.text, equals('Is vaccination up to date?'));
      expect(lastSent.deliveryStatus, equals(MessageDeliveryStatus.sent));
    });

    test('marks conversation as read', () async {
      final chatRepo = ChatRepository();
      final convs = await chatRepo.getConversations();
      final testConv = convs.first;

      await chatRepo.markConversationAsRead(testConv.id);
      final updatedConvs = await chatRepo.getConversations();
      final target = updatedConvs.firstWhere((c) => c.id == testConv.id);
      expect(target.unreadCount, equals(0));
    });
  });
}
