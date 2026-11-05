import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:adoptmatch/core/services/google_auth_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('GoogleAuthService Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({
        'cached_user_id': 'g-123',
        'cached_user_email': 'test@gmail.com',
        'cached_user_name': 'Test Google User',
        'cached_user_photo': 'https://example.com/photo.jpg',
        'cached_user_role': 'USER',
      });
    });

    test('signOut clears cached user session and auth token safely', () async {
      await GoogleAuthService.signOut();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('auth_token'), isNull);
      expect(prefs.getString('cached_user_id'), isNull);
      expect(prefs.getString('cached_user_email'), isNull);
    });
  });
}

