import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/network_error.dart';
import '../../../core/services/local_storage_service.dart';
import '../../../core/storage/secure_storage_service.dart';
import '../../../core/repositories/chat_repository.dart';
import '../../../core/repositories/application_repository.dart';
import '../../../core/repositories/pet_repository.dart';
import '../../../core/supabase/adoptmatch_supabase.dart';
import '../bloc/auth_bloc.dart';

class AuthRepository {
  final ApiClient _apiClient;
  final SecureStorageService _secureStorage;
  final LocalStorageService _localStorage;

  AuthRepository({
    ApiClient? apiClient,
    SecureStorageService? secureStorage,
    LocalStorageService? localStorage,
  }) : _apiClient = apiClient ?? ApiClient(),
       _secureStorage = secureStorage ?? SecureStorageService.instance,
       _localStorage = localStorage ?? LocalStorageService.instance;

  static UserProfile userFromSupabase(
    Map<String, dynamic> profile, [
    Map<String, dynamic>? subData,
  ]) {
    final sub = subData?['subscription'] is Map
        ? (subData!['subscription'] as Map)
        : null;
    final isPremium = sub?['is_premium'] == true;
    final expiryStr = sub?['expires_at']?.toString();
    final expiry = expiryStr != null ? DateTime.tryParse(expiryStr) : null;
    final planId = sub?['plan_id']?.toString();
    final roleStr = profile['role']?.toString() ?? 'adopter';

    return UserProfile(
      id: profile['id']?.toString() ?? '',
      name:
          profile['full_name']?.toString() ??
          profile['name']?.toString() ??
          'Pet Lover',
      email: profile['email']?.toString() ?? '',
      phone: profile['phone']?.toString() ?? '',
      role: UserRole.fromCode(roleStr),
      isVerified: profile['is_verified'] == true,
      avatarUrl: profile['avatar_url']?.toString() ?? '',
      bio: profile['bio']?.toString() ?? '',
      location: profile['location']?.toString() ?? 'Dhaka, Bangladesh',
      preferredPetType: profile['preferred_pet_type']?.toString() ?? 'All Pets',
      isPremium: isPremium,
      premiumPlanId: planId,
      premiumExpiresAt: expiry,
      subscriptionStatus: isPremium ? 'ACTIVE' : 'INACTIVE',
    );
  }

  /// Authenticate user via Supabase Auth (or legacy mock/api client in unit tests)
  Future<UserProfile> loginWithEmail({
    required String email,
    required String password,
  }) async {
    if (AdoptMatchBackend.isInitialized) {
      try {
        await AdoptMatchBackend.instance.signInWithEmail(
          email: email,
          password: password,
        );
        final profile = await AdoptMatchBackend.instance.myProfile();
        if (profile == null) {
          throw Exception(
            'Unable to load user profile from authentication server.',
          );
        }
        Map<String, dynamic> sub = {};
        try {
          sub = await AdoptMatchBackend.instance.mySubscription();
        } catch (_) {}
        final user = userFromSupabase(profile, sub);
        await _secureStorage.saveUserProfile(user);
        return user;
      } on AdoptMatchException catch (e) {
        throw Exception(e.message);
      } catch (e) {
        rethrow;
      }
    }

    try {
      final response = await _apiClient.dio.post(
        '/auth/login',
        data: {'email': email.trim().toLowerCase(), 'password': password},
      );

      final data = response.data as Map<String, dynamic>;
      final token = data['access_token'] as String?;
      final userMap = data['user'] as Map<String, dynamic>?;

      if (token == null || userMap == null) {
        throw Exception('Invalid login response from authentication server.');
      }

      final user = UserProfile.fromJson(userMap);

      // Persist token and profile securely
      await _secureStorage.saveAuthToken(token);
      await _secureStorage.saveUserProfile(user);

      return user;
    } on DioException catch (e) {
      throw Exception(
        describeNetworkFailure(
          e,
          fallback:
              'Unable to reach the authentication server. Please try again.',
        ),
      );
    } catch (e) {
      rethrow;
    }
  }

  /// Register new adopter account via Supabase Auth
  Future<UserProfile> register({
    required String name,
    required String email,
    required String password,
    String? phone,
    String role = 'adopter',
  }) async {
    if (AdoptMatchBackend.isInitialized) {
      try {
        final needsConfirmation =
            await AdoptMatchBackend.instance.signUpWithEmail(
          email: email,
          password: password,
          fullName: name,
        );
        if (needsConfirmation) {
          // Not an error: the account exists, the user just has to confirm.
          throw Exception(
            'Account created. Check $email for the confirmation link, then '
            'sign in.',
          );
        }
        final profile = await AdoptMatchBackend.instance.myProfile();
        if (profile == null) {
          throw Exception(
            'Your account was created. Please sign in to continue.',
          );
        }
        final user = userFromSupabase(profile, {});
        await _secureStorage.saveUserProfile(user);
        return user;
      } on AdoptMatchException catch (e) {
        throw Exception(e.message);
      } catch (e) {
        rethrow;
      }
    }

    try {
      final response = await _apiClient.dio.post(
        '/auth/register',
        data: {
          'name': name.trim(),
          'email': email.trim().toLowerCase(),
          'password': password,
          if (phone != null && phone.isNotEmpty) 'phone': phone.trim(),
          'role': role,
        },
      );

      final data = response.data as Map<String, dynamic>;
      final token = data['access_token'] as String?;
      final userMap = data['user'] as Map<String, dynamic>?;

      if (token == null || userMap == null) {
        throw Exception(
          'Registration succeeded but session token was missing.',
        );
      }

      final user = UserProfile.fromJson(userMap);

      await _secureStorage.saveAuthToken(token);
      await _secureStorage.saveUserProfile(user);

      return user;
    } on DioException catch (e) {
      throw Exception(
        describeNetworkFailure(
          e,
          fallback: 'Registration failed. Please verify your details.',
        ),
      );
    }
  }

  /// Checks if a valid persistent session exists
  Future<UserProfile?> verifyCurrentSession() async {
    if (AdoptMatchBackend.isInitialized) {
      final session = Supabase.instance.client.auth.currentSession;
      if (session == null) return null;
      try {
        var profile = await AdoptMatchBackend.instance.myProfile();
        if (profile == null) {
          await Future.delayed(const Duration(milliseconds: 250));
          profile = await AdoptMatchBackend.instance.myProfile();
        }
        if (profile != null) {
          Map<String, dynamic> sub = {};
          try {
            sub = await AdoptMatchBackend.instance.mySubscription();
          } catch (_) {}
          final user = userFromSupabase(profile, sub);
          await _secureStorage.saveUserProfile(user);
          return user;
        }

        // Resilient fallback: build user profile from verified Supabase session
        final sbUser = session.user;
        final rawName =
            (sbUser.userMetadata?['full_name'] ??
                    sbUser.userMetadata?['name'] ??
                    sbUser.email?.split('@').first ??
                    'Adopter')
                .toString();
        final avatar =
            (sbUser.userMetadata?['avatar_url'] ??
                    sbUser.userMetadata?['picture'] ??
                    '')
                .toString();

        final user = UserProfile(
          id: sbUser.id,
          name: rawName,
          email: sbUser.email ?? '',
          phone: sbUser.phone ?? '',
          role: UserRole.adopter,
          avatarUrl: avatar,
          googlePhotoUrl: avatar,
          location: 'Dhaka, Bangladesh',
          bio: 'Animal advocate & pet rescuer',
          preferredPetType: 'All Pets',
          isVerified: true,
        );
        await _secureStorage.saveUserProfile(user);
        return user;
      } catch (e) {
        debugPrint('[AuthRepository] Error verifying Supabase session: $e');
        return null;
      }
    }

    final token = await _secureStorage.getAuthToken();
    if (token == null || token.isEmpty) {
      return null;
    }

    try {
      final response = await _apiClient.dio.get('/auth/me');
      final data = response.data as Map<String, dynamic>;
      final userMap = data['user'] as Map<String, dynamic>?;

      if (userMap != null) {
        final user = UserProfile.fromJson(userMap);
        await _secureStorage.saveUserProfile(user);
        return user;
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        debugPrint(
          '[AuthRepository] Session token expired or revoked. Clearing local session.',
        );
        await _secureStorage.clearSession();
        return null;
      }
      return null;
    } catch (e) {
      debugPrint('[AuthRepository] Error verifying session: $e');
    }

    return null;
  }

  /// Complete Logout: Revoke server token, clear secure storage & wipe user cache
  Future<void> logout() async {
    if (AdoptMatchBackend.isInitialized) {
      try {
        await AdoptMatchBackend.instance.signOut();
      } catch (e) {
        debugPrint('[AuthRepository] Supabase signOut notice: $e');
      }
    }

    try {
      await _apiClient.dio
          .post('/auth/logout')
          .timeout(const Duration(seconds: 4));
    } catch (e) {
      debugPrint('[AuthRepository] Server logout notice: $e');
    } finally {
      await ChatRepository().clearCache();
      await ApplicationRepository().clearCache();
      await PetRepository().clearUserCache();
      await _secureStorage.clearSession();
      await _localStorage.clearAllUserData();
    }
  }
}
