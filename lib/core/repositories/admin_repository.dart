import 'dart:async';
import '../../features/admin/models/shelter_application_model.dart';
import '../../features/admin/models/admin_pet_moderation_model.dart';
import '../../features/admin/models/admin_audit_log_model.dart';
import '../../features/auth/bloc/auth_bloc.dart';
import '../models/pet_model.dart';
import './pet_repository.dart';

class AdminKPI {
  final int totalAdoptions;
  final int pendingShelters;
  final int activeRescues;
  final int totalDonationsBDT;
  final int flaggedListings;
  final int activeDisputes;

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

class AdminRepository {
  static final AdminRepository _instance = AdminRepository._internal();
  factory AdminRepository() => _instance;

  AdminRepository._internal() {
    _initSeedData();
  }

  final _sheltersController = StreamController<List<ShelterApplication>>.broadcast();
  final _flaggedPetsController = StreamController<List<FlaggedPetListing>>.broadcast();
  final _usersController = StreamController<List<AdminManagedUser>>.broadcast();
  final _auditLogsController = StreamController<List<AdminAuditLog>>.broadcast();

  Stream<List<ShelterApplication>> get sheltersStream => _sheltersController.stream;
  Stream<List<FlaggedPetListing>> get flaggedPetsStream => _flaggedPetsController.stream;
  Stream<List<AdminManagedUser>> get usersStream => _usersController.stream;
  Stream<List<AdminAuditLog>> get auditLogsStream => _auditLogsController.stream;

  List<ShelterApplication> _shelters = [];
  List<FlaggedPetListing> _flaggedPets = [];
  List<AdminManagedUser> _users = [];
  List<AdminAuditLog> _auditLogs = [];
  List<AdoptionDisputeRecord> _disputes = [];

  void _initSeedData() {
    _shelters = [
      ShelterApplication(
        id: 'SH-801',
        shelterName: 'Care For Paws Foundation (Dhaka)',
        registrationNumber: 'REG-DHK-2022-8901',
        contactPerson: 'Zahirul Islam',
        email: 'info@careforpaws.bd',
        phone: '+880 1712 345678',
        city: 'Dhaka',
        address: 'House 42, Road 11, Banani, Dhaka',
        nidNumber: '19892694582910384',
        tradeLicenseNumber: 'TRAD/DNCC/019283/2023',
        vetAffiliation: 'Central Veterinary Hospital, Dhaka',
        status: VerificationStatus.pending,
        documentUrls: [
          'https://images.unsplash.com/photo-1584467735871-8e85353a8413?auto=format&fit=crop&w=600&q=80',
          'https://images.unsplash.com/photo-1544717305-2782549b5136?auto=format&fit=crop&w=600&q=80',
        ],
        submittedAt: DateTime.now().subtract(const Duration(hours: 14)),
        capacity: 45,
      ),
      ShelterApplication(
        id: 'SH-802',
        shelterName: 'Paw Haven Chittagong Animal Sanctuary',
        registrationNumber: 'REG-CTG-2021-4412',
        contactPerson: 'Farhana Kabir',
        email: 'contact@pawhavenctg.org',
        phone: '+880 1819 876543',
        city: 'Chittagong',
        address: '102 Nasirabad Housing Society, Chattogram',
        nidNumber: '19921598432109847',
        tradeLicenseNumber: 'TRAD/CCC/044812/2022',
        vetAffiliation: 'Chittagong Vet & Animal Sciences University',
        status: VerificationStatus.pending,
        documentUrls: [
          'https://images.unsplash.com/photo-1584467735871-8e85353a8413?auto=format&fit=crop&w=600&q=80',
        ],
        submittedAt: DateTime.now().subtract(const Duration(days: 1, hours: 3)),
        capacity: 35,
      ),
      ShelterApplication(
        id: 'SH-803',
        shelterName: 'Sylhet Rescue & Rehabilitation Center',
        registrationNumber: 'REG-SYL-2023-1102',
        contactPerson: 'Ahmed Rezwan',
        email: 'support@sylhetrescues.org',
        phone: '+880 1715 901234',
        city: 'Sylhet',
        address: 'Zindabazar, Amberkhana Road, Sylhet',
        nidNumber: '19875412984532109',
        tradeLicenseNumber: 'TRAD/SCC/011024/2023',
        vetAffiliation: 'Sylhet Agricultural University Clinics',
        status: VerificationStatus.approved,
        documentUrls: [
          'https://images.unsplash.com/photo-1584467735871-8e85353a8413?auto=format&fit=crop&w=600&q=80',
        ],
        submittedAt: DateTime.now().subtract(const Duration(days: 4)),
        reviewerNotes: 'Official NID and Trade License verified with DNCC and DCC records.',
        capacity: 25,
      ),
    ];

    _flaggedPets = [
      FlaggedPetListing(
        id: 'p-fl-1',
        petName: 'Rocky (Golden Retriever)',
        species: 'Dog',
        breed: 'Golden Retriever',
        postedBy: 'Suspicious Seller #401',
        posterRole: 'Individual Rescuer',
        city: 'Dhaka',
        imageUrl: 'https://images.unsplash.com/photo-1558788353-f76d92427f16?auto=format&fit=crop&w=600&q=80',
        reportsCount: 6,
        reportReasons: [
          'Asking adoption fee of ৳25,000 (Commercial Breeding Violation)',
          'Duplicate photos found on external pet store website',
        ],
        isBanned: false,
        isUrgent: false,
        isFeatured: false,
        listedAt: DateTime.now().subtract(const Duration(days: 1)),
      ),
      FlaggedPetListing(
        id: 'p2',
        petName: 'Mochi (Injured Street Cat)',
        species: 'Cat',
        breed: 'Calico',
        postedBy: 'Care For Paws BD',
        posterRole: 'Shelter',
        city: 'Dhaka',
        imageUrl: 'https://images.unsplash.com/photo-1514888286974-6c03e2ca1dba?auto=format&fit=crop&w=600&q=80',
        reportsCount: 1,
        reportReasons: ['Urgent medical surgery fund required'],
        isBanned: false,
        isUrgent: true,
        isFeatured: false,
        listedAt: DateTime.now().subtract(const Duration(days: 2)),
      ),
    ];

    _users = [
      AdminManagedUser(
        id: 'u-101',
        name: 'Elias Ahmed',
        email: 'elias3224@gmail.com',
        phone: '+880 1711 234567',
        role: UserRole.adopter,
        status: 'Active',
        permissions: const [],
        adoptionsCount: 1,
        joinedAt: DateTime.now().subtract(const Duration(days: 120)),
      ),
      AdminManagedUser(
        id: 'u-102',
        name: 'Care For Paws Admin',
        email: 'info@careforpaws.bd',
        phone: '+880 1712 345678',
        role: UserRole.shelter,
        status: 'Active',
        permissions: const ['APPROVE_PETS'],
        adoptionsCount: 38,
        joinedAt: DateTime.now().subtract(const Duration(days: 280)),
      ),
      AdminManagedUser(
        id: 'u-103',
        name: 'Sarah Rahman',
        email: 'superadmin@adoptmatch.org',
        phone: '+880 1819 000001',
        role: UserRole.superAdmin,
        status: 'Active',
        permissions: const ['APPROVE_PETS', 'FLAG_CONTENT', 'REVIEW_APPLICATIONS', 'MANAGE_USERS', 'AUDIT_LOGS'],
        adoptionsCount: 0,
        joinedAt: DateTime.now().subtract(const Duration(days: 450)),
      ),
      AdminManagedUser(
        id: 'u-104',
        name: 'Suspicious Lister 99',
        email: 'petshopdhaka@fake.com',
        phone: '+880 1911 000099',
        role: UserRole.adopter,
        status: 'Banned',
        permissions: const [],
        adoptionsCount: 0,
        joinedAt: DateTime.now().subtract(const Duration(days: 14)),
      ),
      AdminManagedUser(
        id: 'u-105',
        name: 'Tanvir Hossain (Volunteer Lead)',
        email: 'tanvir.mod@adoptmatch.org',
        phone: '+880 1713 999888',
        role: UserRole.moderator,
        status: 'Active',
        permissions: const ['APPROVE_PETS', 'FLAG_CONTENT', 'REVIEW_APPLICATIONS'],
        adoptionsCount: 4,
        joinedAt: DateTime.now().subtract(const Duration(days: 45)),
      ),
    ];

    _auditLogs = [
      AdminAuditLog(
        id: 'LOG-9001',
        timestamp: DateTime.now().subtract(const Duration(minutes: 25)),
        actorName: 'Sarah Rahman',
        actorRole: 'SUPER_ADMIN',
        action: 'APPROVED_SHELTER',
        target: 'SH-803 (Sylhet Rescue)',
        ipAddress: '103.114.98.24',
        details: 'Verified Trade License with Sylhet City Corporation register.',
      ),
      AdminAuditLog(
        id: 'LOG-9002',
        timestamp: DateTime.now().subtract(const Duration(hours: 3)),
        actorName: 'Sarah Rahman',
        actorRole: 'SUPER_ADMIN',
        action: 'USER_BANNED_TOKENS_REVOKED',
        target: 'u-104 (petshopdhaka@fake.com)',
        ipAddress: '103.114.98.11',
        details: 'User violated zero-breeding rule by attempting commercial pet sale. JWT tokens revoked.',
      ),
      AdminAuditLog(
        id: 'LOG-9003',
        timestamp: DateTime.now().subtract(const Duration(hours: 8)),
        actorName: 'System Security',
        actorRole: 'SYSTEM',
        action: 'FLAGGED_PET_LISTING',
        target: 'P-FL-1 (Rocky)',
        ipAddress: '127.0.0.1',
        details: 'Automated ML filter detected commercial keywords in description.',
      ),
    ];

    _disputes = [
      AdoptionDisputeRecord(
        id: 'DISP-501',
        adopterName: 'Mahir Chowdhury',
        shelterName: 'Care For Paws Dhaka',
        petName: 'Barnaby (Senior Dog)',
        contractStatus: 'Signed',
        trialPeriod: 'Day 12 of 14',
        disputeStatus: 'Mediation Required',
        issueSummary: 'Adopter requesting veterinary cost adjustment during foster trial window.',
        updatedAt: DateTime.now().subtract(const Duration(hours: 4)),
      ),
      AdoptionDisputeRecord(
        id: 'DISP-502',
        adopterName: 'Tanzina Sultana',
        shelterName: 'Paw Haven Chittagong',
        petName: 'Bella (Calico Cat)',
        contractStatus: 'Signed',
        trialPeriod: 'Completed',
        disputeStatus: 'Resolved',
        issueSummary: 'Digital e-contract finalized and vaccination passport transferred.',
        updatedAt: DateTime.now().subtract(const Duration(days: 2)),
      ),
    ];
  }

  List<ShelterApplication> getShelters() => List.unmodifiable(_shelters);
  List<FlaggedPetListing> getFlaggedPets() => List.unmodifiable(_flaggedPets);
  List<AdminManagedUser> getUsers() => List.unmodifiable(_users);
  List<AdminAuditLog> getAuditLogs() => List.unmodifiable(_auditLogs);
  List<AdoptionDisputeRecord> getDisputes() => List.unmodifiable(_disputes);

  AdminKPI getKPIs() {
    final pendingCount = _shelters.where((s) => s.status == VerificationStatus.pending).length;
    final flaggedCount = _flaggedPets.where((p) => !p.isBanned).length;
    return AdminKPI(
      totalAdoptions: 1284,
      pendingShelters: pendingCount,
      activeRescues: 342,
      totalDonationsBDT: 248500,
      flaggedListings: flaggedCount,
      activeDisputes: _disputes.where((d) => d.disputeStatus != 'Resolved').length,
    );
  }

  /* ========================================================================
     SHELTER ACTIONS
     ======================================================================== */

  void approveShelter(String id, {String? notes}) {
    final idx = _shelters.indexWhere((s) => s.id == id);
    if (idx != -1) {
      _shelters[idx] = _shelters[idx].copyWith(
        status: VerificationStatus.approved,
        reviewerNotes: notes ?? 'Approved by Administrator after NID & Trade License check.',
      );
      _auditLogs.insert(
        0,
        AdminAuditLog(
          id: 'LOG-${DateTime.now().millisecondsSinceEpoch}',
          timestamp: DateTime.now(),
          actorName: 'Admin',
          actorRole: 'ADMIN',
          action: 'APPROVED_SHELTER',
          target: id,
          ipAddress: '103.114.98.01',
          details: 'Shelter verified and permitted to publish pet rescues.',
        ),
      );
      _sheltersController.add(List.unmodifiable(_shelters));
      _auditLogsController.add(List.unmodifiable(_auditLogs));
    }
  }

  void rejectShelter(String id, {required String reason}) {
    final idx = _shelters.indexWhere((s) => s.id == id);
    if (idx != -1) {
      _shelters[idx] = _shelters[idx].copyWith(
        status: VerificationStatus.rejected,
        reviewerNotes: reason,
      );
      _auditLogs.insert(
        0,
        AdminAuditLog(
          id: 'LOG-${DateTime.now().millisecondsSinceEpoch}',
          timestamp: DateTime.now(),
          actorName: 'Admin',
          actorRole: 'ADMIN',
          action: 'REJECTED_SHELTER',
          target: id,
          ipAddress: '103.114.98.01',
          details: 'Rejection Reason: $reason',
        ),
      );
      _sheltersController.add(List.unmodifiable(_shelters));
      _auditLogsController.add(List.unmodifiable(_auditLogs));
    }
  }

  /* ========================================================================
     USER BANNING & TOKEN INVALIDATION
     ======================================================================== */

  void blockUser(String userId, {String? reason}) {
    final idx = _users.indexWhere((u) => u.id == userId);
    if (idx != -1) {
      final user = _users[idx];
      _users[idx] = user.copyWith(status: 'Banned');
      _auditLogs.insert(
        0,
        AdminAuditLog(
          id: 'LOG-${DateTime.now().millisecondsSinceEpoch}',
          timestamp: DateTime.now(),
          actorName: 'Admin',
          actorRole: 'ADMIN',
          action: 'USER_BANNED_TOKENS_REVOKED',
          target: '${user.name} ($userId)',
          ipAddress: '103.114.98.01',
          details: 'User account banned and all active JWT sessions revoked. Reason: ${reason ?? "Administrative policy breach"}',
        ),
      );
      _usersController.add(List.unmodifiable(_users));
      _auditLogsController.add(List.unmodifiable(_auditLogs));
    }
  }

  void unblockUser(String userId) {
    final idx = _users.indexWhere((u) => u.id == userId);
    if (idx != -1) {
      final user = _users[idx];
      _users[idx] = user.copyWith(status: 'Active');
      _auditLogs.insert(
        0,
        AdminAuditLog(
          id: 'LOG-${DateTime.now().millisecondsSinceEpoch}',
          timestamp: DateTime.now(),
          actorName: 'Admin',
          actorRole: 'ADMIN',
          action: 'USER_UNBLOCKED',
          target: '${user.name} ($userId)',
          ipAddress: '103.114.98.01',
          details: 'Account unblocked. User restored to Active status.',
        ),
      );
      _usersController.add(List.unmodifiable(_users));
      _auditLogsController.add(List.unmodifiable(_auditLogs));
    }
  }

  void updateUserStatus(String id, String status) {
    if (status.toUpperCase() == 'BANNED') {
      blockUser(id);
    } else if (status.toUpperCase() == 'ACTIVE') {
      unblockUser(id);
    } else {
      final idx = _users.indexWhere((u) => u.id == id);
      if (idx != -1) {
        _users[idx] = _users[idx].copyWith(status: status);
        _auditLogs.insert(
          0,
          AdminAuditLog(
            id: 'LOG-${DateTime.now().millisecondsSinceEpoch}',
            timestamp: DateTime.now(),
            actorName: 'Admin',
            actorRole: 'ADMIN',
            action: 'USER_STATUS_CHANGE',
            target: '$id -> $status',
            ipAddress: '103.114.98.01',
            details: 'Updated account status to $status.',
          ),
        );
        _usersController.add(List.unmodifiable(_users));
        _auditLogsController.add(List.unmodifiable(_auditLogs));
      }
    }
  }

  /* ========================================================================
     ROLE DELEGATION & PERMISSIONS
     ======================================================================== */

  void updateUserRole(String userId, UserRole newRole, {List<String>? permissions}) {
    final idx = _users.indexWhere((u) => u.id == userId);
    if (idx != -1) {
      final user = _users[idx];
      List<String> assignedPerms = permissions ?? user.permissions;
      if (newRole == UserRole.moderator && (permissions == null || permissions.isEmpty)) {
        assignedPerms = const ['APPROVE_PETS', 'FLAG_CONTENT', 'REVIEW_APPLICATIONS'];
      }
      _users[idx] = user.copyWith(role: newRole, permissions: assignedPerms);
      _auditLogs.insert(
        0,
        AdminAuditLog(
          id: 'LOG-${DateTime.now().millisecondsSinceEpoch}',
          timestamp: DateTime.now(),
          actorName: 'Admin',
          actorRole: 'ADMIN',
          action: 'DELEGATED_USER_ROLE',
          target: '${user.name} -> ${newRole.code}',
          ipAddress: '103.114.98.01',
          details: 'Role updated to ${newRole.code}. Permissions: [${assignedPerms.join(", ")}]',
        ),
      );
      _usersController.add(List.unmodifiable(_users));
      _auditLogsController.add(List.unmodifiable(_auditLogs));
    }
  }

  void updateUserPermissions(String userId, List<String> permissions) {
    final idx = _users.indexWhere((u) => u.id == userId);
    if (idx != -1) {
      final user = _users[idx];
      _users[idx] = user.copyWith(permissions: permissions);
      _auditLogs.insert(
        0,
        AdminAuditLog(
          id: 'LOG-${DateTime.now().millisecondsSinceEpoch}',
          timestamp: DateTime.now(),
          actorName: 'Admin',
          actorRole: 'ADMIN',
          action: 'UPDATED_USER_PERMISSIONS',
          target: '${user.name} ($userId)',
          ipAddress: '103.114.98.01',
          details: 'Assigned permissions: [${permissions.join(", ")}]',
        ),
      );
      _usersController.add(List.unmodifiable(_users));
      _auditLogsController.add(List.unmodifiable(_auditLogs));
    }
  }

  /* ========================================================================
     PET LISTING CRUD & OVERRIDE
     ======================================================================== */

  void banPetListing(String id) {
    final idx = _flaggedPets.indexWhere((p) => p.id == id);
    if (idx != -1) {
      _flaggedPets[idx] = _flaggedPets[idx].copyWith(isBanned: true);
      _auditLogs.insert(
        0,
        AdminAuditLog(
          id: 'LOG-${DateTime.now().millisecondsSinceEpoch}',
          timestamp: DateTime.now(),
          actorName: 'Admin',
          actorRole: 'ADMIN',
          action: 'BANNED_PET_LISTING',
          target: id,
          ipAddress: '103.114.98.01',
          details: 'Listing removed from public discovery due to policy breach.',
        ),
      );
      _flaggedPetsController.add(List.unmodifiable(_flaggedPets));
      _auditLogsController.add(List.unmodifiable(_auditLogs));
    }
  }

  void togglePetBadge(String id, {bool? isUrgent, bool? isFeatured}) {
    final idx = _flaggedPets.indexWhere((p) => p.id == id);
    if (idx != -1) {
      _flaggedPets[idx] = _flaggedPets[idx].copyWith(
        isUrgent: isUrgent ?? _flaggedPets[idx].isUrgent,
        isFeatured: isFeatured ?? _flaggedPets[idx].isFeatured,
      );
      _flaggedPetsController.add(List.unmodifiable(_flaggedPets));
    }
  }

  Future<void> createPetListing(Pet pet) async {
    await PetRepository().addPet(pet);
    _auditLogs.insert(
      0,
      AdminAuditLog(
        id: 'LOG-${DateTime.now().millisecondsSinceEpoch}',
        timestamp: DateTime.now(),
        actorName: 'Admin',
        actorRole: 'ADMIN',
        action: 'ADMIN_CREATED_PET_LISTING',
        target: '${pet.name} (${pet.id})',
        ipAddress: '103.114.98.01',
        details: 'Direct administrative pet listing created with ${pet.galleryUrls.length} carousel photos.',
      ),
    );
    _auditLogsController.add(List.unmodifiable(_auditLogs));
  }

  Future<void> overridePetListing(Pet pet, {String? notes}) async {
    await PetRepository().updatePet(pet);
    _auditLogs.insert(
      0,
      AdminAuditLog(
        id: 'LOG-${DateTime.now().millisecondsSinceEpoch}',
        timestamp: DateTime.now(),
        actorName: 'Admin',
        actorRole: 'ADMIN',
        action: 'ADMIN_OVERRIDE_PET_LISTING',
        target: '${pet.name} (${pet.id})',
        ipAddress: '103.114.98.01',
        details: 'Admin modified listing details, multi-image carousel, and medical passport. Notes: ${notes ?? "Anytime override"}',
      ),
    );
    _auditLogsController.add(List.unmodifiable(_auditLogs));
  }

  Future<void> deletePetListing(String petId, {String? petName}) async {
    await PetRepository().deletePet(petId);
    _auditLogs.insert(
      0,
      AdminAuditLog(
        id: 'LOG-${DateTime.now().millisecondsSinceEpoch}',
        timestamp: DateTime.now(),
        actorName: 'Admin',
        actorRole: 'ADMIN',
        action: 'ADMIN_DELETED_PET_LISTING',
        target: '${petName ?? petId} ($petId)',
        ipAddress: '103.114.98.01',
        details: 'Pet listing permanently deleted from platform by administrator.',
      ),
    );
    _auditLogsController.add(List.unmodifiable(_auditLogs));
  }

  /// Records an explicit moderation or administrative event in the audit trail.
  void recordAuditLog({
    required String actorName,
    required String action,
    required String target,
    required String details,
    String actorRole = 'ADMIN',
  }) {
    _auditLogs.insert(
      0,
      AdminAuditLog(
        id: 'LOG-${DateTime.now().millisecondsSinceEpoch}',
        timestamp: DateTime.now(),
        actorName: actorName,
        actorRole: actorRole,
        action: action,
        target: target,
        ipAddress: '103.114.98.01 (Admin SSL Session)',
        details: details,
      ),
    );
    _auditLogsController.add(List.unmodifiable(_auditLogs));
  }
}
