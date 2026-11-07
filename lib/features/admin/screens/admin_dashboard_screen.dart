import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../shared/widgets/app_network_image.dart';

import '../../../core/models/application_model.dart';
import '../../../core/models/pet_model.dart';
import '../../../core/models/appointment_model.dart';
import '../../../core/repositories/application_repository.dart';
import '../../../core/repositories/pet_repository.dart';
import '../../../core/repositories/appointment_repository.dart';
import '../../../core/repositories/admin_repository.dart';
import '../../auth/bloc/auth_bloc.dart';
import '../widgets/admin_kpi_card.dart';
import '../widgets/admin_create_pet_dialog.dart';

extension PetAdoptionStatusExtension on Pet {
  bool get isAdopted => story.contains('[ADOPTED]');
}

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final _appRepo = ApplicationRepository();
  final _petRepo = PetRepository();
  final _aptRepo = AppointmentRepository();
  final _adminRepo = AdminRepository();

  StreamSubscription<List<AdoptionApplication>>? _appSub;
  StreamSubscription<List<Pet>>? _petSub;
  StreamSubscription<List<AdoptionAppointment>>? _aptSub;
  StreamSubscription<dynamic>? _auditSub;

  List<AdoptionApplication> _applications = [];
  List<Pet> _pets = [];
  List<AdoptionAppointment> _appointments = [];
  bool _isLoading = false;

  // Bilingual Mode Toggle (English / বাংলা)
  bool _isBangla = false;

  // Search & Filters
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _dateFilter = 'all'; // 'all', 'today', 'week', 'month'

  // Tab-specific filters
  ApplicationStatus? _appFilter;
  String _petFilter = 'all'; // 'all', 'available', 'adopted', 'urgent'
  AppointmentStatus? _aptFilter;

  // Bulk Selection States
  final Set<String> _selectedAppIds = {};

  // Emergency SOS Alert State
  bool _showEmergencySos = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });

    _loadInitialData();

    _appSub = _appRepo.applicationsStream.listen((apps) {
      if (mounted) setState(() => _applications = apps);
    });
    _petSub = _petRepo.petsStream.listen((pets) {
      if (mounted) setState(() => _pets = pets);
    });
    _aptSub = _aptRepo.appointmentsStream.listen((apts) {
      if (mounted) setState(() => _appointments = apts);
    });
    _auditSub = _adminRepo.auditLogsStream.listen((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _appSub?.cancel();
    _petSub?.cancel();
    _aptSub?.cancel();
    _auditSub?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    try {
      final apps = await _appRepo.getApplications();
      final pets = await _petRepo.getAllPets();
      final apts = await _aptRepo.getAppointments();
      if (mounted) {
        setState(() {
          _applications = apps;
          _pets = pets;
          _appointments = apts;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('[AdminDashboard] Initial load warning: $e');
    }
  }

  // ==========================================
  // ACTION LOGIC & AUDIT TRAIL HELPERS
  // ==========================================
  void _batchApproveApplications() {
    if (_selectedAppIds.isEmpty) return;
    final count = _selectedAppIds.length;
    final authState = context.read<AuthBloc>().state;
    final adminName = authState is Authenticated ? authState.user.name : 'Admin';

    for (final id in _selectedAppIds) {
      _appRepo.updateApplicationStatus(id, ApplicationStatus.approved, notes: 'Batch approved by $adminName');
    }

    _adminRepo.recordAuditLog(
      actorName: adminName,
      action: 'BATCH_APPROVE_APPLICATIONS',
      target: '$count Applications',
      details: 'Approved $count adoption requests via bulk batch action queue.',
    );

    setState(() => _selectedAppIds.clear());

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_isBangla ? '$countটি আবেদন সফলভাবে অনুমোদন করা হয়েছে!' : 'Successfully approved $count applications!'),
        backgroundColor: const Color(0xFF0D9488),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _batchRejectApplications() {
    if (_selectedAppIds.isEmpty) return;
    final count = _selectedAppIds.length;
    final authState = context.read<AuthBloc>().state;
    final adminName = authState is Authenticated ? authState.user.name : 'Admin';

    for (final id in _selectedAppIds) {
      _appRepo.updateApplicationStatus(id, ApplicationStatus.rejected, notes: 'Batch declined by $adminName');
    }

    _adminRepo.recordAuditLog(
      actorName: adminName,
      action: 'BATCH_REJECT_APPLICATIONS',
      target: '$count Applications',
      details: 'Declined $count adoption requests via bulk batch action queue.',
    );

    setState(() => _selectedAppIds.clear());

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_isBangla ? '$countটি আবেদন প্রত্যাখ্যান করা হয়েছে।' : 'Declined $count applications.'),
        backgroundColor: const Color(0xFFE11D48),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showPushNotificationDispatcher() {
    final titleController = TextEditingController(text: '🐾 Emergency Rescue Alert');
    final messageController = TextEditingController(
      text: 'Special adoption drive active this weekend in Dhaka. Foster parents urgently needed!',
    );
    String targetAudience = 'All Users in Dhaka (5km)';
    bool isUrgent = true;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF0D9488).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.campaign_rounded, color: Color(0xFF0D9488), size: 22),
              ),
              const SizedBox(width: 12),
              Text(
                _isBangla ? 'পুশ নোটিফিকেশন ডিসপ্যাচার' : 'Push Alert Dispatcher',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isBangla ? 'টার্গেট অডিয়েন্স নির্বাচন করুন:' : 'Target Audience:',
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  value: targetAudience,
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  items: [
                    'All Users in Dhaka (5km)',
                    'Verified Shelters Network',
                    'Active Foster Parents',
                    'All AdoptMatch Users',
                  ].map((s) => DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(fontSize: 13)))).toList(),
                  onChanged: (val) => setDlgState(() => targetAudience = val ?? targetAudience),
                ),
                const SizedBox(height: 14),
                Text(
                  _isBangla ? 'শিরোনাম (Title):' : 'Alert Title:',
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: titleController,
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  _isBangla ? 'মেসেজ বিবরণ (Message Body):' : 'Message Body:',
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: messageController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 10),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    _isBangla ? 'জরুরি অগ্রাধিকার (High Priority Sound & Vibrate)' : 'High Priority Sound & Vibrate',
                    style: const TextStyle(fontSize: 13),
                  ),
                  value: isUrgent,
                  activeColor: const Color(0xFF0D9488),
                  onChanged: (v) => setDlgState(() => isUrgent = v),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(_isBangla ? 'বাতিল' : 'Cancel', style: const TextStyle(color: Colors.grey)),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0D9488),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              icon: const Icon(Icons.send_rounded, size: 16),
              label: Text(_isBangla ? 'ব্রডকাস্ট পাঠান' : 'Broadcast Alert'),
              onPressed: () {
                Navigator.pop(ctx);
                final authState = context.read<AuthBloc>().state;
                final adminName = authState is Authenticated ? authState.user.name : 'Admin';

                _adminRepo.recordAuditLog(
                  actorName: adminName,
                  action: 'BROADCAST_PUSH_ALERT',
                  target: targetAudience,
                  details: 'Broadcast: "${titleController.text.trim()}". Body: "${messageController.text.trim()}"',
                );

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      _isBangla
                          ? 'পুশ অ্যালার্ট সফলভাবে ব্রডকাস্ট করা হয়েছে ($targetAudience)!'
                          : 'Push alert broadcasted successfully to $targetAudience!',
                    ),
                    backgroundColor: const Color(0xFF0D9488),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showExportDataDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF6366F1).withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.file_download_outlined, color: Color(0xFF6366F1), size: 22),
            ),
            const SizedBox(width: 12),
            Text(
              _isBangla ? 'অ্যাডমিন রিপোর্ট এক্সপোর্ট' : 'Export Admin Report',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _isBangla
                  ? 'আপনার প্রয়োজনীয় ফরম্যাটে ডাটা এক্সপোর্ট করুন:'
                  : 'Select report format to download operational metrics & logs:',
              style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 16),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: const Color(0xFF0D9488).withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.table_chart_rounded, color: Color(0xFF0D9488)),
              ),
              title: const Text('Adoption Applications (CSV)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
              subtitle: const Text('Full pipeline records, adopter contacts & vetting history', style: TextStyle(fontSize: 11)),
              trailing: const Icon(Icons.download_rounded, color: Color(0xFF0D9488)),
              onTap: () {
                Navigator.pop(ctx);
                _triggerExportFeedback('Adoption_Applications_Export.csv');
              },
            ),
            const Divider(),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: const Color(0xFFE11D48).withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.picture_as_pdf_rounded, color: Color(0xFFE11D48)),
              ),
              title: const Text('Shelter Audit Summary (PDF)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
              subtitle: const Text('Official monthly verification & compliance certification', style: TextStyle(fontSize: 11)),
              trailing: const Icon(Icons.download_rounded, color: Color(0xFFE11D48)),
              onTap: () {
                Navigator.pop(ctx);
                _triggerExportFeedback('Shelter_Performance_Audit.pdf');
              },
            ),
            const Divider(),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: const Color(0xFF6366F1).withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.pets_rounded, color: Color(0xFF6366F1)),
              ),
              title: const Text('Pet Inventory & Microchips (CSV)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
              subtitle: const Text('Complete roster of active rescues and vaccine passports', style: TextStyle(fontSize: 11)),
              trailing: const Icon(Icons.download_rounded, color: Color(0xFF6366F1)),
              onTap: () {
                Navigator.pop(ctx);
                _triggerExportFeedback('Pet_Inventory_Registry.csv');
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(_isBangla ? 'বন্ধ করুন' : 'Close', style: const TextStyle(color: Colors.grey)),
          ),
        ],
      ),
    );
  }

  void _triggerExportFeedback(String filename) {
    final authState = context.read<AuthBloc>().state;
    final adminName = authState is Authenticated ? authState.user.name : 'Admin';

    _adminRepo.recordAuditLog(
      actorName: adminName,
      action: 'EXPORT_ADMIN_REPORT',
      target: filename,
      details: 'Generated and downloaded encrypted operational export file.',
    );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _isBangla ? '$filename সফলভাবে জেনারেট হয়েছে এবং ডাউনলোড রেডি!' : '$filename exported successfully & ready for download!',
                style: const TextStyle(fontSize: 13),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF0F172A),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _handleEmergencyRescueDispatch() {
    final authState = context.read<AuthBloc>().state;
    final adminName = authState is Authenticated ? authState.user.name : 'Admin';

    _adminRepo.recordAuditLog(
      actorName: adminName,
      action: 'DISPATCH_RESCUE_TEAM',
      target: 'SOS-Mirpur10',
      details: 'Emergency rescue unit dispatched for injured puppy report near Mirpur 10.',
    );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _isBangla
              ? '🚑 ইমার্জেন্সি রেসকিউ টিম ঘটনাস্থলে পাঠানো হয়েছে! কন্টাক্ট নোটিফিকেশন প্রেরিত।'
              : '🚑 Emergency Rescue Unit dispatched to location! Contact notification sent.',
        ),
        backgroundColor: const Color(0xFFE11D48),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ==========================================
  // BUILD SCREEN LAYOUT
  // ==========================================
  @override
  Widget build(BuildContext context) {
    final activeRescuesCount = _pets.length;
    final pendingAppsCount = _applications.where((a) => a.status == ApplicationStatus.underReview || a.status == ApplicationStatus.submitted).length;
    final homeVisitsCount = _appointments.where((apt) => apt.status == AppointmentStatus.confirmed || apt.status == AppointmentStatus.pending).length;
    final trialFostersCount = _applications.where((a) => a.status == ApplicationStatus.fosterTrial).length;
    final adoptionsCompletedCount = _applications.where((a) => a.status == ApplicationStatus.approved).length;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: _buildPageHeader(),
      drawer: _buildAdminDrawer(context),
      body: Stack(
        children: [
          if (_isLoading)
            const Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: LinearProgressIndicator(
                color: Color(0xFF0D9488),
                backgroundColor: Colors.transparent,
                minHeight: 2.5,
              ),
            ),
          NestedScrollView(
            headerSliverBuilder: (context, innerBoxIsScrolled) {
              return [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 1. Live Emergency SOS Broadcast Card (5km Radius)
                        if (_showEmergencySos) _buildEmergencySosCard(),

                        // 2. Section Header: Shelter Performance Overview
                        _buildSectionHeader(),
                        const SizedBox(height: 16),

                        // 3. Fully Clickable KPI Cards (Top of Dashboard)
                        _buildKpiCardsRow(
                          activeRescues: activeRescuesCount,
                          pendingApps: pendingAppsCount,
                          homeVisits: homeVisitsCount,
                          trialFosters: trialFostersCount,
                          adoptionsCompleted: adoptionsCompletedCount,
                        ),
                        const SizedBox(height: 20),

                        // 4. Global Search & Date Filter Bar
                        _buildSearchAndFilterBar(),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),
                // 5. Persistent TabBar Header: [Apps, Pets, Visits, Analytics]
                SliverPersistentHeader(
                  pinned: true,
                  delegate: _SliverTabBarDelegate(
                    TabBar(
                      controller: _tabController,
                      labelColor: const Color(0xFF0D9488),
                      unselectedLabelColor: const Color(0xFF64748B),
                      indicatorColor: const Color(0xFF0D9488),
                      indicatorWeight: 3,
                      labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      tabs: [
                        Tab(
                          text: _isBangla ? 'আবেদন (${_applications.length})' : 'Apps (${_applications.length})',
                          icon: const Icon(Icons.description_outlined, size: 18),
                        ),
                        Tab(
                          text: _isBangla ? 'পোষ্য (${_pets.length})' : 'Pets (${_pets.length})',
                          icon: const Icon(Icons.pets_rounded, size: 18),
                        ),
                        Tab(
                          text: _isBangla ? 'ভিজিট (${_appointments.length})' : 'Visits (${_appointments.length})',
                          icon: const Icon(Icons.home_work_outlined, size: 18),
                        ),
                        Tab(
                          text: _isBangla ? 'অ্যানালিটিক্স ও অডিট' : 'Analytics & Audit',
                          icon: const Icon(Icons.analytics_outlined, size: 18),
                        ),
                      ],
                    ),
                  ),
                ),
              ];
            },
            body: TabBarView(
              controller: _tabController,
              children: [
                _buildApplicationsQueueTab(),
                _buildPetInventoryTab(),
                _buildVisitsAndAppointmentsTab(),
                _buildAnalyticsAndAuditTab(),
              ],
            ),
          ),

          // Pinned Floating Batch Action Bar (When items selected)
          if (_selectedAppIds.isNotEmpty) _buildBatchActionBar(),
        ],
      ),

      // Floating Action Button: "Add Rescue Pet / পোষ্য যোগ"
      floatingActionButton: Padding(
        padding: EdgeInsets.only(bottom: _selectedAppIds.isNotEmpty ? 64 : 0),
        child: FloatingActionButton.extended(
          onPressed: () => showAdminCreatePetDialog(context),
          backgroundColor: const Color(0xFF0D9488),
          foregroundColor: Colors.white,
          elevation: 4,
          icon: const Icon(Icons.add_circle_outline_rounded, size: 20),
          label: Text(
            _isBangla ? 'পোষ্য যোগ করুন' : 'Add Rescue Pet / পোষ্য যোগ',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),
        ),
      ),
    );
  }

  // ==========================================
  // 1. PAGE APPBAR / HEADER
  // ==========================================
  PreferredSizeWidget _buildPageHeader() {
    return AppBar(
      backgroundColor: const Color(0xFF0F172A),
      elevation: 1,
      centerTitle: false,
      leading: Builder(
        builder: (context) => IconButton(
          icon: const Icon(Icons.menu_rounded, color: Colors.white, size: 24),
          tooltip: 'Admin Menu',
          onPressed: () => Scaffold.of(context).openDrawer(),
        ),
      ),
      title: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFF0D9488),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.shield_rounded, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 8),
            Text(
              _isBangla ? 'শেল্টার ম্যানেজমেন্ট অ্যাডমিন' : 'Shelter Management Admin',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 16.5,
                letterSpacing: -0.2,
              ),
            ),
          ],
        ),
      ),
      actions: [
        // Push Alert Dispatcher
        IconButton(
          icon: const Icon(Icons.campaign_rounded, color: Color(0xFF38BDF8), size: 22),
          tooltip: _isBangla ? 'পুশ অ্যালার্ট পাঠান' : 'Dispatch Push Alert',
          onPressed: _showPushNotificationDispatcher,
        ),
        // Export Report (CSV / PDF)
        IconButton(
          icon: const Icon(Icons.file_download_outlined, color: Color(0xFFFBBF24), size: 22),
          tooltip: _isBangla ? 'রিপোর্ট এক্সপোর্ট (CSV/PDF)' : 'Export Report (CSV/PDF)',
          onPressed: _showExportDataDialog,
        ),
        // Bilingual Switch
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: ActionChip(
            backgroundColor: _isBangla ? const Color(0xFF0D9488) : const Color(0xFF1E293B),
            side: BorderSide(color: _isBangla ? const Color(0xFF0D9488) : const Color(0xFF475569)),
            label: Text(
              _isBangla ? 'বাং' : 'EN',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
            ),
            onPressed: () => setState(() => _isBangla = !_isBangla),
          ),
        ),
        // Logout Icon
        IconButton(
          icon: const Icon(Icons.logout_rounded, color: Color(0xFFEF4444), size: 20),
          tooltip: _isBangla ? 'লগআউট' : 'Sign Out',
          onPressed: _showLogoutConfirmation,
        ),
        const SizedBox(width: 4),
      ],
    );
  }

  void _showLogoutConfirmation() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          _isBangla ? 'লগআউট নিশ্চিতকরণ' : 'Confirm Admin Logout',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Text(
          _isBangla
              ? 'আপনি কি নিশ্চিত যে আপনার অ্যাডমিন সেশন শেষ করতে চান?'
              : 'Are you sure you want to end your administrative session?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              _isBangla ? 'বাতিল' : 'Cancel',
              style: const TextStyle(color: Colors.grey),
            ),
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
            child: Text(_isBangla ? 'লগআউট' : 'Logout'),
          ),
        ],
      ),
    );
  }

  Widget _buildAdminDrawer(BuildContext context) {
    final authState = context.read<AuthBloc>().state;
    final user = authState is Authenticated ? authState.user : null;
    final roleName = user?.role.code ?? 'ADMIN';
    final adminName = user?.name ?? 'Administrator';

    return Drawer(
      backgroundColor: const Color(0xFF0F172A),
      child: SafeArea(
        child: Column(
          children: [
            // Drawer Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: Color(0xFF1E293B),
                border: Border(bottom: BorderSide(color: Color(0xFF334155))),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Image.asset(
                      'assets/images/app_logo.png',
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) =>
                          const Icon(Icons.shield_outlined, color: Color(0xFF0D9488), size: 28),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          adminName,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0D9488).withOpacity(0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            roleName,
                            style: const TextStyle(color: Color(0xFF14B8A6), fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Navigation Links
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  _drawerItem(
                    icon: Icons.dashboard_outlined,
                    label: _isBangla ? 'ড্যাশবোর্ড ওভারভিউ' : 'Dashboard Overview',
                    selected: true,
                    onTap: () => Navigator.pop(context),
                  ),
                  _drawerItem(
                    icon: Icons.verified_user_outlined,
                    label: _isBangla ? 'সেল্টার অনুমোদন' : 'Shelter Approvals',
                    onTap: () {
                      Navigator.pop(context);
                      context.push('/admin/shelters');
                    },
                  ),
                  _drawerItem(
                    icon: Icons.pets_outlined,
                    label: _isBangla ? 'পোষ্য মডারেশন' : 'Pet Moderation',
                    onTap: () {
                      Navigator.pop(context);
                      context.push('/admin/pets');
                    },
                  ),
                  _drawerItem(
                    icon: Icons.track_changes_outlined,
                    label: _isBangla ? 'অ্যাডপশন ট্র্যাকিং' : 'Adoption Pipeline',
                    onTap: () {
                      Navigator.pop(context);
                      context.push('/admin/adoptions');
                    },
                  ),
                  _drawerItem(
                    icon: Icons.people_outline_rounded,
                    label: _isBangla ? 'ইউজার ম্যানেজমেন্ট' : 'User Management',
                    onTap: () {
                      Navigator.pop(context);
                      context.push('/admin/users');
                    },
                  ),
                  _drawerItem(
                    icon: Icons.workspace_premium_outlined,
                    label: _isBangla ? 'ভিআইপি সাবস্ক্রিপশন' : 'VIP Subscriptions',
                    onTap: () {
                      Navigator.pop(context);
                      context.push('/admin/subscriptions');
                    },
                  ),
                  _drawerItem(
                    icon: Icons.history_rounded,
                    label: _isBangla ? 'অডিট ট্রেইল লগ' : 'Audit Logs',
                    onTap: () {
                      Navigator.pop(context);
                      context.push('/admin/audit-logs');
                    },
                  ),
                  const Divider(color: Color(0xFF334155)),
                  _drawerItem(
                    icon: Icons.home_outlined,
                    label: _isBangla ? 'ইউজার হোমপেজে ফিরে যান' : 'Back to User App',
                    onTap: () {
                      Navigator.pop(context);
                      context.go('/home');
                    },
                  ),
                ],
              ),
            ),

            // Logout & Exit
            const Divider(color: Color(0xFF334155), height: 1),
            ListTile(
              leading: const Icon(Icons.logout_rounded, color: Color(0xFFEF4444)),
              title: Text(
                _isBangla ? 'লগআউট' : 'Sign Out',
                style: const TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.bold),
              ),
              onTap: () {
                Navigator.pop(context);
                _showLogoutConfirmation();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _drawerItem({
    required IconData icon,
    required String label,
    bool selected = false,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: selected ? const Color(0xFF14B8A6) : const Color(0xFF94A3B8), size: 20),
      title: Text(
        label,
        style: TextStyle(
          color: selected ? Colors.white : const Color(0xFFCBD5E1),
          fontWeight: selected ? FontWeight.bold : FontWeight.w500,
          fontSize: 13.5,
        ),
      ),
      selected: selected,
      selectedTileColor: const Color(0xFF0D9488).withOpacity(0.15),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      onTap: onTap,
    );
  }

  // ==========================================
  // 2. LIVE EMERGENCY RESCUE WIDGET (5KM)
  // ==========================================
  Widget _buildEmergencySosCard() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF1F2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFECDD3), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFE11D48).withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE11D48),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.emergency_rounded, color: Colors.white, size: 12),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          _isBangla ? '🚨 লাইভ ইমার্জেন্সি এসওএস • ৫ কিমি' : '🚨 LIVE EMERGENCY SOS • 5km',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 10),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: const Icon(Icons.close_rounded, size: 18, color: Color(0xFF94A3B8)),
                onPressed: () => setState(() => _showEmergencySos = false),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _isBangla
                ? 'আহত কুকুর ছানা মিরপুর ১০ গোলচত্বরের কাছে উদ্ধার করা হয়েছে। জরুরি চিকিৎসার সহায়তা প্রয়োজন।'
                : 'Injured stray pup reported near Mirpur 10 circle • Urgent veterinary attention requested.',
            style: const TextStyle(color: Color(0xFF881337), fontWeight: FontWeight.bold, fontSize: 13),
          ),
          const SizedBox(height: 4),
          const Text(
            'Reporter: Tanvir Ahmed (+880 1711-234567) • 12 mins ago',
            style: TextStyle(color: Color(0xFF9F1239), fontSize: 11),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: [
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE11D48),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  elevation: 0,
                ),
                icon: const Icon(Icons.local_hospital_rounded, size: 14),
                label: Text(_isBangla ? 'রেসকিউ টিম পাঠান' : 'Dispatch Rescue Team', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                onPressed: _handleEmergencyRescueDispatch,
              ),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF9F1239),
                  side: const BorderSide(color: Color(0xFFFDA4AF)),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                icon: const Icon(Icons.phone_rounded, size: 14),
                label: Text(_isBangla ? 'কল দিন' : 'Call Reporter', style: const TextStyle(fontSize: 12)),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Calling Tanvir Ahmed (+880 1711-234567)...'), duration: Duration(seconds: 2)),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ==========================================
  // 3. SECTION HEADER
  // ==========================================
  Widget _buildSectionHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _isBangla ? 'শেল্টার পারফরম্যান্স ওভারভিউ' : 'Shelter Performance Overview',
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: Color(0xFF0F172A),
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          _isBangla
              ? 'রিয়েল-টাইম অ্যাডপশন মেট্রিক্স ও পাইপলাইন ট্র্যাকিং'
              : 'Real-time ethical adoption metrics and pipeline tracking.',
          style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
        ),
      ],
    );
  }

  // ==========================================
  // 4. CLICKABLE KPI CARDS ROW (TOP OF DASHBOARD)
  // ==========================================
  Widget _buildKpiCardsRow({
    required int activeRescues,
    required int pendingApps,
    required int homeVisits,
    required int trialFosters,
    required int adoptionsCompleted,
  }) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: [
          // 1. Active Rescues -> Pets Tab (Status: ACTIVE / available)
          AdminKpiCard(
            title: _isBangla ? 'সক্রিয় পোষ্য' : 'Active Rescues',
            count: '$activeRescues',
            icon: Icons.pets_rounded,
            accentColor: const Color(0xFF0D9488),
            subtitle: _isBangla ? 'সকল পোষ্য দেখুন' : 'View in Pets tab',
            isSelected: _tabController.index == 1 && _petFilter == 'available',
            onTap: () {
              setState(() {
                _petFilter = 'available';
                _tabController.animateTo(1);
              });
            },
          ),
          const SizedBox(width: 12),

          // 2. Total Applications -> Apps Tab (Status: PENDING / underReview)
          AdminKpiCard(
            title: _isBangla ? 'মোট আবেদন' : 'Total Applications',
            count: '$pendingApps',
            icon: Icons.description_outlined,
            accentColor: const Color(0xFF6366F1),
            subtitle: _isBangla ? 'বিবেচনাধীন কিউ' : 'Review pending',
            isSelected: _tabController.index == 0 && _appFilter == ApplicationStatus.underReview,
            onTap: () {
              setState(() {
                _appFilter = ApplicationStatus.underReview;
                _tabController.animateTo(0);
              });
            },
          ),
          const SizedBox(width: 12),

          // 3. Home Visits -> Visits Tab
          AdminKpiCard(
            title: _isBangla ? 'হোম ভিজিট' : 'Home Visits',
            count: '$homeVisits',
            icon: Icons.home_work_outlined,
            accentColor: const Color(0xFF0284C7),
            subtitle: _isBangla ? 'সিডিউল তালিকা' : 'Scheduled list',
            isSelected: _tabController.index == 2,
            onTap: () {
              setState(() {
                _aptFilter = AppointmentStatus.confirmed;
                _tabController.animateTo(2);
              });
            },
          ),
          const SizedBox(width: 12),

          // 4. Trial Fosters -> Apps Tab (Status: fosterTrial)
          AdminKpiCard(
            title: _isBangla ? 'ট্রায়াল ফস্টার' : 'Trial Fosters',
            count: '$trialFosters',
            icon: Icons.volunteer_activism_outlined,
            accentColor: const Color(0xFFF59E0B),
            subtitle: _isBangla ? '১৪ দিনের পর্যবেক্ষণ' : '14-day trials',
            isSelected: _tabController.index == 0 && _appFilter == ApplicationStatus.fosterTrial,
            onTap: () {
              setState(() {
                _appFilter = ApplicationStatus.fosterTrial;
                _tabController.animateTo(0);
              });
            },
          ),
          const SizedBox(width: 12),

          // 5. Adoptions Completed -> Apps Tab (Status: approved / archive)
          AdminKpiCard(
            title: _isBangla ? 'সম্পন্ন অ্যাডপশন' : 'Adoptions Completed',
            count: '$adoptionsCompleted',
            icon: Icons.check_circle_outline_rounded,
            accentColor: const Color(0xFF10B981),
            subtitle: _isBangla ? 'লিগ্যাল চুক্তি ও রেকর্ড' : 'Completed archive',
            isSelected: _tabController.index == 0 && _appFilter == ApplicationStatus.approved,
            onTap: () {
              setState(() {
                _appFilter = ApplicationStatus.approved;
                _tabController.animateTo(0);
              });
            },
          ),
        ],
      ),
    );
  }

  // ==========================================
  // 5. GLOBAL SEARCH & QUICK FILTER BAR
  // ==========================================
  Widget _buildSearchAndFilterBar() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFCBD5E1)),
                ),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: _isBangla
                        ? 'পেট আইডি, নাম, ফোন বা ব্রিড দিয়ে খুঁজুন...'
                        : 'Search by Pet ID, adopter name, phone, or breed...',
                    hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                    prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF64748B), size: 20),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                  onChanged: (val) => setState(() => _searchQuery = val.trim().toLowerCase()),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        // Quick Date Filter Chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildDateChip('all', _isBangla ? 'সকল সময়' : 'All Time'),
              const SizedBox(width: 8),
              _buildDateChip('today', _isBangla ? 'আজকের' : 'Today'),
              const SizedBox(width: 8),
              _buildDateChip('week', _isBangla ? 'এই সপ্তাহের' : 'This Week'),
              const SizedBox(width: 8),
              _buildDateChip('month', _isBangla ? 'এই মাসের' : 'This Month'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDateChip(String value, String label) {
    final isSelected = _dateFilter == value;
    return ChoiceChip(
      label: Text(label, style: TextStyle(fontSize: 12, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
      selected: isSelected,
      selectedColor: const Color(0xFF0D9488).withOpacity(0.15),
      labelStyle: TextStyle(color: isSelected ? const Color(0xFF0D9488) : const Color(0xFF64748B)),
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: isSelected ? const Color(0xFF0D9488) : const Color(0xFFE2E8F0)),
      ),
      onSelected: (selected) {
        if (selected) setState(() => _dateFilter = value);
      },
    );
  }

  // ==========================================
  // TAB 0: APPLICATIONS QUEUE (BULK ACTION ENABLED)
  // ==========================================
  Widget _buildApplicationsQueueTab() {
    var filtered = _applications.where((app) {
      if (_appFilter != null && app.status != _appFilter) return false;
      if (_searchQuery.isNotEmpty) {
        final matchesQuery = app.applicantName.toLowerCase().contains(_searchQuery) ||
            app.applicantPhone.toLowerCase().contains(_searchQuery) ||
            app.petName.toLowerCase().contains(_searchQuery) ||
            app.petBreed.toLowerCase().contains(_searchQuery) ||
            app.id.toLowerCase().contains(_searchQuery);
        if (!matchesQuery) return false;
      }
      return true;
    }).toList();

    return Column(
      children: [
        // Top Status Filter Chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              _buildAppStatusChip(null, _isBangla ? 'সব (${_applications.length})' : 'All Apps (${_applications.length})'),
              const SizedBox(width: 8),
              _buildAppStatusChip(ApplicationStatus.underReview, _isBangla ? 'বিবেচনাধীন' : 'Under Review'),
              const SizedBox(width: 8),
              _buildAppStatusChip(ApplicationStatus.homeVisitScheduled, _isBangla ? 'হোম ভিজিট' : 'Home Visits'),
              const SizedBox(width: 8),
              _buildAppStatusChip(ApplicationStatus.fosterTrial, _isBangla ? 'ট্রায়াল ফস্টার' : 'Trial Foster'),
              const SizedBox(width: 8),
              _buildAppStatusChip(ApplicationStatus.approved, _isBangla ? 'অনুমোদিত' : 'Approved'),
              const SizedBox(width: 8),
              _buildAppStatusChip(ApplicationStatus.rejected, _isBangla ? 'প্রত্যাখ্যাত' : 'Rejected'),
            ],
          ),
        ),

        // List
        Expanded(
          child: filtered.isEmpty
              ? _buildEmptyState(_isBangla ? 'কোনো আবেদন পাওয়া যায়নি' : 'No applications found in this filter.')
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                  itemCount: filtered.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final app = filtered[index];
                    final isChecked = _selectedAppIds.contains(app.id);

                    return _buildApplicationCard(app, isChecked);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildAppStatusChip(ApplicationStatus? status, String label) {
    final isSelected = _appFilter == status;
    return ChoiceChip(
      label: Text(label, style: const TextStyle(fontSize: 12)),
      selected: isSelected,
      selectedColor: const Color(0xFF0D9488),
      labelStyle: TextStyle(color: isSelected ? Colors.white : const Color(0xFF475569), fontWeight: isSelected ? FontWeight.bold : FontWeight.normal),
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: isSelected ? const Color(0xFF0D9488) : const Color(0xFFE2E8F0))),
      onSelected: (val) {
        setState(() => _appFilter = val ? status : null);
      },
    );
  }

  Widget _buildApplicationCard(AdoptionApplication app, bool isChecked) {
    Color statusColor;
    switch (app.status) {
      case ApplicationStatus.approved:
        statusColor = const Color(0xFF10B981);
        break;
      case ApplicationStatus.rejected:
        statusColor = const Color(0xFFE11D48);
        break;
      case ApplicationStatus.fosterTrial:
        statusColor = const Color(0xFFF59E0B);
        break;
      case ApplicationStatus.homeVisitScheduled:
        statusColor = const Color(0xFF0284C7);
        break;
      default:
        statusColor = const Color(0xFF6366F1);
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isChecked ? const Color(0xFF0D9488) : const Color(0xFFE2E8F0), width: isChecked ? 2 : 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          ListTile(
            leading: Checkbox(
              value: isChecked,
              activeColor: const Color(0xFF0D9488),
              onChanged: (val) {
                setState(() {
                  if (val == true) {
                    _selectedAppIds.add(app.id);
                  } else {
                    _selectedAppIds.remove(app.id);
                  }
                });
              },
            ),
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    app.applicantName,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    app.status.displayName,
                    style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 10),
                  ),
                ),
              ],
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text('Pet: ${app.petName} (${app.petBreed}) • ${app.applicantPhone}', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                Text('Housing: ${app.housingType} • Budget: ৳${app.monthlyBudget}/mo', style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
              ],
            ),
            trailing: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 44,
                height: 44,
                child: AppNetworkImage(
                  imageUrl: app.petImageUrl,
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF0D9488),
                    side: const BorderSide(color: Color(0xFF0D9488)),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    minimumSize: const Size(60, 30),
                  ),
                  onPressed: () {
                    _appRepo.updateApplicationStatus(app.id, ApplicationStatus.fosterTrial, notes: 'Moved to 14-day trial foster');
                    _adminRepo.recordAuditLog(
                      actorName: 'Admin',
                      action: 'UPDATE_APP_STATUS',
                      target: app.id,
                      details: 'Moved application for ${app.petName} to 14-day trial foster.',
                    );
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Placed on 14-day trial foster!')));
                  },
                  child: const Text('Trial Foster', style: TextStyle(fontSize: 11)),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0D9488),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                    minimumSize: const Size(60, 30),
                  ),
                  onPressed: () {
                    _appRepo.updateApplicationStatus(app.id, ApplicationStatus.approved, notes: 'Approved by admin dashboard');
                    _adminRepo.recordAuditLog(
                      actorName: 'Admin',
                      action: 'APPROVE_APPLICATION',
                      target: app.id,
                      details: 'Application for ${app.petName} approved for adopter ${app.applicantName}.',
                    );
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Application Approved!')));
                  },
                  child: const Text('Approve', style: TextStyle(fontSize: 11)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // TAB 1: PET INVENTORY (CLICKABLE STATS & STATUS FILTER)
  // ==========================================
  Widget _buildPetInventoryTab() {
    var filtered = _pets.where((p) {
      if (_petFilter == 'available' && p.isAdopted) return false;
      if (_petFilter == 'adopted' && !p.isAdopted) return false;
      if (_petFilter == 'urgent' && !p.isUrgent) return false;
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        return p.name.toLowerCase().contains(q) ||
            p.breed.toLowerCase().contains(q) ||
            p.species.toLowerCase().contains(q) ||
            p.id.toLowerCase().contains(q);
      }
      return true;
    }).toList();

    return Column(
      children: [
        // Pet Status Filter Chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              _buildPetStatusChip('all', _isBangla ? 'সকল পোষ্য (${_pets.length})' : 'All Rescues (${_pets.length})'),
              const SizedBox(width: 8),
              _buildPetStatusChip('available', _isBangla ? 'দত্তক উপযোগী' : 'Available (Active)'),
              const SizedBox(width: 8),
              _buildPetStatusChip('adopted', _isBangla ? 'দত্তক সম্পন্ন' : 'Adopted'),
              const SizedBox(width: 8),
              _buildPetStatusChip('urgent', _isBangla ? 'জরুরি কেয়ার' : 'Urgent Medical'),
            ],
          ),
        ),

        Expanded(
          child: filtered.isEmpty
              ? _buildEmptyState(_isBangla ? 'কোনো পোষ্য পাওয়া যায়নি' : 'No pets found matching the criteria.')
              : GridView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 220,
                    mainAxisExtent: 260,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final pet = filtered[index];
                    return _buildPetInventoryCard(pet);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildPetStatusChip(String key, String label) {
    final isSelected = _petFilter == key;
    return ChoiceChip(
      label: Text(label, style: const TextStyle(fontSize: 12)),
      selected: isSelected,
      selectedColor: const Color(0xFF0D9488),
      labelStyle: TextStyle(color: isSelected ? Colors.white : const Color(0xFF475569), fontWeight: isSelected ? FontWeight.bold : FontWeight.normal),
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: isSelected ? const Color(0xFF0D9488) : const Color(0xFFE2E8F0))),
      onSelected: (val) {
        if (val) setState(() => _petFilter = key);
      },
    );
  }

  Widget _buildPetInventoryCard(Pet pet) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                child: SizedBox(
                  height: 120,
                  width: double.infinity,
                  child: AppNetworkImage(
                    imageUrl: pet.imageUrl,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              if (pet.isUrgent)
                Positioned(
                  top: 8,
                  left: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: const Color(0xFFE11D48), borderRadius: BorderRadius.circular(8)),
                    child: const Text('URGENT', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                  ),
                ),
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: pet.isAdopted ? const Color(0xFF10B981) : const Color(0xFF0D9488),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    pet.isAdopted ? 'ADOPTED' : 'ACTIVE',
                    style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  pet.name,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '${pet.species} • ${pet.breed}',
                  style: const TextStyle(color: Color(0xFF64748B), fontSize: 11),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: const Size(0, 28),
                          side: const BorderSide(color: Color(0xFFCBD5E1)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                        ),
                        onPressed: () {
                          showAdminCreatePetDialog(context, existingPet: pet);
                        },
                        child: const Text('Edit / তথ্য', style: TextStyle(fontSize: 10, color: Color(0xFF0F172A))),
                      ),
                    ),
                    const SizedBox(width: 6),
                    IconButton(
                      icon: Icon(pet.isAdopted ? Icons.undo_rounded : Icons.check_circle_outline, size: 18),
                      color: pet.isAdopted ? Colors.orange : const Color(0xFF10B981),
                      tooltip: pet.isAdopted ? 'Re-open for adoption' : 'Mark as Adopted',
                      onPressed: () {
                        final isNowAdopted = !pet.isAdopted;
                        final newStory = isNowAdopted
                            ? '[ADOPTED] ${pet.story}'
                            : pet.story.replaceAll('[ADOPTED] ', '').replaceAll('[ADOPTED]', '');
                        final updated = pet.copyWith(story: newStory);
                        _petRepo.updatePet(updated);
                        _adminRepo.recordAuditLog(
                          actorName: 'Admin',
                          action: 'TOGGLE_PET_ADOPTED',
                          target: pet.id,
                          details: 'Changed pet ${pet.name} status to ${isNowAdopted ? "Adopted" : "Active"}.',
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // TAB 2: VISITS & APPOINTMENTS
  // ==========================================
  Widget _buildVisitsAndAppointmentsTab() {
    var filtered = _appointments.where((apt) {
      if (_aptFilter != null && apt.status != _aptFilter) return false;
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        return apt.applicantName.toLowerCase().contains(q) ||
            apt.petName.toLowerCase().contains(q) ||
            apt.shelterName.toLowerCase().contains(q);
      }
      return true;
    }).toList();

    return Column(
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              _buildAptStatusChip(null, _isBangla ? 'সকল ভিজিট (${_appointments.length})' : 'All Visits (${_appointments.length})'),
              const SizedBox(width: 8),
              _buildAptStatusChip(AppointmentStatus.confirmed, _isBangla ? 'নিশ্চিত' : 'Confirmed'),
              const SizedBox(width: 8),
              _buildAptStatusChip(AppointmentStatus.pending, _isBangla ? 'বিবেচনাধীন' : 'Pending'),
              const SizedBox(width: 8),
              _buildAptStatusChip(AppointmentStatus.completed, _isBangla ? 'সম্পন্ন' : 'Completed'),
            ],
          ),
        ),
        Expanded(
          child: filtered.isEmpty
              ? _buildEmptyState(_isBangla ? 'কোনো ভিজিট শিডিউল নেই' : 'No visits scheduled in this view.')
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                  itemCount: filtered.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final apt = filtered[index];
                    return _buildAppointmentCard(apt);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildAptStatusChip(AppointmentStatus? status, String label) {
    final isSelected = _aptFilter == status;
    return ChoiceChip(
      label: Text(label, style: const TextStyle(fontSize: 12)),
      selected: isSelected,
      selectedColor: const Color(0xFF0284C7),
      labelStyle: TextStyle(color: isSelected ? Colors.white : const Color(0xFF475569), fontWeight: isSelected ? FontWeight.bold : FontWeight.normal),
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: isSelected ? const Color(0xFF0284C7) : const Color(0xFFE2E8F0))),
      onSelected: (val) => setState(() => _aptFilter = val ? status : null),
    );
  }

  Widget _buildAppointmentCard(AdoptionAppointment apt) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: const Color(0xFF0284C7).withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.calendar_month_rounded, color: Color(0xFF0284C7), size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${apt.applicantName} • ${apt.type.displayName}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                Text('Pet: ${apt.petName} • Coordinator: ${apt.shelterName}', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                const SizedBox(height: 4),
                Text('Date: ${apt.date.toLocal().toString().substring(0, 10)} • Slot: ${apt.timeSlot}', style: const TextStyle(fontSize: 11, color: Color(0xFF0284C7))),
              ],
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0284C7),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              minimumSize: const Size(60, 28),
            ),
            onPressed: () {
              _aptRepo.updateAppointmentStatus(apt.id, AppointmentStatus.completed);
              _adminRepo.recordAuditLog(
                actorName: 'Admin',
                action: 'COMPLETE_VISIT',
                target: apt.id,
                details: 'Completed visit for pet ${apt.petName} with applicant ${apt.applicantName}.',
              );
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Visit marked as completed!')));
            },
            child: const Text('Complete', style: TextStyle(fontSize: 11)),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // TAB 3: ANALYTICS & AUDIT TRAIL
  // ==========================================
  Widget _buildAnalyticsAndAuditTab() {
    final logs = _adminRepo.getAuditLogs();

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section 1: Pipeline Conversion Progress
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Adoption Conversion Health', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(height: 12),
                _buildProgressMetric('Vetting to Trial Foster Ratio', 0.82, '82%', const Color(0xFF0D9488)),
                const SizedBox(height: 10),
                _buildProgressMetric('Trial Foster to Permanent Adoption', 0.94, '94%', const Color(0xFF10B981)),
                const SizedBox(height: 10),
                _buildProgressMetric('Average Review Time', 0.65, '< 24 Hours', const Color(0xFF6366F1)),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Section 2: System Audit Trail Log
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('System Audit Trail Log', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              TextButton.icon(
                icon: const Icon(Icons.file_download_outlined, size: 16),
                label: const Text('Export Logs'),
                onPressed: () => _triggerExportFeedback('System_Audit_Trail_Export.csv'),
              ),
            ],
          ),
          const SizedBox(height: 8),

          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: logs.length > 8 ? 8 : logs.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final log = logs[index];
                return ListTile(
                  dense: true,
                  leading: CircleAvatar(
                    radius: 14,
                    backgroundColor: const Color(0xFF0D9488).withOpacity(0.12),
                    child: const Icon(Icons.security, size: 14, color: Color(0xFF0D9488)),
                  ),
                  title: Row(
                    children: [
                      Text(log.actorName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(4)),
                        child: Text(log.action, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFF475569))),
                      ),
                    ],
                  ),
                  subtitle: Text(
                    '${log.details} • ${log.timestamp.toLocal().toString().substring(0, 16)}',
                    style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressMetric(String label, double value, String display, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF475569))),
            Text(display, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: color)),
          ],
        ),
        const SizedBox(height: 6),
        LinearProgressIndicator(
          value: value,
          backgroundColor: const Color(0xFFF1F5F9),
          valueColor: AlwaysStoppedAnimation<Color>(color),
          minHeight: 6,
          borderRadius: BorderRadius.circular(4),
        ),
      ],
    );
  }

  // ==========================================
  // BATCH ACTION BAR (PINNED AT BOTTOM)
  // ==========================================
  Widget _buildBatchActionBar() {
    return Positioned(
      bottom: 20,
      left: 20,
      right: 20,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            Text(
              '${_selectedAppIds.length} Selected',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
            ),
            const Spacer(),
            TextButton(
              onPressed: () => setState(() => _selectedAppIds.clear()),
              child: const Text('Clear', style: TextStyle(color: Colors.white70, fontSize: 12)),
            ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE11D48),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              icon: const Icon(Icons.close_rounded, size: 14),
              label: const Text('Reject', style: TextStyle(fontSize: 12)),
              onPressed: _batchRejectApplications,
            ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0D9488),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              icon: const Icon(Icons.check_rounded, size: 14),
              label: const Text('Approve', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              onPressed: _batchApproveApplications,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.inbox_outlined, size: 48, color: Color(0xFFCBD5E1)),
            const SizedBox(height: 12),
            Text(message, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

/// Persistent Header Delegate for the TabBar
class _SliverTabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar _tabBar;

  _SliverTabBarDelegate(this._tabBar);

  @override
  double get minExtent => _tabBar.preferredSize.height;
  @override
  double get maxExtent => _tabBar.preferredSize.height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: Colors.white,
      child: _tabBar,
    );
  }

  @override
  bool shouldRebuild(_SliverTabBarDelegate oldDelegate) {
    return false;
  }
}
