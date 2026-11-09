/// Data layer for the Supabase edition.
///
/// Drop this file into the Flutter app (it needs `supabase_flutter` and
/// `google_sign_in`, both already in `pubspec.yaml`) and replace the Laravel
/// repositories with the calls below. Every method maps 1:1 to a table, a view,
/// an RPC or an Edge Function — there is no custom REST API in between.
///

// Auth model: Supabase owns the session. `Supabase.instance.client.auth`
// refreshes the access token, and the JWT carries `app_role`, so RLS enforces
// permissions without the app re-checking anything.

import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseConfig {
  const SupabaseConfig({required this.url, required this.anonKey});

  final String url;
  final String anonKey;

  static Future<void> initialize({
    required String url,
    required String anonKey,
  }) {
    return Supabase.initialize(url: url, anonKey: anonKey);
  }
}

/// Raised for anything the UI should show as a plain sentence.
class AdoptMatchException implements Exception {
  AdoptMatchException(this.message, {this.code = 'UNKNOWN'});

  final String message;
  final String code;

  @override
  String toString() => message;
}

class AdoptMatchBackend {
  static AdoptMatchBackend? _instance;
  static AdoptMatchBackend get instance => _instance ??= AdoptMatchBackend();

  static bool get isInitialized {
    try {
      return Supabase.instance.client.auth.currentSession != null || true;
    } catch (_) {
      return false;
    }
  }

  AdoptMatchBackend({SupabaseClient? client})
    : _db = client ?? Supabase.instance.client;

  final SupabaseClient _db;

  SupabaseClient get client => _db;
  GoTrueClient get auth => _db.auth;
  User? get currentUser => _db.auth.currentUser;
  Stream<AuthState> get authChanges => _db.auth.onAuthStateChange;

  // ---------------------------------------------------------------------------
  // Auth
  // ---------------------------------------------------------------------------

  /// Google Sign-In: the native picker returns an ID token, Supabase verifies it
  /// against the project's Google client. No server round-trip of our own.
  Future<void> signInWithGoogle({
    required String idToken,
    String? accessToken,
  }) async {
    try {
      await _db.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        accessToken: accessToken,
      );
    } on AuthException catch (error) {
      throw AdoptMatchException(error.message, code: 'GOOGLE_SIGN_IN_FAILED');
    }
  }

  Future<void> signUpWithEmail({
    required String email,
    required String password,
    required String fullName,
  }) async {
    try {
      final response = await _db.auth.signUp(
        email: email.trim().toLowerCase(),
        password: password,
        data: {'full_name': fullName.trim()},
      );
      if (response.session == null) {
        throw AdoptMatchException(
          'Check your email to confirm the account, then sign in.',
          code: 'EMAIL_CONFIRMATION_REQUIRED',
        );
      }
    } on AuthException catch (error) {
      throw AdoptMatchException(error.message, code: 'SIGN_UP_FAILED');
    }
  }

  Future<void> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      await _db.auth.signInWithPassword(
        email: email.trim().toLowerCase(),
        password: password,
      );
    } on AuthException catch (error) {
      throw AdoptMatchException(
        error.message.toLowerCase().contains('invalid')
            ? 'Invalid email or password.'
            : error.message,
        code: 'SIGN_IN_FAILED',
      );
    }
  }

  /// Phone OTP runs entirely inside Supabase Auth; the app never sees the SMS
  /// provider credentials.
  Future<void> requestPhoneOtp(String phone) async {
    try {
      await _db.auth.signInWithOtp(phone: phone);
    } on AuthException catch (error) {
      throw AdoptMatchException(error.message, code: 'OTP_REQUEST_FAILED');
    }
  }

  Future<void> verifyPhoneOtp({
    required String phone,
    required String token,
  }) async {
    try {
      await _db.auth.verifyOTP(phone: phone, token: token, type: OtpType.sms);
    } on AuthException {
      throw AdoptMatchException(
        'Invalid or expired OTP.',
        code: 'OTP_VERIFY_FAILED',
      );
    }
  }

  Future<void> signOut() async {
    await _db.auth.signOut();
  }

  Future<Map<String, dynamic>?> myProfile() async {
    final user = currentUser;
    if (user == null) return null;
    return _db.from('profiles').select().eq('id', user.id).maybeSingle();
  }

  Future<void> updateProfile({
    String? fullName,
    String? phone,
    String? avatarUrl,
    String? location,
    String? bio,
  }) async {
    final user = _requireUser();
    final patch = <String, dynamic>{
      if (fullName != null) 'full_name': fullName,
      if (phone != null) 'phone': phone,
      if (avatarUrl != null) 'avatar_url': avatarUrl,
      if (location != null) 'location': location,
      if (bio != null) 'bio': bio,
    };
    if (patch.isEmpty) return;
    await _db.from('profiles').update(patch).eq('id', user.id);
  }

  Future<void> deleteAccount() async {
    // Requires the `delete-account` Edge Function; kept explicit so the UI does
    // not claim deletion that did not happen.
    final response = await _db.functions.invoke('delete-account');
    if (response.status != 200) {
      throw AdoptMatchException(
        'Account deletion failed. Contact support.',
        code: 'DELETE_FAILED',
      );
    }
    await _db.auth.signOut();
  }

  // ---------------------------------------------------------------------------
  // Listings
  // ---------------------------------------------------------------------------

  Future<List<Map<String, dynamic>>> feed({
    String? species,
    String? city,
    bool urgentOnly = false,
    int limit = 50,
  }) async {
    var query = _db
        .from('pets_feed')
        .select()
        .eq('moderation_status', 'approved');
    if (species != null && species.isNotEmpty)
      query = query.eq('species', species);
    if (city != null && city.isNotEmpty) query = query.eq('city', city);
    if (urgentOnly) query = query.eq('is_urgent', true);
    final rows = await query.order('created_at', ascending: false).limit(limit);
    return List<Map<String, dynamic>>.from(rows as List);
  }

  Future<List<Map<String, dynamic>>> nearby({
    required double latitude,
    required double longitude,
    double radiusKm = 25,
    int limit = 50,
  }) async {
    final rows = await _db.rpc(
      'pets_nearby',
      params: {
        'p_lat': latitude,
        'p_lng': longitude,
        'p_radius_km': radiusKm,
        'p_limit': limit,
      },
    );
    return List<Map<String, dynamic>>.from(rows as List);
  }

  Future<void> toggleFavorite(String petId, {required bool favorite}) async {
    final user = _requireUser();
    if (favorite) {
      await _db.from('favorites').upsert({'user_id': user.id, 'pet_id': petId});
    } else {
      await _db
          .from('favorites')
          .delete()
          .eq('user_id', user.id)
          .eq('pet_id', petId);
    }
  }

  Future<void> swipe(String petId, {required bool like}) async {
    final user = _requireUser();
    await _db.from('swipes').upsert({
      'user_id': user.id,
      'pet_id': petId,
      'direction': like ? 'like' : 'dislike',
    });
  }

  Future<String> createListing(Map<String, dynamic> pet) async {
    final user = _requireUser();
    final row = await _db
        .from('pets')
        .insert({...pet, 'owner_id': user.id})
        .select('id')
        .single();
    return row['id'] as String;
  }

  Future<void> updateListing(String petId, Map<String, dynamic> patch) async {
    await _db.from('pets').update(patch).eq('id', petId);
  }

  /// Uploads go straight to Storage. The path must start with the user id; the
  /// bucket policy rejects anything else.
  Future<String> uploadPetImage(
    String petId,
    List<int> bytes,
    String extension,
  ) async {
    final user = _requireUser();
    final path =
        '${user.id}/$petId/${DateTime.now().millisecondsSinceEpoch}.$extension';
    await _db.storage
        .from('pet-images')
        .uploadBinary(path, Uint8List.fromList(bytes));
    return _db.storage.from('pet-images').getPublicUrl(path);
  }

  // ---------------------------------------------------------------------------
  // Adoption workflow
  // ---------------------------------------------------------------------------

  Future<String> submitApplication({
    required String petId,
    required Map<String, dynamic> dossier,
    required String signatureData,
  }) async {
    final user = _requireUser();
    final row = await _db
        .from('adoption_requests')
        .insert({
          'pet_id': petId,
          'applicant_id': user.id,
          'applicant_data': dossier,
          'signature_data': signatureData,
          'is_e_signed': true,
        })
        .select('id')
        .single();
    return row['id'] as String;
  }

  Future<List<Map<String, dynamic>>> myApplications() async {
    final user = _requireUser();
    final rows = await _db
        .from('adoption_requests')
        .select()
        .eq('applicant_id', user.id)
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(rows as List);
  }

  Future<List<Map<String, dynamic>>> applicationsForMyListings() async {
    final rows = await _db
        .from('adoption_requests')
        .select('*, pets!inner(name, owner_id)')
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(rows as List);
  }

  Future<void> withdrawApplication(String applicationId) async {
    await _db
        .from('adoption_requests')
        .update({'status': 'withdrawn'})
        .eq('id', applicationId);
  }

  Future<void> reviewApplication({
    required String applicationId,
    required String status,
    required String notes,
  }) async {
    await _db
        .from('adoption_requests')
        .update({'status': status, 'reviewer_notes': notes})
        .eq('id', applicationId);
  }

  // ---------------------------------------------------------------------------
  // Messaging
  // ---------------------------------------------------------------------------

  Future<List<Map<String, dynamic>>> conversations() async {
    final user = _requireUser();
    final rows = await _db
        .from('conversations')
        .select()
        .or('adopter_id.eq.${user.id},owner_id.eq.${user.id}')
        .order('last_message_at', ascending: false);
    return List<Map<String, dynamic>>.from(rows as List);
  }

  Future<String> startConversation({
    required String petId,
    required String ownerId,
  }) async {
    final user = _requireUser();
    final existing = await _db
        .from('conversations')
        .select('id')
        .eq('pet_id', petId)
        .eq('adopter_id', user.id)
        .maybeSingle();
    if (existing != null) return existing['id'] as String;

    final row = await _db
        .from('conversations')
        .insert({'pet_id': petId, 'adopter_id': user.id, 'owner_id': ownerId})
        .select('id')
        .single();
    return row['id'] as String;
  }

  Future<List<Map<String, dynamic>>> messages(String conversationId) async {
    final rows = await _db
        .from('messages')
        .select()
        .eq('conversation_id', conversationId)
        .order('created_at');
    return List<Map<String, dynamic>>.from(rows as List);
  }

  Future<void> sendMessage({
    required String conversationId,
    required String body,
    String? attachmentUrl,
  }) async {
    final user = _requireUser();
    await _db.from('messages').insert({
      'conversation_id': conversationId,
      'sender_id': user.id,
      'body': body,
      'attachment_url': attachmentUrl,
    });
  }

  Stream<List<Map<String, dynamic>>> liveMessages(String conversationId) {
    return _db
        .from('messages')
        .stream(primaryKey: ['id'])
        .eq('conversation_id', conversationId)
        .order('created_at')
        .map((rows) => List<Map<String, dynamic>>.from(rows));
  }

  // ---------------------------------------------------------------------------
  // Payments (Edge Functions; the client never writes money rows)
  // ---------------------------------------------------------------------------

  Future<List<Map<String, dynamic>>> plans() async {
    final rows = await _db
        .from('subscription_plans')
        .select()
        .eq('is_active', true)
        .order('price');
    return List<Map<String, dynamic>>.from(rows as List);
  }

  Future<String?> bkashNumber() async {
    final response = await _db.functions.invoke('payments/bkash-number');
    final data = _unwrap(response);
    return data['bkashNumber']?.toString();
  }

  Future<Map<String, dynamic>> startSslcommerz({
    required String planId,
    String? name,
    String? email,
    String? phone,
  }) async {
    final response = await _db.functions.invoke(
      'payments/initiate-sslcommerz',
      body: {
        'plan_id': planId,
        'customer': {'name': name, 'email': email, 'phone': phone},
      },
    );
    return _unwrap(response);
  }

  Future<Map<String, dynamic>> submitManualBkash({
    required String planId,
    required String trxId,
    required String senderPhone,
  }) async {
    final response = await _db.functions.invoke(
      'payments/manual-bkash',
      body: {'plan_id': planId, 'trx_id': trxId, 'sender_phone': senderPhone},
    );
    return _unwrap(response);
  }

  Future<Map<String, dynamic>> mySubscription() async {
    final response = await _db.functions.invoke('payments/my-subscription');
    return _unwrap(response);
  }

  // ---------------------------------------------------------------------------
  // Admin (Edge Function enforces the role again)
  // ---------------------------------------------------------------------------

  Future<Map<String, dynamic>> adminStats() async {
    final response = await _db.functions.invoke('admin/stats');
    return _unwrap(response);
  }

  Future<List<Map<String, dynamic>>> adminUsers({
    String? query,
    String? role,
  }) async {
    final params = <String, String>{'limit': '50'};
    if (query != null && query.isNotEmpty) params['q'] = query;
    if (role != null && role.isNotEmpty) params['role'] = role;
    final response = await _db.functions.invoke(
      'admin/users?${_query(params)}',
    );
    final data = _unwrap(response);
    return List<Map<String, dynamic>>.from(data['data'] as List? ?? const []);
  }

  Future<void> setUserRole(String userId, String role) async {
    await _db.functions.invoke('admin/users/$userId', body: {'role': role});
  }

  Future<void> setAccountStatus(String userId, String status) async {
    await _db.functions.invoke('admin/users/$userId', body: {'status': status});
  }

  Future<void> moderateListing(
    String petId, {
    required String status,
    String? reason,
  }) async {
    await _db.functions.invoke(
      'admin/pets/$petId',
      body: {'moderation_status': status, 'reason': reason},
    );
  }

  Future<void> verifyShelter(String shelterId, {required String status}) async {
    await _db.functions.invoke(
      'admin/shelters/$shelterId',
      body: {'verification_status': status},
    );
  }

  Future<void> approvePayment(String tranId) async {
    await _db.functions.invoke('admin/payments/$tranId/approve');
  }

  Future<void> rejectPayment(String tranId, String reason) async {
    await _db.functions.invoke(
      'admin/payments/$tranId/reject',
      body: {'reason': reason},
    );
  }

  // ---------------------------------------------------------------------------
  // Internals
  // ---------------------------------------------------------------------------

  User _requireUser() {
    final user = currentUser;
    if (user == null) {
      throw AdoptMatchException('Sign in to continue.', code: 'SIGNED_OUT');
    }
    return user;
  }

  Map<String, dynamic> _unwrap(FunctionResponse response) {
    final data = response.data;
    if (response.status < 200 || response.status >= 300) {
      final message = data is Map
          ? (data['message'] ?? 'Request failed.')
          : 'Request failed.';
      throw AdoptMatchException(message.toString(), code: 'FUNCTION_FAILED');
    }
    if (data is Map && data['status'] == 'error') {
      throw AdoptMatchException(
        (data['message'] ?? 'Request failed.').toString(),
        code: (data['code'] ?? 'FUNCTION_FAILED').toString(),
      );
    }
    if (data is Map && data['data'] is Map) {
      return Map<String, dynamic>.from(data['data'] as Map);
    }
    return data is Map ? Map<String, dynamic>.from(data) : <String, dynamic>{};
  }

  String _query(Map<String, String> params) {
    return params.entries
        .map(
          (entry) =>
              '${Uri.encodeQueryComponent(entry.key)}=${Uri.encodeQueryComponent(entry.value)}',
        )
        .join('&');
  }
}
