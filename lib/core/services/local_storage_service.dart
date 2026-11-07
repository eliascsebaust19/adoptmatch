import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/application_model.dart';
import '../models/chat_message_model.dart';

class LocalStorageService {
  static const String _keyApplications = 'adoptmatch_applications';
  static const String _keyDraftPrefix = 'adoptmatch_draft_';
  static const String _keyConversations = 'adoptmatch_conversations';
  static const String _keyMessagesPrefix = 'adoptmatch_msgs_';
  static const String _keyFavorites = 'adoptmatch_favorites';
  static const String _keyQuizCompleted = 'adoptmatch_quiz_completed';
  static const String _keyQuizAnswers = 'adoptmatch_quiz_answers';
  static const String _keyHasSeenOnboarding = 'has_seen_onboarding';

  static final LocalStorageService instance = LocalStorageService._internal();
  LocalStorageService._internal();

  SharedPreferences? _prefs;
  bool _hasSeenOnboarding = false;

  bool get hasSeenOnboarding => _hasSeenOnboarding;

  Future<void> init() async {
    final p = await prefs;
    _hasSeenOnboarding = p.getBool(_keyHasSeenOnboarding) ?? false;
  }

  Future<SharedPreferences> get prefs async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  void resetForTesting() {
    _prefs = null;
  }

  // --- Applications ---
  Future<List<AdoptionApplication>?> loadApplications() async {
    try {
      final p = await prefs;
      final raw = p.getString(_keyApplications);
      if (raw == null || raw.trim().isEmpty) return null;
      final List<dynamic> list = jsonDecode(raw);
      final results = <AdoptionApplication>[];
      for (final item in list) {
        if (item is Map<String, dynamic>) {
          try {
            results.add(AdoptionApplication.fromJson(item));
          } catch (_) {
            // Keep parsing remaining applications
          }
        }
      }
      return results;
    } catch (_) {
      return null;
    }
  }

  Future<void> saveApplications(List<AdoptionApplication> applications) async {
    final p = await prefs;
    final encoded = jsonEncode(applications.map((a) => a.toJson()).toList());
    await p.setString(_keyApplications, encoded);
  }

  // --- Drafts ---
  Future<Map<String, dynamic>?> loadApplicationDraft(String petId) async {
    try {
      final p = await prefs;
      final raw = p.getString('$_keyDraftPrefix$petId');
      if (raw == null) return null;
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  Future<void> saveApplicationDraft(
    String petId,
    Map<String, dynamic> draftData,
  ) async {
    final p = await prefs;
    await p.setString('$_keyDraftPrefix$petId', jsonEncode(draftData));
  }

  Future<void> clearApplicationDraft(String petId) async {
    final p = await prefs;
    await p.remove('$_keyDraftPrefix$petId');
  }

  // --- Conversations & Messages ---
  Future<List<ChatConversation>?> loadConversations() async {
    try {
      final p = await prefs;
      final raw = p.getString(_keyConversations);
      if (raw == null) return null;
      final List<dynamic> list = jsonDecode(raw);
      return list
          .map(
            (item) => ChatConversation.fromJson(item as Map<String, dynamic>),
          )
          .toList();
    } catch (_) {
      return null;
    }
  }

  Future<void> saveConversations(List<ChatConversation> conversations) async {
    final p = await prefs;
    final encoded = jsonEncode(conversations.map((c) => c.toJson()).toList());
    await p.setString(_keyConversations, encoded);
  }

  Future<List<ChatMessage>?> loadMessages(String conversationId) async {
    try {
      final p = await prefs;
      final raw = p.getString('$_keyMessagesPrefix$conversationId');
      if (raw == null) return null;
      final List<dynamic> list = jsonDecode(raw);
      return list
          .map((item) => ChatMessage.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return null;
    }
  }

  Future<void> saveMessages(
    String conversationId,
    List<ChatMessage> messages,
  ) async {
    final p = await prefs;
    final encoded = jsonEncode(messages.map((m) => m.toJson()).toList());
    await p.setString('$_keyMessagesPrefix$conversationId', encoded);
  }

  // --- Favorites ---
  Future<Set<String>> loadFavorites() async {
    try {
      final p = await prefs;
      final list = p.getStringList(_keyFavorites);
      return list != null ? list.toSet() : {};
    } catch (_) {
      return {};
    }
  }

  Future<void> saveFavorites(Set<String> favoriteIds) async {
    final p = await prefs;
    await p.setStringList(_keyFavorites, favoriteIds.toList());
  }

  // --- Compatibility Quiz ---
  Future<bool> loadQuizCompleted() async {
    try {
      final p = await prefs;
      return p.getBool(_keyQuizCompleted) ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<void> saveQuizCompleted(bool completed) async {
    final p = await prefs;
    await p.setBool(_keyQuizCompleted, completed);
  }

  Future<Map<String, dynamic>?> loadQuizAnswers() async {
    try {
      final p = await prefs;
      final raw = p.getString(_keyQuizAnswers);
      if (raw == null) return null;
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  Future<void> saveQuizAnswers(Map<String, dynamic> answers) async {
    final p = await prefs;
    await p.setString(_keyQuizAnswers, jsonEncode(answers));
  }

  Future<void> clearQuiz() async {
    final p = await prefs;
    await p.remove(_keyQuizCompleted);
    await p.remove(_keyQuizAnswers);
  }

  // --- Onboarding ---
  Future<bool> loadHasSeenOnboarding() async {
    try {
      final p = await prefs;
      _hasSeenOnboarding = p.getBool(_keyHasSeenOnboarding) ?? false;
      return _hasSeenOnboarding;
    } catch (_) {
      return false;
    }
  }

  Future<void> saveHasSeenOnboarding(bool value) async {
    _hasSeenOnboarding = value;
    final p = await prefs;
    await p.setBool(_keyHasSeenOnboarding, value);
  }

  /// Wipes all cached user applications, chats, messages, favorites, and quiz data on logout
  Future<void> clearAllUserData() async {
    try {
      final p = await prefs;
      final allKeys = p.getKeys().toList();
      for (final key in allKeys) {
        if (key != _keyHasSeenOnboarding) {
          await p.remove(key);
        }
      }
    } catch (_) {}
  }
}
