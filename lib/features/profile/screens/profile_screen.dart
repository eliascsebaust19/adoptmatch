import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../auth/bloc/auth_bloc.dart';
import '../../../core/localization/app_locale.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/language_selector_sheet.dart';
import '../../../core/widgets/guest_restriction_dialog.dart';
import '../../../shared/widgets/shared_widgets.dart';
import '../widgets/change_password_dialog.dart';
import 'edit_profile_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  Widget _buildUserAvatar(UserProfile user) {
    final avatar = user.avatarUrl;
    if (avatar.startsWith('data:image')) {
      try {
        final bytes = base64Decode(avatar.split(',').last);
        return Image.memory(bytes, fit: BoxFit.cover, width: 72, height: 72);
      } catch (_) {}
    } else if (avatar.isNotEmpty) {
      return AppNetworkImage(imageUrl: avatar, fit: BoxFit.cover);
    }
    return Center(
      child: Text(
        user.name.isNotEmpty ? user.name[0].toUpperCase() : 'U',
        style: const TextStyle(
          fontSize: 26,
          fontWeight: FontWeight.bold,
          color: Color(0xFF4338CA),
        ),
      ),
    );
  }

  void _showLogoutConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
        ),
        title: Row(
          children: const [
            Icon(Icons.logout_rounded, color: AppColors.error, size: 24),
            SizedBox(width: 10),
            Text(
              'Sign Out',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ],
        ),
        content: const Text(
          'Are you sure you want to log out of AdoptMatch? You will need to sign back in to access saved pets and applications.',
          style: TextStyle(
            fontSize: 13,
            color: AppColors.textSecondary,
            height: 1.4,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'Cancel',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.button),
              ),
              elevation: 0,
            ),
            onPressed: () {
              Navigator.pop(ctx);
              context.read<AuthBloc>().add(LogoutEvent());
              context.go('/auth/login');
            },
            child: const Text(
              'Sign Out',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Color _getRoleColor(UserRole role) {
    switch (role) {
      case UserRole.guest:
        return const Color(0xFF64748B);
      case UserRole.superAdmin:
      case UserRole.admin:
        return const Color(0xFFE11D48);
      case UserRole.moderator:
        return const Color(0xFF9333EA);
      case UserRole.shelter:
        return const Color(0xFF4F46E5);
      case UserRole.foster:
        return const Color(0xFF0D9488);
      case UserRole.adopter:
        return const Color(0xFF16A34A);
    }
  }

  String _getRoleLabel(UserRole role) {
    switch (role) {
      case UserRole.guest:
        return 'Guest (Demo Explorer)';
      case UserRole.superAdmin:
        return 'Super Administrator';
      case UserRole.admin:
        return 'Platform Admin';
      case UserRole.moderator:
        return 'Moderator';
      case UserRole.shelter:
        return 'Registered Shelter';
      case UserRole.foster:
        return 'Foster Volunteer';
      case UserRole.adopter:
        return 'Verified Adopter';
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = context.watch<AuthBloc>().state;
    final user = authState is Authenticated
        ? authState.user
        : const UserProfile(
            id: 'guest',
            name: 'Guest User',
            email: 'guest@adoptmatch.org',
            phone: '+880 1700 000000',
          );

    final currentLang = AppLocaleScope.of(context).language;
    final roleColor = _getRoleColor(user.role);

    return Scaffold(
      backgroundColor: AppColors.surfaceScaffold,
      appBar: AppBar(
        title: const Text('My Profile & Settings'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded),
            tooltip: 'Options',
            onSelected: (value) {
              if (value == 'language') {
                showProfessionalLanguageSelector(context);
              } else if (value == 'logout') {
                _showLogoutConfirmation(context);
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'language',
                child: Row(
                  children: [
                    Icon(Icons.language_rounded, color: AppColors.secondary, size: 20),
                    SizedBox(width: 10),
                    Text('Change Language / ভাষা', style: TextStyle(fontSize: 14)),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout_rounded, color: AppColors.error, size: 20),
                    SizedBox(width: 10),
                    Text('Sign Out', style: TextStyle(fontSize: 14, color: AppColors.error)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          children: [
            // Guest Mode Preview Banner
            if (user.role.isGuest)
              Container(
                margin: const EdgeInsets.only(bottom: AppSpacing.lg),
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(AppRadius.card),
                  border: Border.all(color: const Color(0xFFFDE68A)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.visibility_outlined, color: Color(0xFFD97706), size: 26),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            'Guest Demo Mode Active',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13.5,
                              color: Color(0xFF92400E),
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Create an account or sign in to submit adoption applications, message rescues, and unlock all features.',
                            style: TextStyle(fontSize: 11.5, color: Color(0xFFB45309), height: 1.3),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFD97706),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        minimumSize: Size.zero,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        elevation: 0,
                      ),
                      onPressed: () => context.push('/auth/login'),
                      child: const Text('Sign In', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),

            // User Header Card
            AppCard(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Avatar with Camera Badge
                      InkWell(
                        onTap: () async {
                          final isRestricted = await GuestRestrictionDialog.checkAndShow(
                            context,
                            featureName: 'Profile Photo Upload',
                            customMessage: 'Updating profile photo requires an active registered account.\n\nছবি পরিবর্তন করতে সাইন ইন করুন।',
                          );
                          if (isRestricted || !context.mounted) return;

                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const EditProfileScreen(),
                            ),
                          );
                        },
                        borderRadius: BorderRadius.circular(40),
                        child: Stack(
                          children: [
                            Container(
                              width: 76,
                              height: 76,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: const Color(0xFFE0E7FF),
                                border: Border.all(
                                  color: AppColors.primary,
                                  width: 2,
                                ),
                              ),
                              child: ClipOval(child: _buildUserAvatar(user)),
                            ),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: Container(
                                padding: const EdgeInsets.all(5),
                                decoration: const BoxDecoration(
                                  color: AppColors.primary,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.camera_alt,
                                  color: Colors.white,
                                  size: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: AppSpacing.lg),

                      // User Details & Edit Shortcut
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    user.name,
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.slateDark,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 4,
                                    ),
                                    minimumSize: Size.zero,
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                    side: const BorderSide(
                                      color: AppColors.border,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(
                                        AppRadius.sm,
                                      ),
                                    ),
                                  ),
                                  icon: const Icon(
                                    Icons.edit_outlined,
                                    size: 12,
                                    color: AppColors.primary,
                                  ),
                                  label: const Text(
                                    'Edit',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                  onPressed: () async {
                                    final isRestricted = await GuestRestrictionDialog.checkAndShow(
                                      context,
                                      featureName: 'Profile Editing',
                                      customMessage: 'Guest profiles cannot be modified. Please sign in or register to create your profile.\n\nপ্রোফাইল এডিট করতে সাইন ইন করুন।',
                                    );
                                    if (isRestricted || !context.mounted) return;

                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => const EditProfileScreen(),
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              user.email,
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (user.phone.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  const Icon(
                                    Icons.phone,
                                    size: 11,
                                    color: AppColors.textSecondary,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    user.phone,
                                    style: const TextStyle(
                                      fontSize: 11.5,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              children: [
                                // Role Badge
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: roleColor.withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(
                                      AppRadius.xs,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.shield_outlined,
                                        size: 12,
                                        color: roleColor,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        _getRoleLabel(user.role),
                                        style: TextStyle(
                                          color: roleColor,
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (user.hasActivePremium)
                                  PremiumBadge(title: user.premiumBadgeTitle),
                                if (user.location.isNotEmpty)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF1F5F9),
                                      borderRadius: BorderRadius.circular(
                                        AppRadius.xs,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(
                                          Icons.location_on,
                                          size: 11,
                                          color: AppColors.textSecondary,
                                        ),
                                        const SizedBox(width: 3),
                                        Text(
                                          user.location,
                                          style: const TextStyle(
                                            color: AppColors.slateMedium,
                                            fontSize: 10.5,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  // Bio / About Me
                  if (user.bio.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.md),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Text(
                        '"${user.bio}"',
                        style: const TextStyle(
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                          color: AppColors.slateMedium,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            // Quick Tile 1: Edit Profile & Photos
            _SettingsTile(
              icon: Icons.manage_accounts_outlined,
              iconColor: AppColors.primary,
              title: 'Edit Profile & Photos',
              subtitle: 'Update name, contact info, and profile avatar',
              onTap: () async {
                final isRestricted = await GuestRestrictionDialog.checkAndShow(
                  context,
                  featureName: 'Profile Editing',
                  customMessage: 'Guest profiles cannot be modified. Please sign in or register to create your profile.\n\nপ্রোফাইল এডিট করতে সাইন ইন করুন।',
                );
                if (isRestricted || !context.mounted) return;

                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const EditProfileScreen()),
                );
              },
            ),
            const SizedBox(height: AppSpacing.md),

            // Quick Tile: Premium Subscription & VIP Desk
            _SettingsTile(
              icon: Icons.workspace_premium,
              iconColor: const Color(0xFFF59E0B),
              title: user.hasActivePremium ? 'My VIP Subscription' : 'Go Premium (from ৳90 BDT)',
              subtitle: user.hasActivePremium
                  ? '${user.premiumBadgeTitle} • ${user.remainingDays} days remaining'
                  : 'Priority rescue listings, visitor analytics & ad-free access',
              onTap: () async {
                final isRestricted = await GuestRestrictionDialog.checkAndShow(
                  context,
                  featureName: 'VIP Membership & Badges',
                  customMessage: 'VIP membership is linked to a registered adopter profile. Sign in or register to upgrade.\n\nভিআইপি মেম্বারশিপ পেতে সাইন ইন করুন।',
                );
                if (isRestricted || !context.mounted) return;
                context.push(user.hasActivePremium ? '/subscription/my' : '/subscription/plans');
              },
            ),
            const SizedBox(height: AppSpacing.md),

            // Quick Tile 2: Change Password
            _SettingsTile(
              icon: Icons.lock_reset_rounded,
              iconColor: const Color(0xFF4F46E5),
              title: 'Change Password',
              subtitle: 'Update your login credentials and security',
              onTap: () async {
                final isRestricted = await GuestRestrictionDialog.checkAndShow(
                  context,
                  featureName: 'Password Management',
                  customMessage: 'Guest demo accounts do not use a password. Please sign in or register with your email.\n\nপাসওয়ার্ড পরিবর্তনের সুবিধা শুধু রেজিস্টার্ড অ্যাকাউন্ট ব্যবহারকারীদের জন্য।',
                );
                if (isRestricted || !context.mounted) return;
                ChangePasswordDialog.show(context);
              },
            ),
            const SizedBox(height: AppSpacing.md),

            // Language Switcher Tile
            AppCard(
              padding: EdgeInsets.zero,
              child: ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFCCFBF1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.language_rounded,
                    color: AppColors.secondary,
                    size: 22,
                  ),
                ),
                title: const Text(
                  'Language / ভাষা',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: AppColors.slateDark,
                  ),
                ),
                subtitle: Text(
                  currentLang == AppLanguage.en ? 'English (US)' : 'বাংলা (Bangladesh)',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.slateMedium,
                  ),
                ),
                trailing: const Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.textSecondary,
                ),
                onTap: () => showProfessionalLanguageSelector(context),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            // App Feature Navigation
            _SettingsTile(
              icon: Icons.assignment_outlined,
              iconColor: const Color(0xFF2563EB),
              title: 'My Adoption Applications',
              subtitle: 'Track review stages and scheduled home visits',
              onTap: () => context.push('/applications'),
            ),
            const SizedBox(height: AppSpacing.md),

            _SettingsTile(
              icon: Icons.qr_code_2,
              iconColor: AppColors.secondary,
              title: 'Pet Health Passports',
              subtitle: 'Scan and manage offline medical QR tags',
              onTap: () => context.push('/health/p1'),
            ),
            const SizedBox(height: AppSpacing.md),

            _SettingsTile(
              icon: Icons.style,
              iconColor: const Color(0xFFE11D48),
              title: 'Swipe & Match Preferences',
              subtitle: 'Retake 5-question lifestyle compatibility quiz',
              onTap: () => context.push('/quiz'),
            ),
            const SizedBox(height: AppSpacing.md),

            _SettingsTile(
              icon: Icons.security,
              iconColor: const Color(0xFF059669),
              title: 'Privacy & Masked Calling Info',
              subtitle: 'Strict adopter protection & zero breeding guarantee',
              onTap: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.card),
                    ),
                    title: const Text('Ethical Pet Adoption Directives'),
                    content: const Text(
                      'AdoptMatch strictly forbids commercial breeding or commercial pet transactions.\n\nAll personal contact details are masked by proxy relays to safeguard adopters and shelter volunteers.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Understood'),
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: AppSpacing.xxl),

            // Prominent Sign Out Button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.error,
                  side: const BorderSide(color: Color(0xFFFECDD3), width: 1.5),
                  backgroundColor: const Color(0xFFFFF1F2),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.button),
                  ),
                ),
                icon: const Icon(Icons.logout_rounded, size: 20),
                label: const Text(
                  'Sign Out of Account',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
                onPressed: () => _showLogoutConfirmation(context),
              ),
            ),
            const SizedBox(height: AppSpacing.xxl),
          ],
        ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _SettingsTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: EdgeInsets.zero,
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.xs,
        ),
        leading: Container(
          padding: const EdgeInsets.all(AppSpacing.sm),
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          child: Icon(icon, color: iconColor, size: 22),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 14,
            color: AppColors.slateDark,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
        trailing: const Icon(
          Icons.arrow_forward_ios,
          size: 14,
          color: Color(0xFF94A3B8),
        ),
      ),
    );
  }
}
