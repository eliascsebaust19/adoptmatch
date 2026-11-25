import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../auth/bloc/auth_bloc.dart';
import '../../../core/repositories/admin_repository.dart';

class AdminDrawer extends StatelessWidget {
  final bool isBangla;
  final VoidCallback? onLogoutRequested;
  final String? currentRoute;

  const AdminDrawer({
    super.key,
    this.isBangla = false,
    this.onLogoutRequested,
    this.currentRoute,
  });

  @override
  Widget build(BuildContext context) {
    final authState = context.watch<AuthBloc>().state;
    final user = authState is Authenticated ? authState.user : null;
    final roleName = user?.role.code ?? 'ADMIN';
    final adminName = (user?.name != null && user!.name.trim().isNotEmpty)
        ? user.name.trim()
        : ((user?.email != null && user!.email.isNotEmpty)
            ? user.email.split('@').first
            : 'Administrator');
    final adminEmail = user?.email ?? '';

    final kpis = AdminRepository().getKPIs();
    final pendingShelterCount = kpis?.pendingShelters ?? 0;
    final flaggedPetCount = kpis?.flaggedListings ?? 0;

    final activePath = currentRoute ?? GoRouterState.of(context).uri.path;

    return Drawer(
      backgroundColor: const Color(0xFF0F172A),
      elevation: 16,
      child: SafeArea(
        child: Column(
          children: [
            // 1. Dynamic User Header (No hardcoded identity)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: Color(0xFF1E293B),
                border: Border(bottom: BorderSide(color: Color(0xFF334155), width: 1)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: const Color(0xFF0D9488).withOpacity(0.18),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF0D9488).withOpacity(0.4)),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Image.asset(
                      'assets/images/app_logo.png',
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => const Icon(
                        Icons.shield_outlined,
                        color: Color(0xFF14B8A6),
                        size: 26,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          adminName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                            letterSpacing: -0.2,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (adminEmail.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            adminEmail,
                            style: const TextStyle(
                              color: Color(0xFF94A3B8),
                              fontSize: 11,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                        const SizedBox(height: 5),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0D9488).withOpacity(0.2),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFF0D9488).withOpacity(0.5), width: 0.8),
                          ),
                          child: Text(
                            roleName,
                            style: const TextStyle(
                              color: Color(0xFF2DD4BF),
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // 2. Navigation Items (Strictly /admin/* Isolated Scope)
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                children: [
                  _drawerTile(
                    context: context,
                    icon: Icons.dashboard_rounded,
                    label: isBangla ? 'ড্যাশবোর্ড ওভারভিউ' : 'Dashboard Overview',
                    isSelected: activePath == '/admin/dashboard' || activePath == '/admin',
                    onTap: () {
                      Navigator.pop(context);
                      if (activePath != '/admin/dashboard') context.go('/admin/dashboard');
                    },
                  ),
                  _drawerTile(
                    context: context,
                    icon: Icons.verified_user_rounded,
                    label: isBangla ? 'শেল্টার অনুমোদন' : 'Shelter Approvals',
                    badgeCount: pendingShelterCount > 0 ? pendingShelterCount : null,
                    badgeColor: const Color(0xFFF59E0B),
                    isSelected: activePath.startsWith('/admin/shelters'),
                    onTap: () {
                      Navigator.pop(context);
                      context.push('/admin/shelters');
                    },
                  ),
                  _drawerTile(
                    context: context,
                    icon: Icons.pets_rounded,
                    label: isBangla ? 'পোষ্য মডারেশন' : 'Pet Moderation',
                    badgeCount: flaggedPetCount > 0 ? flaggedPetCount : null,
                    badgeColor: const Color(0xFFE11D48),
                    isSelected: activePath.startsWith('/admin/pets'),
                    onTap: () {
                      Navigator.pop(context);
                      context.push('/admin/pets');
                    },
                  ),
                  _drawerTile(
                    context: context,
                    icon: Icons.track_changes_rounded,
                    label: isBangla ? 'অ্যাডপশন পাইপলাইন' : 'Adoption Pipeline',
                    isSelected: activePath.startsWith('/admin/adoptions'),
                    onTap: () {
                      Navigator.pop(context);
                      context.push('/admin/adoptions');
                    },
                  ),
                  _drawerTile(
                    context: context,
                    icon: Icons.people_alt_rounded,
                    label: isBangla ? 'ইউজার ম্যানেজমেন্ট' : 'User Management',
                    isSelected: activePath.startsWith('/admin/users'),
                    onTap: () {
                      Navigator.pop(context);
                      context.push('/admin/users');
                    },
                  ),
                  _drawerTile(
                    context: context,
                    icon: Icons.workspace_premium_rounded,
                    label: isBangla ? 'ভিআইপি সাবস্ক্রিপশন' : 'VIP Subscriptions',
                    isSelected: activePath.startsWith('/admin/subscriptions'),
                    onTap: () {
                      Navigator.pop(context);
                      context.push('/admin/subscriptions');
                    },
                  ),
                  _drawerTile(
                    context: context,
                    icon: Icons.history_edu_rounded,
                    label: isBangla ? 'অডিট ট্রেইল লগ' : 'Audit Logs',
                    isSelected: activePath.startsWith('/admin/audit-logs'),
                    onTap: () {
                      Navigator.pop(context);
                      context.push('/admin/audit-logs');
                    },
                  ),
                ],
              ),
            ),

            // 3. Footer & Sign Out Action
            const Divider(color: Color(0xFF334155), height: 1),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: ListTile(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                leading: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE11D48).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.logout_rounded, color: Color(0xFFEF4444), size: 20),
                ),
                title: Text(
                  isBangla ? 'লগআউট' : 'Sign Out',
                  style: const TextStyle(
                    color: Color(0xFFEF4444),
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  onLogoutRequested?.call();
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                'AdoptMatch v2.4 Enterprise Portal',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.35),
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _drawerTile({
    required BuildContext context,
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    int? badgeCount,
    Color badgeColor = const Color(0xFF0D9488),
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.5),
      child: Material(
        color: isSelected ? const Color(0xFF0D9488).withOpacity(0.18) : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          hoverColor: Colors.white.withOpacity(0.05),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            child: Row(
              children: [
                // Active State Indicator Bar
                Container(
                  width: 3.5,
                  height: 20,
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFF14B8A6) : Colors.transparent,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 10),
                Icon(
                  icon,
                  size: 20,
                  color: isSelected ? const Color(0xFF2DD4BF) : const Color(0xFF94A3B8),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: isSelected ? Colors.white : const Color(0xFFCBD5E1),
                    ),
                  ),
                ),
                if (badgeCount != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: badgeColor,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '$badgeCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
