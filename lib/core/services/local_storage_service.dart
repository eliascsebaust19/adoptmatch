import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
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
  static const _privateIndexKey = 'adoptmatch_private_key_index';
  Set<String> _privateKeys = {};

  Future<String?> _readPrivate(String key) async {
    try {
      final value = await _secureStore.read(key: key);
      if (value != null) { _privateKeys.add(key); return value; }
    } catch (_) {}
    final p = await prefs;
    final legacy = p.getString(key);
    if (legacy != null) { await _writePrivate(key, legacy); return legacy; }
    return null;
  }
  Future<void> _writePrivate(String key, String value) async {
    await _secureStore.write(key: key, value: value);
    _privateKeys.add(key);
    await _secureStore.write(key: _privateIndexKey, value: jsonEncode(_privateKeys.toList()));
    final p = await prefs;
    await p.remove(key);
  }
  Future<void> _deletePrivate(String key) async {
    await _secureStore.delete(key: key);
    _privateKeys.remove(key);
    await _secureStore.write(key: _privateIndexKey, value: jsonEncode(_privateKeys.toList()));
    final p = await prefs;
    await p.remove(key);
  }


  /// Adoption dossiers contain NID numbers, addresses and signatures, so they
  /// live in hardware-backed storage rather than ordinary preferences.
  final FlutterSecureStorage _secureStore = const FlutterSecureStorage(
    aOptions: AndroidOptions(resetOnError: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  bool get hasSeenOnboarding => _hasSeenOnboarding;

  Future<void> init() async {
    try {
      final index = await _secureStore.read(key: _privateIndexKey);
      if (index != null) _privateKeys = Set<String>.from(jsonDecode(index) as List);
    } catch (_) {}
    final p = await prefs;
    _hasSeenOnboarding = p.getBool(_keyHasSeenOnboarding) ?? false;
  }

  Future<SharedPreferences> get prefs async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  void resetForTesting() {
    _prefs = null;
    _privateKeys.clear();
  }

  // --- Applications ---
  Future<List<AdoptionApplication>?> loadApplications() async {
    try {
      var raw = await _secureStore.read(key: _keyApplications);
      if (raw == null || raw.trim().isEmpty) {
        // Migrate a dossier stored in plaintext by an earlier build.
        final p = await prefs;
        final legacy = p.getString(_keyApplications);
        if (legacy != null && legacy.trim().isNotEmpty) {
          await _secureStore.write(key: _keyApplications, value: legacy);
          await p.remove(_keyApplications);
          raw = legacy;
        }
      }
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
    final encoded = jsonEncode(applications.map((a) => a.toJson()).toList());
    await _secureStore.write(key: _keyApplications, value: encoded);
    final p = await prefs;
    await p.remove(_keyApplications);
  }

  // --- Drafts ---
  Future<Map<String, dynamic>?> loadApplicationDraft(String petId) async {
    try {
      final key = '$_keyDraftPrefix$petId';
      var raw = await _secureStore.read(key: key);
      if (raw == null) {
        final p = await prefs;
        final legacy = p.getString(key);
        if (legacy != null) {
          await _secureStore.write(key: key, value: legacy);
          await p.remove(key);
          raw = legacy;
        }
      }
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
    final key = '$_keyDraftPrefix$petId';
    await _secureStore.write(key: key, value: jsonEncode(draftData));
    final p = await prefs;
    await p.remove(key);
  }

  Future<void> clearApplicationDraft(String petId) async {
    final key = '$_keyDraftPrefix$petId';
    await _secureStore.delete(key: key);
    final p = await prefs;
    await p.remove(key);
  }

  // --- Conversations & Messages (encrypted at rest) ---
  Future<List<ChatConversation>?> loadConversations() async {
    try {
      final raw = await _readPrivate(_keyConversations);
      if (raw == null) return null;
      return (jsonDecode(raw) as List).map((item) =>
        ChatConversation.fromJson(Map<String, dynamic>.from(item as Map))).toList();
    } catch (_) { return null; }
  }
  Future<void> saveConversations(List<ChatConversation> conversations) =>
    _writePrivate(_keyConversations, jsonEncode(conversations.map((c) => c.toJson()).toList()));
  Future<List<ChatMessage>?> loadMessages(String conversationId) async {
    try {
      final raw = await _readPrivate('$_keyMessagesPrefix$conversationId');
      if (raw == null) return null;
      return (jsonDecode(raw) as List).map((item) =>
        ChatMessage.fromJson(Map<String, dynamic>.from(item as Map))).toList();
    } catch (_) { return null; }
  }
  Future<void> saveMessages(String conversationId, List<ChatMessage> messages) =>
    _writePrivate('$_keyMessagesPrefix$conversationId', jsonEncode(messages.map((m) => m.toJson()).toList()));
  Future<void> clearMessages(String conversationId) => _deletePrivate('$_keyMessagesPrefix$conversationId');

  Future<void> clearAllChats() async {
    final keys = _privateKeys.where((k) => k.startsWith(_keyMessagesPrefix)).toList();
    for (final key in keys) { await _deletePrivate(key); }
    await _deletePrivate(_keyConversations);
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
    final keys = {..._privateKeys, _keyApplications, _keyConversations};
    final p = await prefs;
    keys.addAll(p.getKeys().where((k) => k.startsWith(_keyDraftPrefix) || k.startsWith(_keyMessagesPrefix)));
    for (final key in keys) { await _deletePrivate(key); }
    for (final key in p.getKeys().toList()) {
      if (key != _keyHasSeenOnboarding) await p.remove(key);
    }
    _privateKeys.clear();
  }
}
