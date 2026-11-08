import 'package:flutter/material.dart';

import '../../../core/repositories/admin_repository.dart';
import '../../auth/bloc/auth_bloc.dart';

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  final _adminRepo = AdminRepository();
  String _searchQuery = '';
  String? _adminError;
  @override
  void initState() {
    super.initState();
    _loadAdminData();
  }
  Future<void> _loadAdminData() async {
    try { await _adminRepo.refresh(); if (mounted) setState(() => _adminError = null); }
    catch (e) { if (mounted) setState(() => _adminError = 'Could not load server data: $e'); }
  }
  Future<void> _runAdminAction(Future<void> action, String success) async {
    try {
      await action;
      if (!mounted) return;
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(_adminRepo.lastSyncError ?? success)));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: const Color(0xFFE11D48), content: Text('Action not saved: $e')));
    }
  }


  static const List<Map<String, String>> _availablePermissions = [
    {
      'code': 'APPROVE_PETS',
      'title': 'Approve Pet Listings',
      'desc': 'Review & approve submitted shelter & rescuer listings',
    },
    {
      'code': 'FLAG_CONTENT',
      'title': 'Moderate & Ban Content',
      'desc': 'Take down fraudulent or commercial selling posts',
    },
    {
      'code': 'REVIEW_APPLICATIONS',
      'title': 'Review Adoptions',
      'desc': 'Inspect digital e-contracts & foster trial timelines',
    },
    {
      'code': 'MANAGE_USERS',
      'title': 'User Account Bans',
      'desc': 'Block malicious accounts & revoke active JWT sessions',
    },
    {
      'code': 'AUDIT_LOGS',
      'title': 'Security Audit Trail',
      'desc': 'View immutable platform security & administrative logs',
    },
  ];

  void _handleToggleBlock(AdminManagedUser user, bool block) {
    if (block) {
      // Show confirmation dialog before banning and invalidating tokens
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: const [
              Icon(Icons.gavel, color: Color(0xFFE11D48)),
              SizedBox(width: 8),
              Text(
                'Ban User & Revoke Tokens',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Are you sure you want to ban ${user.name} (${user.email})?',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF1F2),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFFDA4AF)),
                ),
                child: const Text(
                  'SECURITY NOTICE:\nThis action will immediately invalidate all active JWT refresh tokens and kill all open web/mobile sessions for this account.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF9F1239),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE11D48),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: () {
                Navigator.pop(ctx);
                _runAdminAction(_adminRepo.blockUser(user.id), '${user.name} banned; sessions revoked.');
              },
              child: const Text('Confirm Ban & Revoke'),
            ),
          ],
        ),
      );
    } else {
      // Unblock user
      _runAdminAction(_adminRepo.unblockUser(user.id), '${user.name} unblocked. A fresh login is required.');
    }
  }

  void _showRoleDelegationModal(AdminManagedUser user) {
    UserRole selectedRole = user.role;
    List<String> selectedPerms = List<String>.from(user.permissions);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            title: Row(
              children: [
                const Icon(Icons.shield_outlined, color: Color(0xFF6366F1)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Delegate Role & Permissions: ${user.name}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            content: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: 540,
                maxHeight: MediaQuery.of(ctx).size.height * 0.8,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'User Email: ${user.email}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(height: 14),

                    const Text(
                      'Assign Primary Platform Role:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFCBD5E1)),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<UserRole>(
                          value: selectedRole,
                          isExpanded: true,
                          items: const [
                            DropdownMenuItem(
                              value: UserRole.adopter,
                              child: Text('Regular Adopter (USER)'),
                            ),
                            DropdownMenuItem(
                              value: UserRole.shelter,
                              child: Text('Shelter / Rescue Org (SHELTER)'),
                            ),
                            DropdownMenuItem(
                              value: UserRole.foster,
                              child: Text('Foster Parent (FOSTER)'),
                            ),
                            DropdownMenuItem(
                              value: UserRole.moderator,
                              child: Text('Volunteer Moderator (MODERATOR)'),
                            ),
                            DropdownMenuItem(
                              value: UserRole.admin,
                              child: Text('Platform Administrator (ADMIN)'),
                            ),
                            DropdownMenuItem(
                              value: UserRole.superAdmin,
                              child: Text('Super Administrator (SUPER_ADMIN)'),
                            ),
                          ],
                          onChanged: (val) {
                            if (val != null) {
                              setDialogState(() {
                                selectedRole = val;
                                // Automatically preset permissions if becoming a moderator
                                if (val == UserRole.moderator &&
                                    selectedPerms.isEmpty) {
                                  selectedPerms = [
                                    'APPROVE_PETS',
                                    'FLAG_CONTENT',
                                    'REVIEW_APPLICATIONS',
                                  ];
                                } else if (val == UserRole.admin ||
                                    val == UserRole.superAdmin) {
                                  selectedPerms = _availablePermissions
                                      .map((p) => p['code']!)
                                      .toList();
                                }
                              });
                            }
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),

                    const Text(
                      'Granular Moderation Permissions:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Select the specific capabilities granted to this user in the Admin & Moderation panel.',
                      style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                    ),
                    const SizedBox(height: 10),

                    ..._availablePermissions.map((perm) {
                      final code = perm['code']!;
                      final isChecked = selectedPerms.contains(code);

                      return Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        decoration: BoxDecoration(
                          color: isChecked
                              ? const Color(0xFFEEF2FF)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isChecked
                                ? const Color(0xFF818CF8)
                                : const Color(0xFFE2E8F0),
                          ),
                        ),
                        child: CheckboxListTile(
                          dense: true,
                          value: isChecked,
                          title: Text(
                            perm['title']!,
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                              color: isChecked
                                  ? const Color(0xFF3730A3)
                                  : const Color(0xFF1E293B),
                            ),
                          ),
                          subtitle: Text(
                            perm['desc']!,
                            style: TextStyle(
                              fontSize: 10.5,
                              color: isChecked
                                  ? const Color(0xFF4F46E5)
                                  : const Color(0xFF64748B),
                            ),
                          ),
                          activeColor: const Color(0xFF6366F1),
                          onChanged: (val) {
                            setDialogState(() {
                              if (val == true) {
                                selectedPerms.add(code);
                              } else {
                                selectedPerms.remove(code);
                              }
                            });
                          },
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6366F1),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                icon: const Icon(Icons.check, size: 16),
                label: const Text('Save Privileges'),
                onPressed: () {
                  Navigator.pop(ctx);
                  _runAdminAction(_adminRepo.updateUserRole(user.id, selectedRole,
                    permissions: selectedPerms), 'Privileges updated for ${user.name}.');
                },
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final users = _adminRepo.getUsers().where((u) {
      if (_searchQuery.isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      return u.name.toLowerCase().contains(q) ||
          u.email.toLowerCase().contains(q) ||
          u.phone.contains(q);
    }).toList();

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_adminError != null) Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(children: [Expanded(child: Text(_adminError!,
              style: const TextStyle(color: Color(0xFFE11D48)))),
              TextButton(onPressed: _loadAdminData, child: const Text('Retry'))]),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'User Directory, Moderation & Access Control',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Enforce immediate user bans with JWT token revocation, and delegate moderation privileges.',
                    style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                  ),
                ],
              ),
              SizedBox(
                width: 280,
                height: 40,
                child: TextField(
                  onChanged: (val) => setState(() => _searchQuery = val.trim()),
                  style: const TextStyle(fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Search user by name, email...',
                    hintStyle: const TextStyle(
                      color: Color(0xFF94A3B8),
                      fontSize: 12,
                    ),
                    prefixIcon: const Icon(
                      Icons.search,
                      size: 18,
                      color: Color(0xFF94A3B8),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          Expanded(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.02),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: SingleChildScrollView(
                  scrollDirection: Axis.vertical,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minWidth: 1050),
                      child: DataTable(
                        headingRowColor: MaterialStateProperty.all(
                          const Color(0xFFF8FAFC),
                        ),
                        horizontalMargin: 20,
                        columnSpacing: 22,
                        columns: const [
                          DataColumn(
                            label: Text(
                              'USER PROFILE',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                                color: Color(0xFF475569),
                              ),
                            ),
                          ),
                          DataColumn(
                            label: Text(
                              'CONTACT',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                                color: Color(0xFF475569),
                              ),
                            ),
                          ),
                          DataColumn(
                            label: Text(
                              'ASSIGNED ROLE',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                                color: Color(0xFF475569),
                              ),
                            ),
                          ),
                          DataColumn(
                            label: Text(
                              'PERMISSIONS',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                                color: Color(0xFF475569),
                              ),
                            ),
                          ),
                          DataColumn(
                            label: Text(
                              'STATUS',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                                color: Color(0xFF475569),
                              ),
                            ),
                          ),
                          DataColumn(
                            label: Text(
                              'BAN / UNBLOCK',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                                color: Color(0xFF475569),
                              ),
                            ),
                          ),
                          DataColumn(
                            label: Text(
                              'DELEGATE',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                                color: Color(0xFF475569),
                              ),
                            ),
                          ),
                        ],
                        rows: users.map((u) {
                          final isBanned = u.isBanned;

                          return DataRow(
                            cells: [
                              DataCell(
                                Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 16,
                                      backgroundColor: isBanned
                                          ? const Color(0xFFFFE4E6)
                                          : const Color(0xFFE0E7FF),
                                      child: Text(
                                        u.name.isNotEmpty ? u.name[0] : 'U',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: isBanned
                                              ? const Color(0xFFE11D48)
                                              : const Color(0xFF4338CA),
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          u.name,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 13,
                                            color: Color(0xFF0F172A),
                                          ),
                                        ),
                                        Text(
                                          u.id,
                                          style: const TextStyle(
                                            fontSize: 10,
                                            color: Color(0xFF94A3B8),
                                            fontFamily: 'monospace',
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              DataCell(
                                Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      u.email,
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                    Text(
                                      u.phone,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: Color(0xFF64748B),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              DataCell(_buildRoleBadge(u.role.code)),
                              DataCell(_buildPermissionsSummary(u.permissions)),
                              DataCell(_buildStatusBadge(u.status)),
                              DataCell(
                                Row(
                                  children: [
                                    Switch(
                                      value: !isBanned,
                                      activeColor: const Color(0xFF10B981),
                                      activeTrackColor: const Color(0xFFA7F3D0),
                                      inactiveThumbColor: const Color(
                                        0xFFE11D48,
                                      ),
                                      inactiveTrackColor: const Color(
                                        0xFFFECDD3,
                                      ),
                                      onChanged: (isActive) {
                                        // If toggling off, ban; if toggling on, unblock
                                        _handleToggleBlock(u, !isActive);
                                      },
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      isBanned ? 'Unblock' : 'Active',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: isBanned
                                            ? const Color(0xFFE11D48)
                                            : const Color(0xFF059669),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              DataCell(
                                OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 6,
                                    ),
                                    side: const BorderSide(
                                      color: Color(0xFFCBD5E1),
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  icon: const Icon(
                                    Icons.security,
                                    size: 14,
                                    color: Color(0xFF6366F1),
                                  ),
                                  label: const Text(
                                    'Privileges',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Color(0xFF334155),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  onPressed: () => _showRoleDelegationModal(u),
                                ),
                              ),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoleBadge(String roleCode) {
    Color bg;
    Color fg;
    switch (roleCode) {
      case 'SUPER_ADMIN':
        bg = const Color(0xFFFEF3C7);
        fg = const Color(0xFFB45309);
        break;
      case 'ADMIN':
        bg = const Color(0xFFEEF2FF);
        fg = const Color(0xFF4338CA);
        break;
      case 'MODERATOR':
        bg = const Color(0xFFF3E8FF);
        fg = const Color(0xFF7E22CE);
        break;
      case 'SHELTER':
        bg = const Color(0xFFECFDF5);
        fg = const Color(0xFF047857);
        break;
      default:
        bg = const Color(0xFFF1F5F9);
        fg = const Color(0xFF475569);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        roleCode,
        style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildPermissionsSummary(List<String> perms) {
    if (perms.isEmpty) {
      return const Text(
        'None',
        style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
      );
    }
    return Wrap(
      spacing: 4,
      runSpacing: 2,
      children:
          perms.take(2).map((p) {
            String label = p.replaceAll('_', ' ').toLowerCase();
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 10,
                  color: Color(0xFF334155),
                  fontWeight: FontWeight.w600,
                ),
              ),
            );
          }).toList()..addAll(
            perms.length > 2
                ? [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 2,
                      ),
                      child: Text(
                        '+${perms.length - 2} more',
                        style: const TextStyle(
                          fontSize: 10,
                          color: Color(0xFF6366F1),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ]
                : [],
          ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color bg;
    Color fg;
    final s = status.toUpperCase();
    if (s == 'ACTIVE') {
      bg = const Color(0xFFECFDF5);
      fg = const Color(0xFF059669);
    } else if (s == 'SUSPENDED') {
      bg = const Color(0xFFFFFBEB);
      fg = const Color(0xFFD97706);
    } else {
      bg = const Color(0xFFFFF1F2);
      fg = const Color(0xFFE11D48);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status,
        style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.bold),
      ),
    );
  }
}
