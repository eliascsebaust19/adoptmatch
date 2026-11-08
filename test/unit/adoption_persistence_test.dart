import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:adoptmatch/core/models/application_model.dart';
import 'package:adoptmatch/core/repositories/application_repository.dart';
import 'package:adoptmatch/core/services/local_storage_service.dart';
import '../helpers/secure_storage_mock.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Map<String, String> secureData;
  setUp(() async {
    secureData = await installSecureStorageMock();
    SharedPreferences.setMockInitialValues({});
    ApplicationRepository().resetForTesting();
  });

  final app = AdoptionApplication(id: 'AM-1', serverId: '1', petId: '42', petName: 'Luna',
    petBreed: 'Mixed', petImageUrl: '', applicantName: 'Applicant', applicantPhone: '+8801700000000',
    applicantEmail: 'a@example.test', address: 'Dhaka', housingType: 'Apartment',
    dailyHoursAlone: '2', petExperience: 'Experienced', whyAdopt: 'Home',
    submittedAt: DateTime.parse('2026-11-08T00:00:00Z'), nidNumber: '1234567890',
    signatureData: '{"strokes":[]}');

  test('dossiers are stored in protected storage, not ordinary preferences', () async {
    final storage = LocalStorageService.instance;
    await storage.saveApplications([app]);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('adoptmatch_applications'), isNull);
    expect(secureData['adoptmatch_applications'], contains('1234567890'));
    final loaded = await storage.loadApplications();
    expect(loaded!.single.id, 'AM-1');
    expect(loaded.single.serverId, '1');
  });

  test('legacy plaintext dossiers are migrated and removed', () async {
    SharedPreferences.setMockInitialValues({
      'adoptmatch_applications': jsonEncode([app.toJson()]),
    });
    final loaded = await LocalStorageService.instance.loadApplications();
    expect(loaded!.single.id, 'AM-1');
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('adoptmatch_applications'), isNull);
    expect(secureData.containsKey('adoptmatch_applications'), true);
  });

  test('drafts round-trip and logout clears private caches', () async {
    final repo = ApplicationRepository();
    await repo.saveDraft('42', {'name': 'Applicant', 'currentStep': 2});
    expect((await repo.getDraft('42'))!['currentStep'], 2);
    await LocalStorageService.instance.saveApplications([app]);
    await LocalStorageService.instance.clearAllUserData();
    expect(await LocalStorageService.instance.loadApplications(), anyOf(isNull, isEmpty));
    expect(await repo.getDraft('42'), isNull);
  });
}
