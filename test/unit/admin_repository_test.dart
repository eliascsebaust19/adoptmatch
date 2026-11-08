import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:adoptmatch/core/repositories/admin_repository.dart';
import 'package:adoptmatch/core/models/pet_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Map<String, dynamic> ok([Map<String, dynamic>? data]) => {'success': true, if (data != null) 'data': data};

  test('admin reads and writes use bearer-authenticated server state', () async {
    final requests = <http.Request>[];
    var banned = false;
    final client = MockClient((request) async {
      requests.add(request);
      expect(request.headers['Authorization'], 'Bearer admin-token');
      final path = request.url.path;
      if (path.endsWith('/admin/stats')) return http.Response(jsonEncode(ok({
        'pendingShelters': 1, 'activeRescues': 2, 'flaggedListings': 0,
        'totalAdoptions': null, 'totalDonationsBDT': null, 'activeDisputes': null})), 200);
      if (path.endsWith('/admin/users')) return http.Response(jsonEncode({'success': true, 'data': [
        {'id': 'u-1', 'name': 'User', 'email': 'u@example.test', 'role': 'USER',
         'status': banned ? 'Banned' : 'Active', 'permissions': [], 'joinedAt': '2026-01-01T00:00:00Z'}]}), 200);
      if (path.endsWith('/admin/shelters') || path.endsWith('/admin/pets') || path.endsWith('/admin/audit-logs')) {
        return http.Response(jsonEncode({'success': true, 'data': []}), 200);
      }
      if (request.method == 'PATCH' && path.endsWith('/users/u-1/block')) {
        banned = true;
        return http.Response(jsonEncode(ok({'userId': 'u-1', 'status': 'Banned'})), 200);
      }
      return http.Response(jsonEncode({'success': false, 'error': 'unexpected ${request.method} $path'}), 500);
    });
    final repo = AdminRepository()..configureForTesting(client, () async => 'admin-token');
    await repo.refresh();
    expect(repo.getUsers().single.isBanned, false);
    expect(repo.getKPIs()!.totalAdoptions, isNull);
    await repo.blockUser('u-1', reason: 'policy');
    expect(repo.getUsers().single.isBanned, true);
    expect(requests.any((r) => r.method == 'PATCH' && r.url.path.endsWith('/users/u-1/block')), true);
  });

  test('failed admin write does not mutate local state', () async {
    final client = MockClient((request) async {
      if (request.method == 'PATCH') return http.Response('{"success":false,"error":"denied"}', 403);
      if (request.url.path.endsWith('/admin/users')) return http.Response(jsonEncode({'success': true, 'data': [
        {'id': 'u-1', 'name': 'User', 'email': 'u@example.test', 'role': 'USER',
         'status': 'Active', 'joinedAt': '2026-01-01T00:00:00Z'}]}), 200);
      if (request.url.path.endsWith('/admin/stats')) return http.Response(jsonEncode(ok({
        'pendingShelters': 0, 'activeRescues': 0, 'flaggedListings': 0})), 200);
      return http.Response(jsonEncode({'success': true, 'data': []}), 200);
    });
    final repo = AdminRepository()..configureForTesting(client, () async => 'admin-token');
    await repo.refresh();
    await expectLater(repo.blockUser('u-1'), throwsException);
    expect(repo.getUsers().single.isBanned, false);
  });

  test('pet creation returns the server identity only after acknowledgement', () async {
    final client = MockClient((request) async {
      if (request.method == 'POST' && request.url.path.endsWith('/admin/pets')) {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(jsonEncode(ok({'id': 'server-pet-9', 'name': body['name'], 'species': 'Dog',
          'breed': 'Mixed', 'ageDisplay': '1 yr', 'ageMonths': 12, 'gender': 'Male',
          'imageUrl': 'https://cdn.example.test/p.jpg', 'galleryUrls': ['https://cdn.example.test/p.jpg']})), 201);
      }
      if (request.url.path.endsWith('/admin/stats')) return http.Response(jsonEncode(ok({
        'pendingShelters': 0, 'activeRescues': 0, 'flaggedListings': 0})), 200);
      return http.Response(jsonEncode({'success': true, 'data': []}), 200);
    });
    final repo = AdminRepository()..configureForTesting(client, () async => 'admin-token');
    const pet = Pet(id: 'local-draft', name: 'Thunder', species: 'Dog', breed: 'Mixed',
      ageDisplay: '1 yr', ageMonths: 12, gender: 'Male', weightKg: 10, distanceKm: 1, matchScore: 0,
      imageUrl: 'https://cdn.example.test/p.jpg', galleryUrls: ['https://cdn.example.test/p.jpg'],
      shelterName: 'Shelter', shelterPhone: '', shelterAddress: 'Dhaka', story: 'Rescue');
    final saved = await repo.createPetListing(pet);
    expect(saved.id, 'server-pet-9');
    expect(saved.name, 'Thunder');
  });
}
