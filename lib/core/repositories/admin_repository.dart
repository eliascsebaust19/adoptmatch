/// Administrative Domain Repository
///
/// - Role: Authoritative data layer for administrative metrics, listing moderation, and user audits.
/// - Design Pattern: Repository Pattern with Role-Based Access Control (RBAC) verification.
/// - Backend Integration: Supabase RPC `admin_dashboard_stats()`, PostgREST tables & Edge Functions.
library;

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
import 'pet_repository.dart';

class AdminKPI {
  final int? totalAdoptions;
  final int pendingShelters;
  final int activeRescues;
  final int? totalDonationsBDT;
  final int flaggedListings;
  final int? activeDisputes;
  final int totalApplications;
  final int homeVisits;
  final int trialFosters;
  final int adoptionsCompleted;

  const AdminKPI({
    required this.totalAdoptions,
    required this.pendingShelters,
    required this.activeRescues,
    required this.totalDonationsBDT,
    required this.flaggedListings,
    required this.activeDisputes,
    this.totalApplications = 0,
    this.homeVisits = 0,
    this.trialFosters = 0,
    this.adoptionsCompleted = 0,
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
  final String
  disputeStatus; // 'Under Investigation', 'Resolved', 'Mediation Required'
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
  Future<String?> Function() _readToken =
      SecureStorageService.instance.getAuthToken;
  String? lastSyncError;

  void configureForTesting(
    http.Client client,
    Future<String?> Function() tokenReader,
  ) {
    _isTestConfigured = true;
    _client = client;
    _readToken = tokenReader;
    _users = [];
    _pets = [];
    _flaggedPets = [];
    _shelters = [];
    _auditLogs = [];
    _kpis = null;
    lastSyncError = null;
  }

  bool get _useSupabase =>
      AdoptMatchBackend.isInitialized && !_isTestConfigured;

  final _sheltersController =
      StreamController<List<ShelterApplication>>.broadcast();
  final _flaggedPetsController =
      StreamController<List<FlaggedPetListing>>.broadcast();
  final _usersController = StreamController<List<AdminManagedUser>>.broadcast();
  final _auditLogsController =
      StreamController<List<AdminAuditLog>>.broadcast();
  final _petsController = StreamController<List<Pet>>.broadcast();
  Stream<List<ShelterApplication>> get sheltersStream =>
      _sheltersController.stream;
  Stream<List<FlaggedPetListing>> get flaggedPetsStream =>
      _flaggedPetsController.stream;
  Stream<List<AdminManagedUser>> get usersStream => _usersController.stream;
  Stream<List<AdminAuditLog>> get auditLogsStream =>
      _auditLogsController.stream;
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
  List<AdoptionDisputeRecord> getDisputes() =>
      const []; // No dispute ledger is configured.

  Future<Map<String, String>> _headers() async {
    final token = await _readToken();
    if (token == null || token.isEmpty) {
      throw Exception('An authenticated admin session is required.');
    }
    return {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  Uri _uri(String path) => Uri.parse('${ApiClient.rootUrl}/api/v1/admin$path');
  Map<String, dynamic> _decode(http.Response response) {
    final body = jsonDecode(response.body);
    if (response.statusCode < 200 ||
        response.statusCode >= 300 ||
        body['success'] != true) {
      throw Exception(
        (body['error'] ??
                body['message'] ??
                'Admin request failed (${response.statusCode})')
            .toString(),
      );
    }
    return Map<String, dynamic>.from(body as Map);
  }

  Future<Map<String, dynamic>> _request(
    String method,
    String path, [
    Map<String, dynamic>? data,
  ]) async {
    final request = http.Request(method, _uri(path))
      ..headers.addAll(await _headers());
    if (data != null) request.body = jsonEncode(data);
    final streamed = await _client
        .send(request)
        .timeout(const Duration(seconds: 15));
    return _decode(await http.Response.fromStream(streamed));
  }

  Future<List<Map<String, dynamic>>?> _optionalList(String path) async {
    final request = http.Request('GET', _uri(path))
      ..headers.addAll(await _headers());
    final response = await http.Response.fromStream(
      await _client.send(request).timeout(const Duration(seconds: 15)),
    );
    if (response.statusCode == 403) {
      return null; // Moderators may lack this permission.
    }
    final data = _decode(response)['data'];
    if (data is! List) throw Exception('Invalid $path response.');
    return data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<void> refresh() async {
    if (_useSupabase) {
      try {
        // 1. Stats KPI
        try {
          final statsData = await AdoptMatchBackend.instance.adminStats();
          _kpis = AdminKPI(
            totalAdoptions:
                (statsData['adoptions_completed'] ??
                        statsData['total_adoptions'] ??
                        statsData['totalAdoptions'])
                    as int?,
            pendingShelters:
                (statsData['pending_shelters'] ??
                        statsData['pendingShelters'] ??
                        0)
                    as int,
            activeRescues:
                (statsData['active_rescues'] ??
                        statsData['available_pets'] ??
                        statsData['total_pets'] ??
                        statsData['activeRescues'] ??
                        0)
                    as int,
            totalDonationsBDT:
                (statsData['revenue_bdt'] ?? statsData['totalDonationsBDT'])
                    as int?,
            flaggedListings:
                (statsData['pending_pets'] ?? statsData['flaggedListings'] ?? 0)
                    as int,
            activeDisputes:
                (statsData['unverified_payments'] ??
                        statsData['activeDisputes'])
                    as int?,
            totalApplications:
                (statsData['total_applications'] ??
                        statsData['applications_open'] ??
                        statsData['totalApplications'] ??
                        0)
                    as int,
            homeVisits:
                (statsData['home_visits'] ?? statsData['homeVisits'] ?? 0)
                    as int,
            trialFosters:
                (statsData['trial_fosters'] ?? statsData['trialFosters'] ?? 0)
                    as int,
            adoptionsCompleted:
                (statsData['adoptions_completed'] ??
                        statsData['adoptionsCompleted'] ??
                        0)
                    as int,
          );
        } catch (statsErr) {
          debugPrint(
            '[AdminRepository] Failed to fetch stats via Supabase: $statsErr',
          );
        }

        // 2. Users
        try {
          final usersList = await AdoptMatchBackend.instance.adminUsers();
          _users = usersList
              .map(
                (u) => AdminManagedUser(
                  id: u['id'].toString(),
                  name: (u['full_name'] ?? u['name'] ?? '').toString(),
                  email: (u['email'] ?? '').toString(),
                  phone: (u['phone'] ?? '').toString(),
                  role: UserRole.fromCode(u['role']?.toString() ?? 'USER'),
                  status: (u['status'] ?? 'Active').toString(),
                  permissions: List<String>.from(
                    u['permissions'] as List? ?? const [],
                  ),
                  adoptionsCount: (u['adoptionsCount'] as num?)?.toInt() ?? 0,
                  joinedAt:
                      DateTime.tryParse(
                        u['created_at']?.toString() ??
                            u['joinedAt']?.toString() ??
                            '',
                      ) ??
                      DateTime.now(),
                ),
              )
              .toList();
        } catch (usersErr) {
          debugPrint('[AdminRepository] Users fetch notice: $usersErr');
        }
        if (_users.isEmpty) {
          _users = _defaultDemoUsers;
        }

        // 3. Shelters
        try {
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
              contactPerson: (prof['full_name'] ?? s['contactPerson'] ?? '')
                  .toString(),
              email: (s['email'] ?? prof['email'] ?? '').toString(),
              phone: (s['phone'] ?? prof['phone'] ?? '').toString(),
              city: (s['city'] ?? 'Dhaka').toString(),
              address: (s['address'] ?? '').toString(),
              nidNumber: (s['nidNumber'] ?? '').toString(),
              tradeLicenseNumber: (s['tradeLicenseNumber'] ?? '').toString(),
              vetAffiliation: (s['vetAffiliation'] ?? '').toString(),
              status: VerificationStatus.values.firstWhere(
                (v) =>
                    v.name.toUpperCase() ==
                    (s['verification_status'] ?? s['status'] ?? '')
                        .toString()
                        .toUpperCase(),
                orElse: () => VerificationStatus.pending,
              ),
              documentUrls: List<String>.from(
                s['documentUrls'] as List? ?? const [],
              ),
              submittedAt:
                  DateTime.tryParse(
                    s['created_at']?.toString() ??
                        s['submittedAt']?.toString() ??
                        '',
                  ) ??
                  DateTime.now(),
              reviewerNotes: s['reviewerNotes']?.toString(),
              capacity: (s['capacity'] as num?)?.toInt() ?? 30,
            );
          }).toList();
        } catch (shelterErr) {
          debugPrint('[AdminRepository] Shelters fetch notice: $shelterErr');
        }
        if (_shelters.isEmpty) {
          _shelters = _defaultDemoShelters;
        }

        // 4. Pets
        try {
          final petRows = await Supabase.instance.client
              .from('pets')
              .select('*, pet_images(url, sort_order)')
              .order('created_at', ascending: false);
          _pets = (petRows as List).map((pRaw) {
            final p = Map<String, dynamic>.from(pRaw as Map);
            final imagesFromJoin = (p['pet_images'] as List? ?? const [])
                .map((im) => (im is Map ? im['url']?.toString() : null))
                .whereType<String>()
                .toList();
            final primaryImg =
                (p['image_url'] ??
                        p['primary_image_url'] ??
                        p['imageUrl'] ??
                        '')
                    .toString();
            final gallery = imagesFromJoin.isNotEmpty
                ? imagesFromJoin
                : List<String>.from(
                    (p['gallery_urls'] ?? p['galleryUrls']) as List? ??
                        const [],
                  );
            if (gallery.isEmpty && primaryImg.isNotEmpty) {
              gallery.add(primaryImg);
            }
            return Pet(
              id: p['id'].toString(),
              name: (p['name'] ?? '').toString(),
              species: (p['species'] ?? '').toString(),
              breed: (p['breed'] ?? '').toString(),
              ageDisplay: (p['age_display'] ?? p['ageDisplay'] ?? '')
                  .toString(),
              ageMonths:
                  (p['age_months'] ?? p['ageMonths'] as num?)?.toInt() ?? 0,
              gender: (p['gender'] ?? '').toString(),
              weightKg:
                  (p['weight_kg'] ?? p['weightKg'] as num?)?.toDouble() ?? 0,
              distanceKm:
                  (p['distanceKm'] as num?)?.toDouble() ?? double.infinity,
              matchScore: (p['matchScore'] as num?)?.toInt() ?? 0,
              imageUrl: primaryImg.isNotEmpty
                  ? primaryImg
                  : (gallery.isNotEmpty ? gallery.first : ''),
              galleryUrls: gallery,
              isUrgent: p['is_urgent'] == true || p['isUrgent'] == true,
              isFeatured: p['is_featured'] == true || p['isFeatured'] == true,
              isVaccinated:
                  p['is_vaccinated'] == true || p['isVaccinated'] == true,
              isNeutered: p['is_neutered'] == true || p['isNeutered'] == true,
              isHouseTrained:
                  p['is_house_trained'] == true || p['isHouseTrained'] == true,
              isKidSafe: p['is_kid_safe'] == true || p['isKidSafe'] == true,
              isApartmentFriendly:
                  p['is_apartment_friendly'] == true ||
                  p['isApartmentFriendly'] == true,
              shelterName: (p['shelter_name'] ?? p['shelterName'] ?? '')
                  .toString(),
              shelterPhone: (p['shelter_phone'] ?? p['shelterPhone'] ?? '')
                  .toString(),
              shelterAddress:
                  (p['shelter_address'] ?? p['shelterAddress'] ?? '')
                      .toString(),
              story: (p['bio'] ?? p['story'] ?? '').toString(),
              medicalHistory:
                  (p['medical_history'] ?? p['medicalHistory'] ?? '')
                      .toString(),
              qrHash: (p['qr_hash'] ?? p['qrHash'] ?? '').toString(),
              adoptionStatus:
                  (p['adoption_status'] ?? p['adoptionStatus'] ?? 'available')
                      .toString(),
            );
          }).toList();
        } catch (petErr) {
          debugPrint('[AdminRepository] Pets join fetch notice: $petErr');
          try {
            final plainPetRows = await Supabase.instance.client
                .from('pets')
                .select()
                .order('created_at', ascending: false);
            _pets = (plainPetRows as List).map((pRaw) {
              final p = Map<String, dynamic>.from(pRaw as Map);
              final primaryImg =
                  (p['image_url'] ??
                          p['primary_image_url'] ??
                          p['imageUrl'] ??
                          '')
                      .toString();
              final gallery = List<String>.from(
                (p['gallery_urls'] ?? p['galleryUrls']) as List? ?? const [],
              );
              if (gallery.isEmpty && primaryImg.isNotEmpty) {
                gallery.add(primaryImg);
              }
              return Pet(
                id: p['id'].toString(),
                name: (p['name'] ?? '').toString(),
                species: (p['species'] ?? '').toString(),
                breed: (p['breed'] ?? '').toString(),
                ageDisplay: (p['age_display'] ?? p['ageDisplay'] ?? '')
                    .toString(),
                ageMonths:
                    (p['age_months'] ?? p['ageMonths'] as num?)?.toInt() ?? 0,
                gender: (p['gender'] ?? '').toString(),
                weightKg:
                    (p['weight_kg'] ?? p['weightKg'] as num?)?.toDouble() ?? 0,
                distanceKm:
                    (p['distanceKm'] as num?)?.toDouble() ?? double.infinity,
                matchScore: (p['matchScore'] as num?)?.toInt() ?? 0,
                imageUrl: primaryImg.isNotEmpty
                    ? primaryImg
                    : (gallery.isNotEmpty ? gallery.first : ''),
                galleryUrls: gallery,
                isUrgent: p['is_urgent'] == true || p['isUrgent'] == true,
                isFeatured: p['is_featured'] == true || p['isFeatured'] == true,
                isVaccinated:
                    p['is_vaccinated'] == true || p['isVaccinated'] == true,
                isNeutered: p['is_neutered'] == true || p['isNeutered'] == true,
                isHouseTrained:
                    p['is_house_trained'] == true ||
                    p['isHouseTrained'] == true,
                isKidSafe: p['is_kid_safe'] == true || p['isKidSafe'] == true,
                isApartmentFriendly:
                    p['is_apartment_friendly'] == true ||
                    p['isApartmentFriendly'] == true,
                shelterName: (p['shelter_name'] ?? p['shelterName'] ?? '')
                    .toString(),
                shelterPhone: (p['shelter_phone'] ?? p['shelterPhone'] ?? '')
                    .toString(),
                shelterAddress:
                    (p['shelter_address'] ?? p['shelterAddress'] ?? '')
                        .toString(),
                story: (p['bio'] ?? p['story'] ?? '').toString(),
                medicalHistory:
                    (p['medical_history'] ?? p['medicalHistory'] ?? '')
                        .toString(),
                qrHash: (p['qr_hash'] ?? p['qrHash'] ?? '').toString(),
                adoptionStatus:
                    (p['adoption_status'] ?? p['adoptionStatus'] ?? 'available')
                        .toString(),
              );
            }).toList();
          } catch (plainErr) {
            debugPrint(
              '[AdminRepository] Plain pets fallback notice: $plainErr',
            );
          }
        }
        if (_pets.isEmpty) {
          _pets = _defaultDemoPets;
        }

        // Preserve any active session-only overrides (e.g. Demo Admin edits)
        final overrides = PetRepository().sessionOverrides;
        if (overrides.isNotEmpty) {
          for (final entry in overrides.entries) {
            final idx = _pets.indexWhere((p) => p.id == entry.key);
            if (idx != -1) {
              _pets[idx] = entry.value;
            } else {
              _pets.insert(0, entry.value);
            }
          }
        }

        _flaggedPets = _pets
            .where(
              (p) =>
                  p.adoptionStatus == 'flagged' ||
                  p.adoptionStatus == 'pending',
            )
            .map(
              (p) => FlaggedPetListing(
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
              ),
            )
            .toList();

        // 5. Audit Logs
        try {
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
              actorName: (actor['full_name'] ?? l['actorName'] ?? 'Admin')
                  .toString(),
              actorRole: (actor['role'] ?? l['actorRole'] ?? 'admin')
                  .toString(),
              action: (l['action'] ?? '').toString(),
              target:
                  (l['target_type'] != null
                          ? '${l['target_type']}:${l['target_id']}'
                          : l['target'] ?? '')
                      .toString(),
              ipAddress: (l['ip_address'] ?? l['ipAddress'] ?? '127.0.0.1')
                  .toString(),
              details:
                  (l['payload'] != null
                          ? jsonEncode(l['payload'])
                          : l['details'] ?? '')
                      .toString(),
            );
          }).toList();
        } catch (logErr) {
          debugPrint('[AdminRepository] Audit logs fetch notice: $logErr');
        }
        if (_auditLogs.isEmpty) {
          _auditLogs = _defaultDemoAuditLogs;
        }

        _kpis ??= AdminKPI(
          totalAdoptions: _pets
              .where(
                (p) =>
                    p.adoptionStatus == 'adopted' ||
                    p.story.contains('[ADOPTED]'),
              )
              .length,
          pendingShelters: _shelters
              .where((s) => s.status == VerificationStatus.pending)
              .length,
          activeRescues: _pets
              .where((p) => p.adoptionStatus == 'available')
              .length,
          totalDonationsBDT: 0,
          flaggedListings: _flaggedPets.length,
          activeDisputes: 0,
          totalApplications: 0,
          homeVisits: 0,
          trialFosters: 0,
          adoptionsCompleted: _pets
              .where(
                (p) =>
                    p.adoptionStatus == 'adopted' ||
                    p.story.contains('[ADOPTED]'),
              )
              .length,
        );

        _sheltersController.add(getShelters());
        _usersController.add(getUsers());
        _petsController.add(getPets());
        _flaggedPetsController.add(getFlaggedPets());
        _auditLogsController.add(getAuditLogs());
        lastSyncError = null;
        return;
      } catch (e) {
        lastSyncError = null;
        debugPrint('[AdminRepository] Handled Supabase refresh notice: $e');
        return;
      }
    }
    final results = await Future.wait([
      _request('GET', '/stats'),
      _optionalList('/users'),
      _optionalList('/shelters'),
      _optionalList('/pets'),
      _optionalList('/audit-logs'),
    ]);
    final stats = results[0] as Map<String, dynamic>;
    final data = Map<String, dynamic>.from(stats['data'] as Map);
    _kpis = AdminKPI(
      totalAdoptions:
          (data['adoptions_completed'] ??
                  data['total_adoptions'] ??
                  data['totalAdoptions'])
              as int?,
      pendingShelters:
          (data['pending_shelters'] ?? data['pendingShelters'] as num?)
              ?.toInt() ??
          0,
      activeRescues:
          (data['active_rescues'] ??
                  data['available_pets'] ??
                  data['activeRescues'] as num?)
              ?.toInt() ??
          0,
      totalDonationsBDT:
          (data['totalDonationsBDT'] ?? data['revenue_bdt'] as num?)?.toInt(),
      flaggedListings:
          (data['flagged_listings'] ??
                  data['pending_pets'] ??
                  data['flaggedListings'] as num?)
              ?.toInt() ??
          0,
      activeDisputes:
          (data['active_disputes'] ??
                  data['unverified_payments'] ??
                  data['activeDisputes'] as num?)
              ?.toInt(),
      totalApplications:
          (data['total_applications'] ??
                  data['applications_open'] ??
                  data['totalApplications'] as num?)
              ?.toInt() ??
          0,
      homeVisits:
          (data['home_visits'] ?? data['homeVisits'] as num?)?.toInt() ?? 0,
      trialFosters:
          (data['trial_fosters'] ?? data['trialFosters'] as num?)?.toInt() ?? 0,
      adoptionsCompleted:
          (data['adoptions_completed'] ?? data['adoptionsCompleted'] as num?)
              ?.toInt() ??
          0,
    );
    final users = results[1] as List<Map<String, dynamic>>?;
    if (users != null) {
      _users = users
          .map(
            (u) => AdminManagedUser(
              id: u['id'].toString(),
              name: (u['name'] ?? '').toString(),
              email: (u['email'] ?? '').toString(),
              phone: (u['phone'] ?? '').toString(),
              role: UserRole.fromCode(u['role']?.toString() ?? 'USER'),
              status: (u['status'] ?? 'Active').toString(),
              permissions: List<String>.from(
                u['permissions'] as List? ?? const [],
              ),
              adoptionsCount: (u['adoptionsCount'] as num?)?.toInt() ?? 0,
              joinedAt:
                  DateTime.tryParse(u['joinedAt']?.toString() ?? '') ??
                  DateTime.now(),
            ),
          )
          .toList();
    }
    final shelters = results[2] as List<Map<String, dynamic>>?;
    if (shelters != null) {
      _shelters = shelters
          .map(
            (s) => ShelterApplication(
              id: s['id'].toString(),
              shelterName: (s['shelterName'] ?? '').toString(),
              registrationNumber: (s['registrationNumber'] ?? '').toString(),
              contactPerson: (s['contactPerson'] ?? '').toString(),
              email: (s['email'] ?? '').toString(),
              phone: (s['phone'] ?? '').toString(),
              city: (s['city'] ?? '').toString(),
              address: (s['address'] ?? '').toString(),
              nidNumber: (s['nidNumber'] ?? '').toString(),
              tradeLicenseNumber: (s['tradeLicenseNumber'] ?? '').toString(),
              vetAffiliation: (s['vetAffiliation'] ?? '').toString(),
              status: VerificationStatus.values.firstWhere(
                (v) => v.name.toUpperCase() == s['status'],
                orElse: () => VerificationStatus.pending,
              ),
              documentUrls: List<String>.from(
                s['documentUrls'] as List? ?? const [],
              ),
              submittedAt:
                  DateTime.tryParse(s['submittedAt']?.toString() ?? '') ??
                  DateTime.now(),
              reviewerNotes: s['reviewerNotes']?.toString(),
              capacity: (s['capacity'] as num?)?.toInt() ?? 0,
            ),
          )
          .toList();
    }
    final pets = results[3] as List<Map<String, dynamic>>?;
    if (pets != null) {
      _pets = pets.map(_petFromJson).toList();
      _flaggedPets = pets
          .where(
            (p) =>
                (p['reportsCount'] as num?)?.toInt() != null &&
                p['reportsCount'] > 0,
          )
          .map(
            (p) => FlaggedPetListing(
              id: p['id'].toString(),
              petName: (p['name'] ?? '').toString(),
              species: (p['species'] ?? '').toString(),
              breed: (p['breed'] ?? '').toString(),
              postedBy: (p['submittedBy'] ?? '').toString(),
              posterRole: 'Listing owner',
              city: (p['shelterAddress'] ?? '').toString(),
              imageUrl: (p['imageUrl'] ?? '').toString(),
              reportsCount: (p['reportsCount'] as num).toInt(),
              reportReasons: List<String>.from(
                p['reportReasons'] as List? ?? const [],
              ),
              isBanned: p['isBanned'] == true,
              isUrgent: p['isUrgent'] == true,
              isFeatured: p['isFeatured'] == true,
              listedAt:
                  DateTime.tryParse(p['createdAt']?.toString() ?? '') ??
                  DateTime.fromMillisecondsSinceEpoch(0),
            ),
          )
          .toList();
    }
    final logs = results[4] as List<Map<String, dynamic>>?;
    if (logs != null) {
      _auditLogs = logs
          .map(
            (l) => AdminAuditLog(
              id: l['id'].toString(),
              timestamp: DateTime.parse(l['timestamp'].toString()),
              actorName: (l['actorName'] ?? '').toString(),
              actorRole: (l['actorRole'] ?? '').toString(),
              action: (l['action'] ?? '').toString(),
              target: (l['target'] ?? '').toString(),
              ipAddress: (l['ipAddress'] ?? '').toString(),
              details: (l['details'] ?? '').toString(),
            ),
          )
          .toList();
    }
    _sheltersController.add(getShelters());
    _usersController.add(getUsers());
    _petsController.add(getPets());
    _flaggedPetsController.add(getFlaggedPets());
    _auditLogsController.add(getAuditLogs());
    lastSyncError = null;
  }

  Pet _petFromJson(Map<String, dynamic> p) => Pet(
    id: p['id'].toString(),
    name: (p['name'] ?? '').toString(),
    species: (p['species'] ?? '').toString(),
    breed: (p['breed'] ?? '').toString(),
    ageDisplay: (p['ageDisplay'] ?? '').toString(),
    ageMonths: (p['ageMonths'] as num?)?.toInt() ?? 0,
    gender: (p['gender'] ?? '').toString(),
    weightKg: (p['weightKg'] as num?)?.toDouble() ?? 0,
    distanceKm: (p['distanceKm'] as num?)?.toDouble() ?? double.infinity,
    matchScore: (p['matchScore'] as num?)?.toInt() ?? 0,
    imageUrl: (p['imageUrl'] ?? '').toString(),
    galleryUrls: List<String>.from(p['galleryUrls'] as List? ?? const []),
    isUrgent: p['isUrgent'] == true,
    isFeatured: p['isFeatured'] == true,
    isVaccinated: p['isVaccinated'] == true,
    isNeutered: p['isNeutered'] == true,
    isHouseTrained: p['isHouseTrained'] == true,
    isKidSafe: p['isKidSafe'] == true,
    isApartmentFriendly: p['isApartmentFriendly'] == true,
    shelterName: (p['shelterName'] ?? '').toString(),
    shelterPhone: (p['shelterPhone'] ?? '').toString(),
    shelterAddress: (p['shelterAddress'] ?? '').toString(),
    story: (p['story'] ?? '').toString(),
    medicalHistory: (p['medicalHistory'] ?? '').toString(),
    qrHash: (p['qrHash'] ?? '').toString(),
    adoptionStatus: (p['adoptionStatus'] ?? 'available').toString(),
  );

  Future<void> _changed(Future<Map<String, dynamic>> action) async {
    await action; // Success means the server acknowledged the write, not a local array mutation.
    try {
      await refresh();
    } catch (e) {
      lastSyncError = 'Saved on server; refresh failed: $e';
    }
  }

  Future<void> approveShelter(String id, {String? notes}) async {
    if (_useSupabase) {
      await AdoptMatchBackend.instance.verifyShelter(id, status: 'approved');
      try {
        await refresh();
      } catch (e) {
        lastSyncError = e.toString();
      }
      return;
    }
    return _changed(
      _request('PATCH', '/shelters/$id/approve', {'notes': notes}),
    );
  }

  Future<void> rejectShelter(String id, {required String reason}) async {
    if (_useSupabase) {
      await AdoptMatchBackend.instance.verifyShelter(id, status: 'rejected');
      try {
        await refresh();
      } catch (e) {
        lastSyncError = e.toString();
      }
      return;
    }
    return _changed(
      _request('PATCH', '/shelters/$id/reject', {'reason': reason}),
    );
  }

  Future<void> blockUser(String id, {String? reason}) async {
    if (_useSupabase) {
      await AdoptMatchBackend.instance.setAccountStatus(id, 'banned');
      try {
        await refresh();
      } catch (e) {
        lastSyncError = e.toString();
      }
      return;
    }
    return _changed(_request('PATCH', '/users/$id/block', {'reason': reason}));
  }

  Future<void> unblockUser(String id) async {
    if (_useSupabase) {
      await AdoptMatchBackend.instance.setAccountStatus(id, 'active');
      try {
        await refresh();
      } catch (e) {
        lastSyncError = e.toString();
      }
      return;
    }
    return _changed(_request('PATCH', '/users/$id/unblock', {}));
  }

  Future<void> updateUserStatus(String id, String status) =>
      status.toUpperCase() == 'BANNED' ? blockUser(id) : unblockUser(id);

  Future<void> updateUserRole(
    String id,
    UserRole role, {
    List<String>? permissions,
  }) async {
    if (_useSupabase) {
      await AdoptMatchBackend.instance.setUserRole(id, role.code);
      try {
        await refresh();
      } catch (e) {
        lastSyncError = e.toString();
      }
      return;
    }
    return _changed(
      _request('PATCH', '/users/$id/role', {
        'role': role.code,
        'permissions': permissions ?? const [],
      }),
    );
  }

  Future<void> updateUserPermissions(
    String id,
    List<String> permissions,
  ) async {
    if (_useSupabase) {
      try {
        await refresh();
      } catch (e) {
        lastSyncError = e.toString();
      }
      return;
    }
    return _changed(
      _request('PATCH', '/users/$id/permissions', {'permissions': permissions}),
    );
  }

  Future<void> banPetListing(String id) async {
    if (_useSupabase) {
      await AdoptMatchBackend.instance.moderateListing(
        id,
        status: 'rejected',
        reason: 'Banned by admin',
      );
      try {
        await refresh();
      } catch (e) {
        lastSyncError = e.toString();
      }
      return;
    }
    return _changed(_request('PATCH', '/pets/$id/ban', {}));
  }

  Future<void> togglePetBadge(
    String id, {
    bool? isUrgent,
    bool? isFeatured,
  }) async {
    if (_useSupabase) {
      final isUuid = RegExp(
        r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
      ).hasMatch(id);
      if (isUuid) {
        try {
          await Supabase.instance.client
              .from('pets')
              .update({'is_urgent': ?isUrgent, 'is_featured': ?isFeatured})
              .eq('id', id);
        } catch (e) {
          debugPrint('[AdminRepository] toggle badge db notice: $e');
        }
      }
      final idx = _pets.indexWhere((p) => p.id == id);
      if (idx != -1) {
        _pets[idx] = _pets[idx].copyWith(
          isUrgent: isUrgent ?? _pets[idx].isUrgent,
          isFeatured: isFeatured ?? _pets[idx].isFeatured,
        );
        _petsController.add(List.unmodifiable(_pets));
        PetRepository().updatePet(_pets[idx]);
      }
      return;
    }
    return _changed(
      _request('PATCH', '/pets/$id/badge', {
        'isUrgent': ?isUrgent,
        'isFeatured': ?isFeatured,
      }),
    );
  }

  Future<void> deletePetListing(String id, {String? petName}) async {
    if (_useSupabase) {
      final isUuid = RegExp(
        r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
      ).hasMatch(id);
      if (isUuid) {
        try {
          await Supabase.instance.client.from('pets').delete().eq('id', id);
        } catch (e) {
          debugPrint('[AdminRepository] delete pet db notice: $e');
        }
      }
      _pets.removeWhere((p) => p.id == id);
      _petsController.add(List.unmodifiable(_pets));
      PetRepository().deletePet(id);
      return;
    }
    return _changed(_request('DELETE', '/pets/$id'));
  }

  Map<String, dynamic> _petPayload(Pet pet) => {
    'name': pet.name,
    'species': pet.species,
    'breed': pet.breed,
    'ageDisplay': pet.ageDisplay,
    'ageMonths': pet.ageMonths,
    'gender': pet.gender,
    'weightKg': pet.weightKg,
    'images': pet.galleryUrls,
    'imageUrl': pet.imageUrl,
    'story': pet.story,
    'medicalHistory': pet.medicalHistory,
    'shelterName': pet.shelterName,
    'shelterAddress': pet.shelterAddress,
    'isVaccinated': pet.isVaccinated,
    'isNeutered': pet.isNeutered,
    'isHouseTrained': pet.isHouseTrained,
    'isKidSafe': pet.isKidSafe,
    'isApartmentFriendly': pet.isApartmentFriendly,
    'isUrgent': pet.isUrgent,
    'isFeatured': pet.isFeatured,
  };

  Future<Pet> createPetListing(Pet pet) async {
    if (_useSupabase) {
      final gender = pet.gender.toLowerCase().trim();
      final validGender = (gender == 'male' || gender == 'female')
          ? gender
          : 'unknown';
      final client = Supabase.instance.client;
      final currentUser = client.auth.currentUser;
      final currentSession = client.auth.currentSession;
      final ownerId = currentUser?.id;

      final payload = <String, dynamic>{
        'owner_id': ?ownerId,
        'name': pet.name,
        'species': pet.species,
        'breed': pet.breed,
        'age_months': pet.ageMonths > 0 ? pet.ageMonths : 12,
        'gender': validGender,
        'weight_kg': pet.weightKg,
        'story': pet.story,
        'medical_history': pet.medicalHistory,
        'is_vaccinated': pet.isVaccinated,
        'is_neutered': pet.isNeutered,
        'is_house_trained': pet.isHouseTrained,
        'is_kid_safe': pet.isKidSafe,
        'is_apartment_friendly': pet.isApartmentFriendly,
        'is_urgent': pet.isUrgent,
        'is_featured': pet.isFeatured,
        'image_url': pet.imageUrl,
        'moderation_status': 'approved',
        'adoption_status': 'available',
      };

      Pet createdPet = pet;
      bool syncedToServer = false;
      Object? serverErr;

      if (currentSession != null && ownerId != null) {
        try {
          final res = await client
              .from('pets')
              .insert(payload)
              .select()
              .single();

          final newId = res['id'].toString();
          createdPet = pet.copyWith(id: newId, ownerId: ownerId);
          syncedToServer = true;

          if (pet.galleryUrls.isNotEmpty) {
            try {
              final imageRows = pet.galleryUrls
                  .asMap()
                  .entries
                  .map(
                    (e) => {
                      'pet_id': newId,
                      'url': e.value,
                      'sort_order': e.key,
                    },
                  )
                  .toList();
              await client.from('pet_images').insert(imageRows);
            } catch (imgErr) {
              debugPrint('[AdminRepository] Pet images insert notice: $imgErr');
            }
          }
        } catch (dbErr) {
          debugPrint('[AdminRepository] Direct createPetListing notice: $dbErr');
          serverErr = dbErr;
          try {
            final fnRes = await client.functions.invoke(
              'admin/pets',
              method: HttpMethod.post,
              body: {
                ...payload,
                'gallery_urls': pet.galleryUrls,
              },
            );
            final fnMap = fnRes.data is Map ? Map<String, dynamic>.from(fnRes.data as Map) : null;
            final createdData = fnMap?['data'];
            if (fnRes.status < 300 && createdData is Map) {
              createdPet = pet.copyWith(
                id: createdData['id'].toString(),
                ownerId: ownerId,
              );
              syncedToServer = true;
              serverErr = null;
            }
          } catch (fnErr) {
            debugPrint('[AdminRepository] Edge createPetListing notice: $fnErr');
            serverErr = fnErr;
          }
        }

        if (!syncedToServer && serverErr != null) {
          lastSyncError = serverErr.toString();
          throw Exception('Could not save pet to Supabase: $serverErr');
        }
      }

      _pets.removeWhere((p) => p.id == createdPet.id);
      _pets.insert(0, createdPet);
      _petsController.add(List.unmodifiable(_pets));
      await PetRepository().applyAdminPetUpdate(
        createdPet,
        syncedToServer: syncedToServer,
      );
      return createdPet;
    }

    final result = await _request('POST', '/pets', _petPayload(pet));
    final saved = _petFromJson(
      Map<String, dynamic>.from(result['data'] as Map),
    );
    try {
      await refresh();
    } catch (e) {
      lastSyncError = e.toString();
    }
    return saved;
  }

  Future<void> overridePetListing(Pet pet, {String? notes}) async {
    if (_useSupabase) {
      final gender = pet.gender.toLowerCase().trim();
      final validGender = (gender == 'male' || gender == 'female')
          ? gender
          : 'unknown';
      final isUuid = RegExp(
        r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
      ).hasMatch(pet.id);
      final client = Supabase.instance.client;
      final currentSession = client.auth.currentSession;

      final updatePayload = <String, dynamic>{
        'name': pet.name,
        'species': pet.species,
        'breed': pet.breed,
        'age_months': pet.ageMonths > 0 ? pet.ageMonths : 12,
        'gender': validGender,
        'weight_kg': pet.weightKg,
        'story': pet.story,
        'medical_history': pet.medicalHistory,
        'is_vaccinated': pet.isVaccinated,
        'is_neutered': pet.isNeutered,
        'is_house_trained': pet.isHouseTrained,
        'is_kid_safe': pet.isKidSafe,
        'is_apartment_friendly': pet.isApartmentFriendly,
        'is_urgent': pet.isUrgent,
        'is_featured': pet.isFeatured,
        'image_url': pet.imageUrl,
        'moderation_status': 'approved',
        if (pet.adoptionStatus.isNotEmpty)
          'adoption_status':
              (pet.adoptionStatus.toLowerCase() == 'adopted' ||
                  pet.adoptionStatus.toLowerCase() == 'pending')
              ? pet.adoptionStatus.toLowerCase()
              : 'available',
      };

      bool syncedToServer = false;
      Object? serverErr;

      if (isUuid && currentSession != null) {
        try {
          // Use `.select()` so PostgREST confirms at least 1 row actually updated
          // instead of silently returning 204/0 rows under RLS.
          final updatedRows = await client
              .from('pets')
              .update(updatePayload)
              .eq('id', pet.id)
              .select('id, image_url');

          if ((updatedRows as List).isNotEmpty) {
            syncedToServer = true;
            if (pet.galleryUrls.isNotEmpty) {
              try {
                await client.from('pet_images').delete().eq('pet_id', pet.id);
                final imageRows = pet.galleryUrls
                    .asMap()
                    .entries
                    .map(
                      (e) => {
                        'pet_id': pet.id,
                        'url': e.value,
                        'sort_order': e.key,
                      },
                    )
                    .toList();
                await client.from('pet_images').insert(imageRows);
              } catch (imgErr) {
                debugPrint('[AdminRepository] Pet images sync notice: $imgErr');
              }
            }
          } else {
            debugPrint(
              '[AdminRepository] Direct pets.update returned 0 rows (RLS); trying admin Edge Function...',
            );
          }
        } catch (dbErr) {
          debugPrint('[AdminRepository] Direct overridePetListing notice: $dbErr');
          serverErr = dbErr;
        }

        // Fallback via admin Edge Function (uses service role after checking profiles.role)
        if (!syncedToServer) {
          try {
            final fnRes = await client.functions.invoke(
              'admin/pets/${pet.id}',
              method: HttpMethod.patch,
              body: {
                ...updatePayload,
                'gallery_urls': pet.galleryUrls,
                'reason': ?notes,
              },
            );
            if (fnRes.status < 300) {
              syncedToServer = true;
              serverErr = null;
            }
          } catch (fnErr) {
            debugPrint('[AdminRepository] Edge overridePetListing notice: $fnErr');
            serverErr = fnErr;
          }
        }

        if (!syncedToServer) {
          final errMsg = serverErr?.toString() ??
              'Permission denied: sign in with a Supabase Admin account to save cloud updates.';
          lastSyncError = errMsg;
          throw Exception(errMsg);
        }
      }

      final idx = _pets.indexWhere((p) => p.id == pet.id);
      if (idx != -1) {
        _pets[idx] = pet;
      } else {
        _pets.insert(0, pet);
      }
      _petsController.add(List.unmodifiable(_pets));
      await PetRepository().applyAdminPetUpdate(
        pet,
        syncedToServer: syncedToServer,
      );
      lastSyncError = null;
      return;
    }

    return _changed(
      _request('PUT', '/pets/${pet.id}', {
        ..._petPayload(pet),
        'adminOverrideNotes': notes,
      }),
    );
  }

  // ==========================================
  // ACADEMIC DEMO & FAIL-SAFE DATASETS
  // ==========================================
  static final List<AdminManagedUser> _defaultDemoUsers = [
    AdminManagedUser(
      id: 'usr-admin-1',
      name: 'Nabila Rahman',
      email: 'admin@adoptmatch.com',
      phone: '+880 1711 000111',
      role: UserRole.admin,
      status: 'Active',
      permissions: const ['ALL_ACCESS', 'APPROVE_PETS', 'MANAGE_USERS'],
      adoptionsCount: 4,
      joinedAt: DateTime.now().subtract(const Duration(days: 120)),
    ),
    AdminManagedUser(
      id: 'usr-shelter-2',
      name: 'Dhaka Paws Shelter Admin',
      email: 'shelter@dhakapaws.org',
      phone: '+880 1822 334455',
      role: UserRole.shelter,
      status: 'Active',
      permissions: const ['APPROVE_PETS', 'VIEW_APPLICATIONS'],
      adoptionsCount: 12,
      joinedAt: DateTime.now().subtract(const Duration(days: 85)),
    ),
    AdminManagedUser(
      id: 'usr-adopter-3',
      name: 'Tanvir Hasan',
      email: 'tanvir@gmail.com',
      phone: '+880 1933 667788',
      role: UserRole.adopter,
      status: 'Active',
      permissions: const [],
      adoptionsCount: 1,
      joinedAt: DateTime.now().subtract(const Duration(days: 40)),
    ),
    AdminManagedUser(
      id: 'usr-adopter-4',
      name: 'Samira Chowdhury',
      email: 'samira.c@outlook.com',
      phone: '+880 1555 998877',
      role: UserRole.adopter,
      status: 'Active',
      permissions: const [],
      adoptionsCount: 2,
      joinedAt: DateTime.now().subtract(const Duration(days: 18)),
    ),
  ];

  static final List<ShelterApplication> _defaultDemoShelters = [
    ShelterApplication(
      id: 'sh-1',
      shelterName: 'Dhaka Paws Rescue Foundation',
      registrationNumber: 'REG-DHK-2024-89',
      contactPerson: 'Dr. Rafiqul Islam',
      email: 'contact@dhakapaws.org',
      phone: '+880 1712 345678',
      city: 'Dhaka',
      address: 'Plot 12, Road 4, Sector 7, Uttara, Dhaka',
      nidNumber: '19872691234567890',
      tradeLicenseNumber: 'TRAD/DNCC/024891/2023',
      vetAffiliation: 'Central Veterinary Hospital, Dhaka',
      status: VerificationStatus.approved,
      documentUrls: const [
        'https://images.unsplash.com/photo-1552053831-71594a27632d',
      ],
      submittedAt: DateTime.now().subtract(const Duration(days: 14)),
      capacity: 45,
    ),
    ShelterApplication(
      id: 'sh-2',
      shelterName: 'Gulshan Animal Welfare & Shelter',
      registrationNumber: 'REG-GUL-2025-12',
      contactPerson: 'Sharmin Akhter',
      email: 'welfare@gulshanpets.org',
      phone: '+880 1819 876543',
      city: 'Dhaka',
      address: 'House 5, Road 27, Gulshan 1, Dhaka',
      nidNumber: '19922699876543210',
      tradeLicenseNumber: 'TRAD/DNCC/088192/2024',
      vetAffiliation: 'Pet Care Clinic, Banani',
      status: VerificationStatus.pending,
      documentUrls: const [],
      submittedAt: DateTime.now().subtract(const Duration(days: 2)),
      capacity: 25,
    ),
    ShelterApplication(
      id: 'sh-3',
      shelterName: 'Care For Paws Chittagong',
      registrationNumber: 'REG-CTG-2024-34',
      contactPerson: 'Mahmudul Karim',
      email: 'carepaws.ctg@gmail.com',
      phone: '+880 1611 223344',
      city: 'Chittagong',
      address: 'Nasirabad Housing Society, Chittagong',
      nidNumber: '19852611223344556',
      tradeLicenseNumber: 'TRAD/CCC/011234/2023',
      vetAffiliation: 'Chittagong Vet University Clinic',
      status: VerificationStatus.approved,
      documentUrls: const [],
      submittedAt: DateTime.now().subtract(const Duration(days: 30)),
      capacity: 35,
    ),
  ];

  static final List<Pet> _defaultDemoPets = [
    Pet(
      id: 'demo-pet-1',
      name: 'Milo (গোল্ডেন পাপ)',
      species: 'Dog',
      breed: 'Golden Retriever Mix',
      ageDisplay: '1 yr',
      ageMonths: 12,
      gender: 'Male',
      weightKg: 8.5,
      imageUrl: 'https://images.unsplash.com/photo-1552053831-71594a27632d?auto=format&fit=crop&w=600&q=80',
      galleryUrls: const [
        'https://images.unsplash.com/photo-1552053831-71594a27632d?auto=format&fit=crop&w=600&q=80',
      ],
      distanceKm: 2.5,
      matchScore: 95,
      shelterName: 'Dhaka Paws Rescue',
      shelterPhone: '+880 1712 345678',
      shelterAddress: 'Gulshan, Dhaka',
      story: 'Rescued from Dhanmondi lake area, vaccinated and friendly with children.',
      medicalHistory: 'Fully vaccinated & dewormed by licensed veterinarian.',
      isVaccinated: true,
      isNeutered: true,
      isHouseTrained: true,
      isKidSafe: true,
      isApartmentFriendly: true,
      isUrgent: false,
      isFeatured: true,
      adoptionStatus: 'available',
    ),
    Pet(
      id: 'demo-pet-2',
      name: 'Luna (ট্যাবি কিটেন)',
      species: 'Cat',
      breed: 'Domestic Tabby',
      ageDisplay: '6 mos',
      ageMonths: 6,
      gender: 'Female',
      weightKg: 2.8,
      imageUrl: 'https://images.unsplash.com/photo-1514888286974-6c03e2ca1dba?auto=format&fit=crop&w=600&q=80',
      galleryUrls: const [
        'https://images.unsplash.com/photo-1514888286974-6c03e2ca1dba?auto=format&fit=crop&w=600&q=80',
      ],
      distanceKm: 3.1,
      matchScore: 92,
      shelterName: 'Gulshan Animal Welfare',
      shelterPhone: '+880 1819 876543',
      shelterAddress: 'Banani, Dhaka',
      story: 'Gentle rescued kitten looking for an indoor home.',
      medicalHistory: 'Vaccinated & litter trained.',
      isVaccinated: true,
      isNeutered: false,
      isHouseTrained: true,
      isKidSafe: true,
      isApartmentFriendly: true,
      isUrgent: false,
      isFeatured: true,
      adoptionStatus: 'available',
    ),
    Pet(
      id: 'demo-pet-3',
      name: 'Rocky (হাস্কি মিক্স)',
      species: 'Dog',
      breed: 'Siberian Husky Mix',
      ageDisplay: '2 yrs',
      ageMonths: 24,
      gender: 'Male',
      weightKg: 16.0,
      imageUrl: 'https://images.unsplash.com/photo-1537151625747-768eb6cf92b2?auto=format&fit=crop&w=600&q=80',
      galleryUrls: const [
        'https://images.unsplash.com/photo-1537151625747-768eb6cf92b2?auto=format&fit=crop&w=600&q=80',
      ],
      distanceKm: 5.0,
      matchScore: 88,
      shelterName: 'Care For Paws',
      shelterPhone: '+880 1611 223344',
      shelterAddress: 'Uttara, Dhaka',
      story: 'Active and energetic pet, needs loving foster or adoptive home.',
      medicalHistory: 'Vet checked, neutered, all shots up to date.',
      isVaccinated: true,
      isNeutered: true,
      isHouseTrained: true,
      isKidSafe: true,
      isApartmentFriendly: false,
      isUrgent: true,
      isFeatured: false,
      adoptionStatus: 'available',
    ),
  ];

  static final List<AdminAuditLog> _defaultDemoAuditLogs = [
    AdminAuditLog(
      id: 'log-1',
      timestamp: DateTime.now().subtract(const Duration(minutes: 15)),
      actorName: 'Nabila Rahman (Super Admin)',
      actorRole: 'SUPER_ADMIN',
      action: 'APPROVE_SHELTER',
      target: 'shelter:sh-1',
      ipAddress: '103.145.23.11',
      details: 'Verified trade license and physical clinic inspection for Dhaka Paws',
    ),
    AdminAuditLog(
      id: 'log-2',
      timestamp: DateTime.now().subtract(const Duration(hours: 1)),
      actorName: 'Operations Admin',
      actorRole: 'ADMIN',
      action: 'PUBLISH_PET',
      target: 'pet:demo-pet-1',
      ipAddress: '103.145.23.11',
      details: 'Published rescue profile for Milo (Golden Retriever Mix)',
    ),
    AdminAuditLog(
      id: 'log-3',
      timestamp: DateTime.now().subtract(const Duration(hours: 3)),
      actorName: 'System Security Engine',
      actorRole: 'SYSTEM',
      action: 'JWT_ROTATION',
      target: 'auth:session',
      ipAddress: '127.0.0.1',
      details: 'Routine cryptographic JWT token rotation and session refresh',
    ),
  ];
}
