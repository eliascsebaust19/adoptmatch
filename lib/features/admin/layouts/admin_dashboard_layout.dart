import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../auth/bloc/auth_bloc.dart';
import '../../../core/repositories/admin_repository.dart';
import '../widgets/admin_create_pet_dialog.dart';

class AdminDashboardLayout extends StatefulWidget {
  final Widget child;

  const AdminDashboardLayout({super.key, required this.child});

  @override
  State<AdminDashboardLayout> createState() => _AdminDashboardLayoutState();
}

class _AdminDashboardLayoutState extends State<AdminDashboardLayout> {
  final _adminRepo = AdminRepository();
  @override
  void initState() {
    super.initState();
    _adminRepo.refresh().then((_) { if (mounted) setState(() {}); }).catchError((Object e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Admin data unavailable: $e')));
    });
  }

  int _getSelectedIndex(String path) {
    if (path.startsWith('/admin/shelters')) return 1;
    if (path.startsWith('/admin/pets')) return 2;
    if (path.startsWith('/admin/adoptions')) return 3;
    if (path.startsWith('/admin/users')) return 4;
    if (path.startsWith('/admin/audit-logs')) return 5;
    if (path.startsWith('/admin/subscriptions')) return 6;
    return 0; // /admin/dashboard
  }

  void _onNavigate(int index) {
    switch (index) {
      case 0:
        context.go('/admin/dashboard');
        break;
      case 1:
        context.go('/admin/shelters');
        break;
      case 2:
        context.go('/admin/pets');
        break;
      case 3:
        context.go('/admin/adoptions');
        break;
      case 4:
        context.go('/admin/users');
        break;
      case 5:
        context.go('/admin/audit-logs');
        break;
      case 6:
        context.go('/admin/subscriptions');
        break;
    }
  }

  void _handleLogout() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Confirm Admin Logout', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('Are you sure you want to end your administrative session?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE11D48),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              context.read<AuthBloc>().add(LogoutEvent());
              context.go('/admin/login');
            },
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    final selectedIndex = _getSelectedIndex(location);

    final authState = context.watch<AuthBloc>().state;
    final user = authState is Authenticated ? authState.user : null;
    final roleName = user?.role.code ?? 'ADMIN';
    final adminName = user?.name ?? 'Administrator';

    final kpis = _adminRepo.getKPIs();
    final pendingShelterCount = kpis?.pendingShelters ?? 0;
    final flaggedPetCount = kpis?.flaggedListings ?? 0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 960;

        return Scaffold(
          backgroundColor: const Color(0xFF0F172A), // Dark slate enterprise background
          appBar: isWide
              ? null
              : AppBar(
                  backgroundColor: const Color(0xFF1E293B),
                  elevation: 1,
                  title: Row(
                    children: [
                      Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Image.asset(
                          'assets/images/app_logo.png',
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => const Icon(Icons.shield_outlined, color: Color(0xFF6366F1), size: 18),
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'AdoptMatch Admin',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ],
                  ),
                  actions: [
                    IconButton(
                      icon: const Icon(Icons.add_circle, color: Color(0xFF14B8A6), size: 24),
                      tooltip: 'Add Pet / পোষ্য যোগ',
                      onPressed: () => showAdminCreatePetDialog(context),
                    ),
                    IconButton(
                      icon: const Icon(Icons.logout, color: Color(0xFFEF4444)),
                      tooltip: 'Logout',
                      onPressed: _handleLogout,
                    ),
                  ],
                ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => showAdminCreatePetDialog(context),
            backgroundColor: const Color(0xFF0D9488),
            foregroundColor: Colors.white,
            elevation: 4,
            icon: const Icon(Icons.add_photo_alternate_rounded, size: 20),
            label: const Text(
              'Add Rescue Pet / পোষ্য যোগ',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ),
          drawer: isWide
              ? null
              : Drawer(
                  backgroundColor: const Color(0xFF1E293B),
                  child: _buildSidebarContent(
                    context,
                    selectedIndex,
                    roleName,
                    adminName,
                    pendingShelterCount,
                    flaggedPetCount,
                    isDrawer: true,
                  ),
                ),
          body: Row(
            children: [
              if (isWide)
                SizedBox(
                  width: 260,
                  child: _buildSidebarContent(
                    context,
                    selectedIndex,
                    roleName,
                    adminName,
                    pendingShelterCount,
                    flaggedPetCount,
                    isDrawer: false,
                  ),
                ),
              Expanded(
                child: Container(
                  color: const Color(0xFFF8FAFC), // Crisp light content area
                  child: Column(
                    children: [
                      // Top Admin Header Bar (Desktop only)
                      if (isWide) _buildTopHeader(context, adminName, roleName),
                      // Screen Child
                      Expanded(child: widget.child),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTopHeader(BuildContext context, String adminName, String roleName) {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const Text(
                'Enterprise Control Portal',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: roleName == 'SUPER_ADMIN' ? const Color(0xFFFEF3C7) : const Color(0xFFE0E7FF),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: roleName == 'SUPER_ADMIN' ? const Color(0xFFF59E0B) : const Color(0xFF6366F1),
                    width: 0.5,
                  ),
                ),
                child: Text(
                  roleName,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: roleName == 'SUPER_ADMIN' ? const Color(0xFFB45309) : const Color(0xFF4338CA),
                  ),
                ),
              ),
            ],
          ),
          Row(
            children: [
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0D9488),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  elevation: 1,
                ),
                icon: const Icon(Icons.add_photo_alternate_rounded, size: 16),
                label: const Text('Add Rescue Pet / পোষ্য যোগ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                onPressed: () => showAdminCreatePetDialog(context),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 14,
                      backgroundColor: const Color(0xFF6366F1),
                      child: Text(
                        adminName.isNotEmpty ? adminName[0].toUpperCase() : 'A',
                        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      adminName,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              IconButton(
                icon: const Icon(Icons.logout, color: Color(0xFFE11D48), size: 20),
                tooltip: 'Logout',
                onPressed: _handleLogout,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSidebarContent(
    BuildContext context,
    int selectedIndex,
    String roleName,
    String adminName,
    int pendingShelterCount,
    int flaggedPetCount, {
    required bool isDrawer,
  }) {
    return Container(
      color: const Color(0xFF1E293B),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Brand Logo
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Image.asset(
                      'assets/images/app_logo.png',
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => const Icon(Icons.pets, color: Color(0xFF6366F1), size: 20),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'AdoptMatch',
                        style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Admin Operations',
                        style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Divider(color: Color(0xFF334155), height: 1),
            const SizedBox(height: 12),

            // Navigation Items
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: [
                  _SidebarItem(
                    icon: Icons.dashboard_rounded,
                    title: 'Dashboard Overview',
                    isSelected: selectedIndex == 0,
                    onTap: () {
                      if (isDrawer) Navigator.pop(context);
                      _onNavigate(0);
                    },
                  ),
                  _SidebarItem(
                    icon: Icons.domain_verification_rounded,
                    title: 'Shelter Approvals',
                    badgeCount: pendingShelterCount > 0 ? pendingShelterCount : null,
                    badgeColor: const Color(0xFFF59E0B),
                    isSelected: selectedIndex == 1,
                    onTap: () {
                      if (isDrawer) Navigator.pop(context);
                      _onNavigate(1);
                    },
                  ),
                  _SidebarItem(
                    icon: Icons.warning_amber_rounded,
                    title: 'Pet Moderation',
                    badgeCount: flaggedPetCount > 0 ? flaggedPetCount : null,
                    badgeColor: const Color(0xFFE11D48),
                    isSelected: selectedIndex == 2,
                    onTap: () {
                      if (isDrawer) Navigator.pop(context);
                      _onNavigate(2);
                    },
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                    child: Material(
                      color: const Color(0xFF0D9488).withOpacity(0.18),
                      borderRadius: BorderRadius.circular(10),
                      child: InkWell(
                        onTap: () {
                          if (isDrawer) Navigator.pop(context);
                          showAdminCreatePetDialog(context);
                        },
                        borderRadius: BorderRadius.circular(10),
                        child: const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          child: Row(
                            children: [
                              Icon(Icons.add_photo_alternate_rounded, color: Color(0xFF14B8A6), size: 18),
                              SizedBox(width: 12),
                              Text(
                                '+ Add Rescue Pet / পোষ্য যোগ',
                                style: TextStyle(
                                  color: Color(0xFF2DD4BF),
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  _SidebarItem(
                    icon: Icons.assignment_outlined,
                    title: 'Adoptions & Disputes',
                    isSelected: selectedIndex == 3,
                    onTap: () {
                      if (isDrawer) Navigator.pop(context);
                      _onNavigate(3);
                    },
                  ),
                  _SidebarItem(
                    icon: Icons.manage_accounts_outlined,
                    title: 'User Management',
                    isSelected: selectedIndex == 4,
                    onTap: () {
                      if (isDrawer) Navigator.pop(context);
                      _onNavigate(4);
                    },
                  ),
                  _SidebarItem(
                    icon: Icons.history_rounded,
                    title: 'Audit Logs',
                    isSelected: selectedIndex == 5,
                    onTap: () {
                      if (isDrawer) Navigator.pop(context);
                      _onNavigate(5);
                    },
                  ),
                  _SidebarItem(
                    icon: Icons.payments_outlined,
                    title: 'Subscriptions & Billing',
                    isSelected: selectedIndex == 6,
                    onTap: () {
                      if (isDrawer) Navigator.pop(context);
                      _onNavigate(6);
                    },
                  ),
                ],
              ),
            ),

            // Logout & Footer
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  InkWell(
                    onTap: _handleLogout,
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: Row(
                        children: const [
                          Icon(Icons.logout, color: Color(0xFFEF4444), size: 18),
                          SizedBox(width: 10),
                          Text(
                            'Sign Out',
                            style: TextStyle(color: Color(0xFFF87171), fontWeight: FontWeight.w600, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'AdoptMatch v2.4 Enterprise',
                    style: TextStyle(color: Color(0xFF64748B), fontSize: 10),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final bool isSelected;
  final VoidCallback onTap;
  final int? badgeCount;
  final Color badgeColor;

  const _SidebarItem({
    required this.icon,
    required this.title,
    required this.isSelected,
    required this.onTap,
    this.badgeCount,
    this.badgeColor = const Color(0xFF6366F1),
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Material(
        color: isSelected ? const Color(0xFF6366F1) : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          hoverColor: Colors.white.withOpacity(0.06),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 19,
                  color: isSelected ? Colors.white : const Color(0xFF94A3B8),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: isSelected ? Colors.white : const Color(0xFFCBD5E1),
                    ),
                  ),
                ),
                if (badgeCount != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: badgeColor,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '$badgeCount',
                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
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

