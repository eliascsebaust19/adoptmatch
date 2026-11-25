import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

import 'local_ai_fallback_service.dart';

// ── Gemini AI Companion Service ──────────────────────────────────────────────

/// Primary conversational AI assistant backed by Google Gemini, falling back
/// to [AiAssistantService] when no API key is present or remote quotas fail.
class GeminiAiService {
  static const String defaultApiKey = String.fromEnvironment(
    'GEMINI_API_KEY',
    defaultValue: '',
  );

  static const String _systemInstructionText = '''
You are AdoptMatch AI, a friendly, intelligent, and natural conversational AI assistant for the AdoptMatch pet adoption platform in Bangladesh.

🌟 Conversational Style:
- Talk like a real, helpful, and empathetic AI companion—NEVER repeat robotic scripted templates.
- Support natural multi-turn conversations in English, Bengali (বাংলা), and Banglish (e.g., "kmn acho", "amar ekta beral dorkar"). Always reply in the same language and tone the user uses.
- Casual greetings, small talk, and pleasantries (e.g., "kmn acho", "hello", "hi", "good morning", "thank you") should receive warm, natural replies that invite pet-related conversation.
- Use friendly pet emojis (🐾, 🐶, 🐱, 🐠, 🐢) naturally.

🛡️ Strict Boundary Guardrails (PETS ONLY):
- Your domain is strictly limited to pets, animal welfare, and adoption:
  * Dog, cat, bird, rabbit, turtle, gecko, and aquatic breeds/species.
  * Pet care, nutrition, behavior, training, and housing requirements (e.g., hours alone, apartment vs yard).
  * Vaccination schedules and general health guidance.
  * Adoption protocols and using the AdoptMatch app.
- For emergency or severe veterinary symptoms (e.g. poisoning, unconsciousness, severe pain), advise immediate visit to the nearest 24/7 veterinary clinic.

🚫 Out-of-Scope Protection (Non-Pet Topics):
- If the user asks about unrelated non-pet topics (such as politics, programming/coding, sports, cricket, movies, general math, stock markets, or homework), do NOT answer the unrelated query.
- Politely decline with natural warmth and steer back to pets:
  * In Bangla/Banglish: "আমি শুধু পোষা প্রাণী ও অ্যাডপশন সংক্রান্ত বিষয়ে সাহায্য করতে পারি! 🐾 আপনার কি কুকুর, বিড়াল বা অন্য কোনো পোষা প্রাণীর যত্ন অথবা AdoptMatch-এ অ্যাডপশন নিয়ে কোনো প্রশ্ন আছে?"
  * In English: "I'd love to chat, but my expertise is focused purely on pets and adoption! 🐾 Feel free to ask me anything about pet care, breeds, vaccines, or adopting on AdoptMatch!"
''';

  static const List<String> _preferredModels = [
    'gemini-3.1-flash-lite',
    'gemini-3.8-flash',
    'gemini-flash-latest',
  ];

  GenerativeModel? _model;
  ChatSession? _chat;
  final String apiKey;
  String _activeModelName = 'gemini-3.1-flash-lite';
  bool _isInitialized = false;
  bool _remoteDisabledForSession = false;

  bool get isRemoteEnabled => _isInitialized && !_remoteDisabledForSession;

  GeminiAiService({String? apiKey})
    : apiKey = (apiKey != null && apiKey.isNotEmpty) ? apiKey : defaultApiKey {
    _initBestModel();
  }

  void _initBestModel() {
    if (apiKey.trim().isEmpty) {
      _isInitialized = false;
      debugPrint(
        '[GeminiAiService] GEMINI_API_KEY not provided; using local AdoptMatch AI assistant.',
      );
      return;
    }
    for (final modelName in _preferredModels) {
      try {
        _model = GenerativeModel(
          model: modelName,
          apiKey: apiKey,
          systemInstruction: Content.system(_systemInstructionText),
        );
        _chat = _model!.startChat();
        _activeModelName = modelName;
        _isInitialized = true;
        return;
      } catch (e) {
        debugPrint('[GeminiAiService] Could not init $modelName: $e');
      }
    }
  }

  bool _isAuthOrPermissionError(Object error) {
    final msg = error.toString().toLowerCase();
    return msg.contains('permission denied') ||
        msg.contains('api key') ||
        msg.contains('api_key_invalid') ||
        msg.contains('403') ||
        msg.contains('401') ||
        msg.contains('unauthorized');
  }

  void resetChat() {
    if (_isInitialized && _model != null) {
      try {
        _chat = _model!.startChat();
      } catch (_) {}
    }
  }

  Future<String> sendMessage(String userPrompt) async {
    // 1. Try primary chat session only when a key is configured and not permission-blocked
    if (_isInitialized && !_remoteDisabledForSession && _chat != null) {
      try {
        final response = await _chat!
            .sendMessage(Content.text(userPrompt))
            .timeout(const Duration(seconds: 8));

        if (response.text != null && response.text!.trim().isNotEmpty) {
          return response.text!.trim();
        }
      } catch (e) {
        debugPrint(
          '[GeminiAiService] Active model ($_activeModelName) error: $e',
        );

        if (_isAuthOrPermissionError(e)) {
          _remoteDisabledForSession = true;
          debugPrint(
            '[GeminiAiService] Remote Gemini disabled for this session due to API key/permission error. '
            'Pass --dart-define=GEMINI_API_KEY=YOUR_KEY to enable live Gemini.',
          );
          final fallbackResponse = await AiAssistantService().getResponse(
            userPrompt,
          );
          return fallbackResponse.text;
        }

        // Reset chat session so subsequent calls don't get stuck in broken state
        _chat = _model?.startChat();

        // Try remaining models as fallbacks (e.g. if a specific model had transient demand)
        for (final fallbackName in _preferredModels) {
          if (fallbackName == _activeModelName) continue;
          try {
            final fallbackModel = GenerativeModel(
              model: fallbackName,
              apiKey: apiKey,
              systemInstruction: Content.system(_systemInstructionText),
            );
            final fallbackResponse = await fallbackModel
                .generateContent([Content.text(userPrompt)])
                .timeout(const Duration(seconds: 5));

            if (fallbackResponse.text != null &&
                fallbackResponse.text!.trim().isNotEmpty) {
              // Switch to working model
              _model = fallbackModel;
              _chat = _model!.startChat();
              _activeModelName = fallbackName;
              return fallbackResponse.text!.trim();
            }
          } catch (fbErr) {
            debugPrint(
              '[GeminiAiService] Fallback to $fallbackName failed: $fbErr',
            );
            if (_isAuthOrPermissionError(fbErr)) {
              _remoteDisabledForSession = true;
              break;
            }
          }
        }
      }
    }

    // 2. Intelligent local offline conversational engine if network/key unavailable
    final fallbackResponse = await AiAssistantService().getResponse(userPrompt);
    return fallbackResponse.text;
  }
}
