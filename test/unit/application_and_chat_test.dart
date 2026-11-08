import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:adoptmatch/core/models/application_model.dart';
import 'package:adoptmatch/core/models/chat_message_model.dart';
import 'package:adoptmatch/core/models/pet_model.dart';
import 'package:adoptmatch/core/network/api_client.dart';
import 'package:adoptmatch/core/repositories/application_repository.dart';
import 'package:adoptmatch/core/repositories/chat_repository.dart';
import 'package:adoptmatch/core/services/laravel_pet_service.dart';
import '../helpers/secure_storage_mock.dart';
import '../helpers/fake_dio_adapter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() async { await installSecureStorageMock(); });

  Future<AdoptionApplication> submit(ApplicationRepository repo, {String petId = '42'}) =>
    repo.submitApplication(petId: petId, petName: 'Luna', petBreed: 'Mixed',
      petImageUrl: 'https://cdn.example.test/luna.jpg', applicantName: 'Applicant',
      applicantPhone: '+8801700000000', applicantEmail: 'a@example.test', nidNumber: '1234567890',
      emergencyContactName: 'Contact', emergencyContactPhone: '+8801800000000', address: 'Dhaka',
      housingType: 'Apartment', ownershipStatus: 'Rented', landlordAllowsPets: true,
      yardType: 'Balcony', petLivingSpace: 'Indoor', totalAdults: 2, hasKids: false,
      hasAllergies: false, hasOtherPets: false, dailyHoursAlone: '2-4', primaryCaregiver: 'Self',
      petExperience: 'Experienced', emergencyVetFund: true, monthlyBudget: '5000',
      whyAdopt: 'A safe permanent home.', signatureData: '{"strokes":[[[1,2],[3,4]]]}');

  test('application success requires server reference and syncs paginated history', () async {
    final adapter = FakeDioAdapter((options) async {
      if (options.method == 'GET') return (200, {'status': 'success', 'data': {'data': [
        {'id': 9, 'reference_no': 'AM-APP-9', 'pet_id': 42, 'status': 'under_review',
         'created_at': '2026-11-08T00:00:00Z', 'applicant_data': {'applicantName': 'Applicant'},
         'pet': {'name': 'Luna', 'primary_image_url': 'https://cdn.example.test/luna.jpg'}}]}});
      return (200, {'status': 'success'});
    });
    final api = ApiClient(baseUrl: 'https://api.example.test/api/v1')..dio.httpClientAdapter = adapter;
    final client = MockClient((request) async => http.Response(jsonEncode({
      'status': 'success', 'reference_no': 'AM-APP-9', 'data': {'id': 9}}), 201));
    final repo = ApplicationRepository()..configureForTesting(LaravelPetService(apiClient: api),
      client: client, tokenReader: () async => 'token');
    final app = await submit(repo);
    expect(app.id, 'AM-APP-9'); expect(app.serverId, '9');
    final rows = await repo.getApplications();
    expect(rows.single.status, ApplicationStatus.underReview);
    await repo.updateApplicationStatus('AM-APP-9', ApplicationStatus.approved, notes: 'ok');
    expect(adapter.requests.last.method, 'PATCH');
    expect(adapter.requests.last.path, '/adoption-requests/9/status');
  });

  test('application failure never creates a submitted local record', () async {
    final adapter = FakeDioAdapter((options) async => (200, {'status': 'success', 'data': {'data': []}}));
    final api = ApiClient(baseUrl: 'https://api.example.test/api/v1')..dio.httpClientAdapter = adapter;
    final client = MockClient((request) async => http.Response('{"message":"rejected"}', 422));
    final repo = ApplicationRepository()..configureForTesting(LaravelPetService(apiClient: api),
      client: client, tokenReader: () async => 'token');
    await expectLater(submit(repo), throwsException);
    expect(await repo.getApplications(), isEmpty);
  });

  const serverPet = Pet(id: '42', ownerId: '7', name: 'Luna', species: 'Dog', breed: 'Mixed',
    ageDisplay: '1 yr', ageMonths: 12, gender: 'Female', weightKg: 10, distanceKm: 1, matchScore: 0,
    imageUrl: 'https://cdn.example.test/luna.jpg', shelterName: 'Shelter', shelterPhone: '',
    shelterAddress: 'Dhaka', story: 'Rescue');

  test('chat marks sent only after acknowledgement and keeps failed drafts visible', () async {
    var failSend = false;
    final client = MockClient((request) async {
      expect(request.headers['Authorization'], 'Bearer token');
      if (request.method == 'POST' && request.url.path.endsWith('/messages')) {
        if (failSend) return http.Response('{"message":"offline"}', 503);
        return http.Response(jsonEncode({'status': 'success', 'data': {'id': 100}}), 201);
      }
      if (request.url.path.endsWith('/messages/conversations')) return http.Response(jsonEncode({'data': [
        {'other_user': {'id': 7, 'name': 'Shelter'}, 'pet': {'id': 42, 'name': 'Luna'},
         'last_message': 'Hello', 'last_message_time': '2026-11-08T00:00:00Z', 'unread_count': 0}]}), 200);
      if (request.url.path.endsWith('/messages/7')) return http.Response(jsonEncode({'data': []}), 200);
      return http.Response('{}', 404);
    });
    final repo = ChatRepository()..configureForTesting(client: client, tokenReader: () async => 'token', userId: '1');
    final conv = await repo.getOrCreateConversationForPet(serverPet);
    final sent = await repo.sendMessage(conv.id, 'Hello');
    expect(sent.deliveryStatus, MessageDeliveryStatus.sent); expect(sent.id, '100');
    failSend = true;
    await expectLater(repo.sendMessage(conv.id, 'Retry me'), throwsException);
    final messages = await repo.getMessages(conv.id);
    expect(messages.last.text, 'Retry me');
    expect(messages.last.deliveryStatus, MessageDeliveryStatus.failed);
    expect(messages.any((m) => m.senderName == 'Shelter' && m.text.contains('keyword')), false);
  });

  test('unpublished demo listings cannot open a fake server conversation', () async {
    final repo = ChatRepository()..configureForTesting(client: MockClient((_) async => http.Response('{}', 500)),
      tokenReader: () async => 'token');
    await expectLater(repo.getOrCreateConversationForPet(serverPet.copyWith(id: 'p1')), throwsException);
  });
}
