import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../features/admin/models/shelter_application_model.dart';
import '../../features/admin/models/admin_pet_moderation_model.dart';
import '../../features/admin/models/admin_audit_log_model.dart';
import '../../features/auth/bloc/auth_bloc.dart';
import '../models/pet_model.dart';
import '../network/api_client.dart';
import '../storage/secure_storage_service.dart';
import '../supabase/adoptmatch_supabase.dart';

class AdminKPI {
  final int? totalAdoptions;
  final int pendingShelters;
  final int activeRescues;
  final int? totalDonationsBDT;
  final int flaggedListings;
  final int? activeDisputes;

  const AdminKPI({
    required this.totalAdoptions,
    required this.pendingShelters,
    required this.activeRescues,
    required this.totalDonationsBDT,
    required this.flaggedListings,
    required this.activeDisputes,
  });
}

class AdminManagedUser {
  final String id;
  final String name;
  final String email;
  final String phone;
  final UserRole role;
  final String status; // 'Active', 'Suspended', 'Banned'
  final List<String> permissions;
  final int adoptionsCount;
  final DateTime joinedAt;

  bool get isBanned => status.toUpperCase() == 'BANNED';

  const AdminManagedUser({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.role,
    required this.status,
    this.permissions = const [],
    required this.adoptionsCount,
    required this.joinedAt,
  });

  AdminManagedUser copyWith({
    String? id,
    String? name,
    String? email,
    String? phone,
    UserRole? role,
    String? status,
    List<String>? permissions,
    int? adoptionsCount,
    DateTime? joinedAt,
  }) {
    return AdminManagedUser(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      role: role ?? this.role,
      status: status ?? this.status,
      permissions: permissions ?? this.permissions,
      adoptionsCount: adoptionsCount ?? this.adoptionsCount,
      joinedAt: joinedAt ?? this.joinedAt,
    );
  }
}

class AdoptionDisputeRecord {
  final String id;
  final String adopterName;
  final String shelterName;
  final String petName;
  final String contractStatus; // 'Signed', 'Pending Signature', 'Breached'
  final String trialPeriod; // 'Day 9 of 14', 'Completed', 'Disputed'
  final String disputeStatus; // 'Under Investigation', 'Resolved', 'Mediation Required'
  final String issueSummary;
  final DateTime updatedAt;

  const AdoptionDisputeRecord({
    required this.id,
    required this.adopterName,
    required this.shelterName,
    required this.petName,
    required this.contractStatus,
    required this.trialPeriod,
    required this.disputeStatus,
    required this.issueSummary,
    required this.updatedAt,
  });
}

/// Administrative state is read from and written to the authenticated API only.
class AdminRepository {
  static final AdminRepository _instance = AdminRepository._internal();
  factory AdminRepository() => _instance;
  AdminRepository._internal();
  http.Client _client = http.Client();
  bool _isTestConfigured = false;
  Future<String?> Function() _readToken = SecureStorageService.instance.getAuthToken;
  String? lastSyncError;

  void configureForTesting(http.Client client, Future<String?> Function() tokenReader) {
    _isTestConfigured = true;
    _client = client; _readToken = tokenReader;
    _users = []; _pets = []; _flaggedPets = []; _shelters = []; _auditLogs = []; _kpis = null; lastSyncError = null;
  }

  bool get _useSupabase => AdoptMatchBackend.isInitialized && !_isTestConfigured;

  final _sheltersController = StreamController<List<ShelterApplication>>.broadcast();
  final _flaggedPetsController = StreamController<List<FlaggedPetListing>>.broadcast();
  final _usersController = StreamController<List<AdminManagedUser>>.broadcast();
  final _auditLogsController = StreamController<List<AdminAuditLog>>.broadcast();
  final _petsController = StreamController<List<Pet>>.broadcast();
  Stream<List<ShelterApplication>> get sheltersStream => _sheltersController.stream;
  Stream<List<FlaggedPetListing>> get flaggedPetsStream => _flaggedPetsController.stream;
  Stream<List<AdminManagedUser>> get usersStream => _usersController.stream;
  Stream<List<AdminAuditLog>> get auditLogsStream => _auditLogsController.stream;
  Stream<List<Pet>> get petsStream => _petsController.stream;
  List<ShelterApplication> _shelters = [];
  List<Pet> _pets = [];
  List<FlaggedPetListing> _flaggedPets = [];
  List<AdminManagedUser> _users = [];
  List<AdminAuditLog> _auditLogs = [];
  AdminKPI? _kpis;

  List<ShelterApplication> getShelters() => List.unmodifiable(_shelters);
  List<Pet> getPets() => List.unmodifiable(_pets);
  List<AdminManagedUser> getUsers() => List.unmodifiable(_users);
  List<AdminAuditLog> getAuditLogs() => List.unmodifiable(_auditLogs);
  AdminKPI? getKPIs() => _kpis;
  List<FlaggedPetListing> getFlaggedPets() => List.unmodifiable(_flaggedPets);
  List<AdoptionDisputeRecord> getDisputes() => const []; // No dispute ledger is configured.

  Future<Map<String, String>> _headers() async {
    final token = await _readToken();
    if (token == null || token.isEmpty) throw Exception('An authenticated admin session is required.');
    return {'Accept': 'application/json', 'Content-Type': 'application/json', 'Authorization': 'Bearer $token'};
  }
  Uri _uri(String path) => Uri.parse('${ApiClient.rootUrl}/api/v1/admin$path');
  Map<String, dynamic> _decode(http.Response response) {
    final body = jsonDecode(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300 || body['success'] != true) {
      throw Exception((body['error'] ?? body['message'] ?? 'Admin request failed (${response.statusCode})').toString());
    }
    return Map<String, dynamic>.from(body as Map);
  }
  Future<Map<String, dynamic>> _request(String method, String path, [Map<String, dynamic>? data]) async {
    final request = http.Request(method, _uri(path))..headers.addAll(await _headers());
    if (data != null) request.body = jsonEncode(data);
    final streamed = await _client.send(request).timeout(const Duration(seconds: 15));
    return _decode(await http.Response.fromStream(streamed));
  }
  Future<List<Map<String, dynamic>>?> _optionalList(String path) async {
    final request = http.Request('GET', _uri(path))..headers.addAll(await _headers());
    final response = await http.Response.fromStream(await _client.send(request).timeout(const Duration(seconds: 15)));
    if (response.statusCode == 403) return null; // Moderators may lack this permission.
    final data = _decode(response)['data'];
    if (data is! List) throw Exception('Invalid $path response.');
    return data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<void> refresh() async {
    if (_useSupabase) {
      try {
        final statsData = await AdoptMatchBackend.instance.adminStats();
        _kpis = AdminKPI(
          totalAdoptions: (statsData['adoptions_completed'] ?? statsData['totalAdoptions']) as int?,
          pendingShelters: (statsData['pending_shelters'] ?? statsData['pendingShelters'] ?? 0) as int,
          activeRescues: (statsData['available_pets'] ?? statsData['activeRescues'] ?? 0) as int,
          totalDonationsBDT: (statsData['revenue_bdt'] ?? statsData['totalDonationsBDT']) as int?,
          flaggedListings: (statsData['pending_pets'] ?? statsData['flaggedListings'] ?? 0) as int,
          activeDisputes: (statsData['unverified_payments'] ?? statsData['activeDisputes']) as int?,
        );

        final usersList = await AdoptMatchBackend.instance.adminUsers();
        _users = usersList.map((u) => AdminManagedUser(
          id: u['id'].toString(),
          name: (u['full_name'] ?? u['name'] ?? '').toString(),
          email: (u['email'] ?? '').toString(),
          phone: (u['phone'] ?? '').toString(),
          role: UserRole.fromCode(u['role']?.toString() ?? 'USER'),
          status: (u['status'] ?? 'Active').toString(),
          permissions: List<String>.from(u['permissions'] as List? ?? const []),
          adoptionsCount: (u['adoptionsCount'] as num?)?.toInt() ?? 0,
          joinedAt: DateTime.tryParse(u['created_at']?.toString() ?? u['joinedAt']?.toString() ?? '') ?? DateTime.now(),
        )).toList();

        final shelterRows = await Supabase.instance.client
            .from('shelters')
            .select('*, profile:profiles(id, full_name, email, phone)')
            .order('created_at', ascending: false);
        _shelters = (shelterRows as List).map((sRaw) {
          final s = Map<String, dynamic>.from(sRaw as Map);
          final prof = Map<String, dynamic>.from(s['profile'] as Map? ?? {});
          return ShelterApplication(
            id: s['id'].toString(),
            shelterName: (s['name'] ?? s['shelterName'] ?? '').toString(),
            registrationNumber: (s['registrationNumber'] ?? '').toString(),
            contactPerson: (prof['full_name'] ?? s['contactPerson'] ?? '').toString(),
            email: (s['email'] ?? prof['email'] ?? '').toString(),
            phone: (s['phone'] ?? prof['phone'] ?? '').toString(),
            city: (s['city'] ?? 'Dhaka').toString(),
            address: (s['address'] ?? '').toString(),
            nidNumber: (s['nidNumber'] ?? '').toString(),
            tradeLicenseNumber: (s['tradeLicenseNumber'] ?? '').toString(),
            vetAffiliation: (s['vetAffiliation'] ?? '').toString(),
            status: VerificationStatus.values.firstWhere(
              (v) => v.name.toUpperCase() == (s['verification_status'] ?? s['status'] ?? '').toString().toUpperCase(),
              orElse: () => VerificationStatus.pending,
            ),
            documentUrls: List<String>.from(s['documentUrls'] as List? ?? const []),
            submittedAt: DateTime.tryParse(s['created_at']?.toString() ?? s['submittedAt']?.toString() ?? '') ?? DateTime.now(),
            reviewerNotes: s['reviewerNotes']?.toString(),
            capacity: (s['capacity'] as num?)?.toInt() ?? 30,
          );
        }).toList();

        final petRows = await Supabase.instance.client
            .from('pets')
            .select()
            .order('created_at', ascending: false);
        _pets = (petRows as List).map((pRaw) {
          final p = Map<String, dynamic>.from(pRaw as Map);
          return Pet(
            id: p['id'].toString(),
            name: (p['name'] ?? '').toString(),
            species: (p['species'] ?? '').toString(),
            breed: (p['breed'] ?? '').toString(),
            ageDisplay: (p['age_display'] ?? p['ageDisplay'] ?? '').toString(),
            ageMonths: (p['age_months'] ?? p['ageMonths'] as num?)?.toInt() ?? 0,
            gender: (p['gender'] ?? '').toString(),
            weightKg: (p['weight_kg'] ?? p['weightKg'] as num?)?.toDouble() ?? 0,
            distanceKm: (p['distanceKm'] as num?)?.toDouble() ?? double.infinity,
            matchScore: (p['matchScore'] as num?)?.toInt() ?? 0,
            imageUrl: (p['primary_image_url'] ?? p['imageUrl'] ?? '').toString(),
            galleryUrls: List<String>.from((p['gallery_urls'] ?? p['galleryUrls']) as List? ?? const []),
            isUrgent: p['is_urgent'] == true || p['isUrgent'] == true,
            isFeatured: p['is_featured'] == true || p['isFeatured'] == true,
            isVaccinated: p['is_vaccinated'] == true || p['isVaccinated'] == true,
            isNeutered: p['is_neutered'] == true || p['isNeutered'] == true,
            isHouseTrained: p['is_house_trained'] == true || p['isHouseTrained'] == true,
            isKidSafe: p['is_kid_safe'] == true || p['isKidSafe'] == true,
            isApartmentFriendly: p['is_apartment_friendly'] == true || p['isApartmentFriendly'] == true,
            shelterName: (p['shelter_name'] ?? p['shelterName'] ?? '').toString(),
            shelterPhone: (p['shelter_phone'] ?? p['shelterPhone'] ?? '').toString(),
            shelterAddress: (p['shelter_address'] ?? p['shelterAddress'] ?? '').toString(),
            story: (p['bio'] ?? p['story'] ?? '').toString(),
            medicalHistory: (p['medical_history'] ?? p['medicalHistory'] ?? '').toString(),
            qrHash: (p['qr_hash'] ?? p['qrHash'] ?? '').toString(),
            adoptionStatus: (p['adoption_status'] ?? p['adoptionStatus'] ?? 'available').toString(),
          );
        }).toList();

        _flaggedPets = _pets.where((p) => p.adoptionStatus == 'flagged' || p.adoptionStatus == 'pending').map((p) =>
          FlaggedPetListing(
            id: p.id,
            petName: p.name,
            species: p.species,
            breed: p.breed,
            postedBy: 'Listing owner',
            posterRole: 'Listing owner',
            city: p.shelterAddress,
            imageUrl: p.imageUrl,
            reportsCount: 1,
            reportReasons: const ['Review required'],
            isBanned: false,
            isUrgent: p.isUrgent,
            isFeatured: p.isFeatured,
            listedAt: DateTime.now(),
          )).toList();

        final logRows = await Supabase.instance.client
            .from('audit_logs')
            .select('*, actor:profiles(id, full_name, role)')
            .order('created_at', ascending: false)
            .limit(50);
        _auditLogs = (logRows as List).map((lRaw) {
          final l = Map<String, dynamic>.from(lRaw as Map);
          final actor = Map<String, dynamic>.from(l['actor'] as Map? ?? {});
          return AdminAuditLog(
            id: l['id'].toString(),
            timestamp: DateTime.parse(l['created_at'].toString()),
            actorName: (actor['full_name'] ?? l['actorName'] ?? 'Admin').toString(),
            actorRole: (actor['role'] ?? l['actorRole'] ?? 'admin').toString(),
            action: (l['action'] ?? '').toString(),
            target: (l['target_type'] != null ? '${l['target_type']}:${l['target_id']}' : l['target'] ?? '').toString(),
            ipAddress: (l['ip_address'] ?? l['ipAddress'] ?? '127.0.0.1').toString(),
            details: (l['payload'] != null ? jsonEncode(l['payload']) : l['details'] ?? '').toString(),
          );
        }).toList();

        _sheltersController.add(getShelters());
        _usersController.add(getUsers());
        _petsController.add(getPets());
        _flaggedPetsController.add(getFlaggedPets());
        _auditLogsController.add(getAuditLogs());
        lastSyncError = null;
        return;
      } catch (e) {
        lastSyncError = e.toString();
        debugPrint('[AdminRepository] Supabase refresh error: $e');
        rethrow;
      }
    }
    final results = await Future.wait([
      _request('GET', '/stats'), _optionalList('/users'), _optionalList('/shelters'),
      _optionalList('/pets'), _optionalList('/audit-logs'),
    ]);
    final stats = results[0] as Map<String, dynamic>;
    final data = Map<String, dynamic>.from(stats['data'] as Map);
    _kpis = AdminKPI(totalAdoptions: (data['totalAdoptions'] as num?)?.toInt(),
      pendingShelters: (data['pendingShelters'] as num?)?.toInt() ?? 0,
      activeRescues: (data['activeRescues'] as num?)?.toInt() ?? 0,
      totalDonationsBDT: (data['totalDonationsBDT'] as num?)?.toInt(),
      flaggedListings: (data['flaggedListings'] as num?)?.toInt() ?? 0,
      activeDisputes: (data['activeDisputes'] as num?)?.toInt());
    final users = results[1] as List<Map<String, dynamic>>?;
    if (users != null) _users = users.map((u) => AdminManagedUser(id: u['id'].toString(),
      name: (u['name'] ?? '').toString(), email: (u['email'] ?? '').toString(), phone: (u['phone'] ?? '').toString(),
      role: UserRole.fromCode(u['role']?.toString() ?? 'USER'), status: (u['status'] ?? 'Active').toString(),
      permissions: List<String>.from(u['permissions'] as List? ?? const []),
      adoptionsCount: (u['adoptionsCount'] as num?)?.toInt() ?? 0,
      joinedAt: DateTime.tryParse(u['joinedAt']?.toString() ?? '') ?? DateTime.now())).toList();
    final shelters = results[2] as List<Map<String, dynamic>>?;
    if (shelters != null) _shelters = shelters.map((s) => ShelterApplication(id: s['id'].toString(),
      shelterName: (s['shelterName'] ?? '').toString(), registrationNumber: (s['registrationNumber'] ?? '').toString(),
      contactPerson: (s['contactPerson'] ?? '').toString(), email: (s['email'] ?? '').toString(), phone: (s['phone'] ?? '').toString(),
      city: (s['city'] ?? '').toString(), address: (s['address'] ?? '').toString(), nidNumber: (s['nidNumber'] ?? '').toString(),
      tradeLicenseNumber: (s['tradeLicenseNumber'] ?? '').toString(), vetAffiliation: (s['vetAffiliation'] ?? '').toString(),
      status: VerificationStatus.values.firstWhere((v) => v.name.toUpperCase() == s['status'], orElse: () => VerificationStatus.pending),
      documentUrls: List<String>.from(s['documentUrls'] as List? ?? const []),
      submittedAt: DateTime.tryParse(s['submittedAt']?.toString() ?? '') ?? DateTime.now(),
      reviewerNotes: s['reviewerNotes']?.toString(), capacity: (s['capacity'] as num?)?.toInt() ?? 0)).toList();
    final pets = results[3] as List<Map<String, dynamic>>?;
    if (pets != null) {
      _pets = pets.map(_petFromJson).toList();
      _flaggedPets = pets.where((p) => (p['reportsCount'] as num?)?.toInt() != null && p['reportsCount'] > 0).map((p) =>
        FlaggedPetListing(id: p['id'].toString(), petName: (p['name'] ?? '').toString(),
          species: (p['species'] ?? '').toString(), breed: (p['breed'] ?? '').toString(),
          postedBy: (p['submittedBy'] ?? '').toString(), posterRole: 'Listing owner',
          city: (p['shelterAddress'] ?? '').toString(), imageUrl: (p['imageUrl'] ?? '').toString(),
          reportsCount: (p['reportsCount'] as num).toInt(),
          reportReasons: List<String>.from(p['reportReasons'] as List? ?? const []),
          isBanned: p['isBanned'] == true, isUrgent: p['isUrgent'] == true, isFeatured: p['isFeatured'] == true,
          listedAt: DateTime.tryParse(p['createdAt']?.toString() ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0))).toList();
    }
    final logs = results[4] as List<Map<String, dynamic>>?;
    if (logs != null) _auditLogs = logs.map((l) => AdminAuditLog(id: l['id'].toString(),
      timestamp: DateTime.parse(l['timestamp'].toString()), actorName: (l['actorName'] ?? '').toString(),
      actorRole: (l['actorRole'] ?? '').toString(), action: (l['action'] ?? '').toString(), target: (l['target'] ?? '').toString(),
      ipAddress: (l['ipAddress'] ?? '').toString(), details: (l['details'] ?? '').toString())).toList();
    _sheltersController.add(getShelters()); _usersController.add(getUsers());
    _petsController.add(getPets()); _flaggedPetsController.add(getFlaggedPets()); _auditLogsController.add(getAuditLogs());
    lastSyncError = null;
  }

  Pet _petFromJson(Map<String, dynamic> p) => Pet(id: p['id'].toString(), name: (p['name'] ?? '').toString(),
    species: (p['species'] ?? '').toString(), breed: (p['breed'] ?? '').toString(), ageDisplay: (p['ageDisplay'] ?? '').toString(),
    ageMonths: (p['ageMonths'] as num?)?.toInt() ?? 0, gender: (p['gender'] ?? '').toString(),
    weightKg: (p['weightKg'] as num?)?.toDouble() ?? 0, distanceKm: (p['distanceKm'] as num?)?.toDouble() ?? double.infinity,
    matchScore: (p['matchScore'] as num?)?.toInt() ?? 0, imageUrl: (p['imageUrl'] ?? '').toString(),
    galleryUrls: List<String>.from(p['galleryUrls'] as List? ?? const []), isUrgent: p['isUrgent'] == true,
    isFeatured: p['isFeatured'] == true, isVaccinated: p['isVaccinated'] == true, isNeutered: p['isNeutered'] == true,
    isHouseTrained: p['isHouseTrained'] == true, isKidSafe: p['isKidSafe'] == true, isApartmentFriendly: p['isApartmentFriendly'] == true,
    shelterName: (p['shelterName'] ?? '').toString(), shelterPhone: (p['shelterPhone'] ?? '').toString(),
    shelterAddress: (p['shelterAddress'] ?? '').toString(), story: (p['story'] ?? '').toString(),
    medicalHistory: (p['medicalHistory'] ?? '').toString(), qrHash: (p['qrHash'] ?? '').toString(),
    adoptionStatus: (p['adoptionStatus'] ?? 'available').toString());

  Future<void> _changed(Future<Map<String, dynamic>> action) async {
    await action; // Success means the server acknowledged the write, not a local array mutation.
    try { await refresh(); } catch (e) { lastSyncError = 'Saved on server; refresh failed: $e'; }
  }
  Future<void> approveShelter(String id, {String? notes}) async {
    if (_useSupabase) {
      await AdoptMatchBackend.instance.verifyShelter(id, status: 'approved');
      try { await refresh(); } catch (e) { lastSyncError = e.toString(); }
      return;
    }
    return _changed(_request('PATCH', '/shelters/$id/approve', {'notes': notes}));
  }

  Future<void> rejectShelter(String id, {required String reason}) async {
    if (_useSupabase) {
      await AdoptMatchBackend.instance.verifyShelter(id, status: 'rejected');
      try { await refresh(); } catch (e) { lastSyncError = e.toString(); }
      return;
    }
    return _changed(_request('PATCH', '/shelters/$id/reject', {'reason': reason}));
  }

  Future<void> blockUser(String id, {String? reason}) async {
    if (_useSupabase) {
      await AdoptMatchBackend.instance.setAccountStatus(id, 'banned');
      try { await refresh(); } catch (e) { lastSyncError = e.toString(); }
      return;
    }
    return _changed(_request('PATCH', '/users/$id/block', {'reason': reason}));
  }

  Future<void> unblockUser(String id) async {
    if (_useSupabase) {
      await AdoptMatchBackend.instance.setAccountStatus(id, 'active');
      try { await refresh(); } catch (e) { lastSyncError = e.toString(); }
      return;
    }
    return _changed(_request('PATCH', '/users/$id/unblock', {}));
  }

  Future<void> updateUserStatus(String id, String status) =>
      status.toUpperCase() == 'BANNED' ? blockUser(id) : unblockUser(id);

  Future<void> updateUserRole(String id, UserRole role, {List<String>? permissions}) async {
    if (_useSupabase) {
      await AdoptMatchBackend.instance.setUserRole(id, role.code);
      try { await refresh(); } catch (e) { lastSyncError = e.toString(); }
      return;
    }
    return _changed(_request('PATCH', '/users/$id/role', {'role': role.code, 'permissions': permissions ?? const []}));
  }

  Future<void> updateUserPermissions(String id, List<String> permissions) async {
    if (_useSupabase) {
      try { await refresh(); } catch (e) { lastSyncError = e.toString(); }
      return;
    }
    return _changed(_request('PATCH', '/users/$id/permissions', {'permissions': permissions}));
  }

  Future<void> banPetListing(String id) async {
    if (_useSupabase) {
      await AdoptMatchBackend.instance.moderateListing(id, status: 'rejected', reason: 'Banned by admin');
      try { await refresh(); } catch (e) { lastSyncError = e.toString(); }
      return;
    }
    return _changed(_request('PATCH', '/pets/$id/ban', {}));
  }

  Future<void> togglePetBadge(String id, {bool? isUrgent, bool? isFeatured}) async {
    if (_useSupabase) {
      await Supabase.instance.client.from('pets').update({
        if (isUrgent != null) 'is_urgent': isUrgent,
        if (isFeatured != null) 'is_featured': isFeatured,
      }).eq('id', id);
      try { await refresh(); } catch (e) { lastSyncError = e.toString(); }
      return;
    }
    return _changed(_request('PATCH', '/pets/$id/badge', {if (isUrgent != null) 'isUrgent': isUrgent, if (isFeatured != null) 'isFeatured': isFeatured}));
  }

  Future<void> deletePetListing(String id, {String? petName}) async {
    if (_useSupabase) {
      await Supabase.instance.client.from('pets').delete().eq('id', id);
      try { await refresh(); } catch (e) { lastSyncError = e.toString(); }
      return;
    }
    return _changed(_request('DELETE', '/pets/$id'));
  }

  Map<String, dynamic> _petPayload(Pet pet) => {'name': pet.name, 'species': pet.species, 'breed': pet.breed,
    'ageDisplay': pet.ageDisplay, 'ageMonths': pet.ageMonths, 'gender': pet.gender, 'weightKg': pet.weightKg,
    'images': pet.galleryUrls, 'imageUrl': pet.imageUrl, 'story': pet.story, 'medicalHistory': pet.medicalHistory,
    'shelterName': pet.shelterName, 'shelterAddress': pet.shelterAddress, 'isVaccinated': pet.isVaccinated,
    'isNeutered': pet.isNeutered, 'isHouseTrained': pet.isHouseTrained, 'isKidSafe': pet.isKidSafe,
    'isApartmentFriendly': pet.isApartmentFriendly, 'isUrgent': pet.isUrgent, 'isFeatured': pet.isFeatured};
  Future<Pet> createPetListing(Pet pet) async {
    final result = await _request('POST', '/pets', _petPayload(pet));
    final saved = _petFromJson(Map<String, dynamic>.from(result['data'] as Map));
    try { await refresh(); } catch (e) { lastSyncError = e.toString(); }
    return saved;
  }
  Future<void> overridePetListing(Pet pet, {String? notes}) =>
      _changed(_request('PUT', '/pets/${pet.id}', {..._petPayload(pet), 'adminOverrideNotes': notes}));
}
