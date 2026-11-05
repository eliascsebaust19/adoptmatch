import 'package:flutter_test/flutter_test.dart';
import 'package:adoptmatch/core/services/gemini_ai_service.dart';
import 'package:adoptmatch/core/localization/app_locale.dart';

void main() {
  group('GeminiAiService & Localization Unit Tests', () {
    test('Gemini API real conversational responses', () async {
      final service = GeminiAiService();

      // Test 1: Casual greeting in Banglish
      final reply1 = await service.sendMessage('kmn acho');
      expect(reply1.isNotEmpty, isTrue);

      // Test 2: Follow-up lifestyle answer
      final reply2 = await service.sendMessage('3 hours');
      expect(reply2.isNotEmpty, isTrue);
    }, timeout: const Timeout(Duration(seconds: 90)));

    test('GeminiAiService responds gracefully to pet care query via fallback or API', () async {
      final service = GeminiAiService();
      final reply = await service.sendMessage('Best pets for apartment living in Dhaka');
      expect(reply, isNotEmpty);
      expect(reply.length, greaterThan(10));
    }, timeout: const Timeout(Duration(seconds: 90)));

    test('GeminiAiService triggers out-of-scope protection for non-pet queries', () async {
      final service = GeminiAiService();
      final replyEn = await service.sendMessage('Tell me about election politics and flutter coding');
      expect(replyEn.toLowerCase().contains('pets') || replyEn.toLowerCase().contains('adoptmatch'), isTrue);

      final replyBn = await service.sendMessage('রাজনীতি ও ফুটবল নিয়ে কিছু বলো');
      expect(replyBn.contains('পোষা প্রাণী') || replyBn.contains('AdoptMatch'), isTrue);
    }, timeout: const Timeout(Duration(seconds: 90)));

    test('AppLocale and appLocaleNotifier sync properly', () {
      appLocaleNotifier.value = AppLocale.bengali;
      expect(appLocaleNotifier.value.languageCode, equals('bn'));

      appLocaleNotifier.value = AppLocale.english;
      expect(appLocaleNotifier.value.languageCode, equals('en'));
    });
  });
}
