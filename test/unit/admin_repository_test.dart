import 'package:flutter_test/flutter_test.dart';
import 'package:adoptmatch/core/repositories/admin_repository.dart';
import 'package:adoptmatch/core/repositories/pet_repository.dart';
import 'package:adoptmatch/core/models/pet_model.dart';
import 'package:adoptmatch/features/auth/bloc/auth_bloc.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Admin Privilege & Moderation Tests', () {
    late AdminRepository adminRepo;
    late PetRepository petRepo;

    setUp(() {
      adminRepo = AdminRepository();
      petRepo = PetRepository();
    });

    test('blockUser sets status to Banned and unblockUser restores Active status', () {
      const testUserId = 'u-101';
      final initialUser = adminRepo.getUsers().firstWhere((u) => u.id == testUserId);
      expect(initialUser.status, 'Active');
      expect(initialUser.isBanned, false);

      // Block user
      adminRepo.blockUser(testUserId, reason: 'Commercial sales breach');
      final bannedUser = adminRepo.getUsers().firstWhere((u) => u.id == testUserId);
      expect(bannedUser.status, 'Banned');
      expect(bannedUser.isBanned, true);

      // Verify audit log recorded
      final latestLog = adminRepo.getAuditLogs().first;
      expect(latestLog.action, 'USER_BANNED_TOKENS_REVOKED');
      expect(latestLog.target, contains(testUserId));

      // Unblock user
      adminRepo.unblockUser(testUserId);
      final unblockedUser = adminRepo.getUsers().firstWhere((u) => u.id == testUserId);
      expect(unblockedUser.status, 'Active');
      expect(unblockedUser.isBanned, false);
      expect(adminRepo.getAuditLogs().first.action, 'USER_UNBLOCKED');
    });

    test('updateUserRole delegates MODERATOR role and assigns default moderation permissions', () {
      const testUserId = 'u-101';
      adminRepo.updateUserRole(testUserId, UserRole.moderator);

      final updatedUser = adminRepo.getUsers().firstWhere((u) => u.id == testUserId);
      expect(updatedUser.role, UserRole.moderator);
      expect(updatedUser.role.isModerator, true);
      expect(updatedUser.role.hasAdminAccess, true);
      expect(updatedUser.permissions, contains('APPROVE_PETS'));
      expect(updatedUser.permissions, contains('FLAG_CONTENT'));
      expect(updatedUser.permissions, contains('REVIEW_APPLICATIONS'));

      expect(adminRepo.getAuditLogs().first.action, 'DELEGATED_USER_ROLE');
    });

    test('updateUserPermissions updates granular permissions and creates audit trail', () {
      const testUserId = 'u-105';
      final newPerms = ['APPROVE_PETS', 'MANAGE_USERS'];
      adminRepo.updateUserPermissions(testUserId, newPerms);

      final user = adminRepo.getUsers().firstWhere((u) => u.id == testUserId);
      expect(user.permissions, newPerms);
      expect(adminRepo.getAuditLogs().first.action, 'UPDATED_USER_PERMISSIONS');
    });

    test('Full Pet Listing CRUD & Image Override updates both repositories', () async {
      final testPet = Pet(
        id: 'p-test-crud-1',
        name: 'Thunder',
        species: 'Dog',
        breed: 'Husky Mix',
        ageDisplay: '1 yr',
        ageMonths: 12,
        gender: 'Male',
        weightKg: 20.0,
        distanceKm: 1.5,
        matchScore: 90,
        imageUrl: 'https://images.unsplash.com/photo-1552053831-71594a27632d',
        galleryUrls: const [
          'https://images.unsplash.com/photo-1552053831-71594a27632d',
          'https://images.unsplash.com/photo-1537151625747-768eb6cf92b2',
        ],
        isFavorite: false,
        isUrgent: false,
        isFeatured: false,
        shelterName: 'AdoptMatch Test Shelter',
        shelterPhone: '+880 1700 000000',
        shelterAddress: 'Banani, Dhaka',
        story: 'Test husky mix rescue.',
        medicalHistory: 'Vaccinated and neutered.',
        qrHash: 'HASH-TEST-1',
      );

      // 1. Create
      await adminRepo.createPetListing(testPet);
      expect(petRepo.pets.any((p) => p.id == 'p-test-crud-1'), true);
      expect(adminRepo.getAuditLogs().first.action, 'ADMIN_CREATED_PET_LISTING');

      // 2. Override & Image Replacement Anytime
      final overriddenPet = testPet.copyWith(
        name: 'Thunderbolt (Renamed by Admin)',
        galleryUrls: const [
          'https://images.unsplash.com/photo-new-1',
          'https://images.unsplash.com/photo-new-2',
          'https://images.unsplash.com/photo-new-3',
        ],
        isUrgent: true,
        isFeatured: true,
        medicalHistory: 'Updated: Rabies booster confirmed by Dr. Kabir.',
      );

      await adminRepo.overridePetListing(overriddenPet, notes: 'Emergency medical update');
      final fetched = petRepo.pets.firstWhere((p) => p.id == 'p-test-crud-1');
      expect(fetched.name, 'Thunderbolt (Renamed by Admin)');
      expect(fetched.galleryUrls.length, 3);
      expect(fetched.isUrgent, true);
      expect(fetched.isFeatured, true);
      expect(fetched.medicalHistory, contains('Dr. Kabir'));
      expect(adminRepo.getAuditLogs().first.action, 'ADMIN_OVERRIDE_PET_LISTING');

      // 3. Delete
      await adminRepo.deletePetListing('p-test-crud-1');
      expect(petRepo.pets.any((p) => p.id == 'p-test-crud-1'), false);
      expect(adminRepo.getAuditLogs().first.action, 'ADMIN_DELETED_PET_LISTING');
    });
  });
}

