import 'package:flutter_test/flutter_test.dart';
import 'package:adoptmatch/core/network/api_client.dart';
import 'package:adoptmatch/core/services/laravel_pet_service.dart';
import '../helpers/fake_dio_adapter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('catalog unwraps Laravel paginator and nearby search sends canonical coordinates', () async {
    final adapter = FakeDioAdapter((options) async {
      if (options.path == '/pets/nearby') {
        expect(options.queryParameters['latitude'], 23.8);
        expect(options.queryParameters['longitude'], 90.4);
        expect(options.queryParameters['radius_km'], 12.0);
      }
      return (200, {'status': 'success', 'data': {'data': [
        {'id': 7, 'name': 'Luna', 'species': 'dog', 'breed': 'Mixed', 'age_months': 12,
         'gender': 'female', 'adoption_status': 'available', 'images': []}]}});
    });
    final service = LaravelPetService(apiClient: ApiClient(baseUrl: 'https://api.example.test/api/v1')
      ..dio.httpClientAdapter = adapter);
    final pets = await service.getPets();
    expect(pets.single.id, '7');
    expect(pets.single.isVaccinated, false);
    expect(pets.single.shelterRating, 0);
    final nearby = await service.getNearbyPets(lat: 23.8, lng: 90.4, radiusKm: 12);
    expect(nearby.single.id, '7');
  });

  test('favorites use explicit server endpoints and swipes do not set favorites', () async {
    final adapter = FakeDioAdapter((options) async {
      if (options.method == 'PUT') {
        expect(options.path, '/pets/7/favorite');
        return (200, {'status': 'success', 'data': {'is_favorite': true}});
      }
      if (options.method == 'DELETE') return (200, {'status': 'success', 'data': {'is_favorite': false}});
      if (options.path.endsWith('/like')) {
        expect(options.data, {'direction': 'like'});
        return (200, {'status': 'success'});
      }
      return (200, {'status': 'success', 'data': {'is_favorite': false}});
    });
    final service = LaravelPetService(apiClient: ApiClient(baseUrl: 'https://api.example.test/api/v1')
      ..dio.httpClientAdapter = adapter);
    expect(await service.setFavorite('7', true), true);
    expect(await service.setFavorite('7', false), false);
    expect(await service.recordSwipe('7', isLike: true), true);
    expect(await service.getFavoriteStatus('7'), false);
  });
}
