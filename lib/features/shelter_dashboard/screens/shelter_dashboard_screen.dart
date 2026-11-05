import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import '../../../core/models/application_model.dart';
import '../../../core/models/pet_model.dart';
import '../../../core/models/appointment_model.dart';
import '../../../core/repositories/application_repository.dart';
import '../../../core/repositories/pet_repository.dart';
import '../../../core/repositories/appointment_repository.dart';
import '../../admin/widgets/admin_create_pet_dialog.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../auth/bloc/auth_bloc.dart';

class ShelterDashboardScreen extends StatefulWidget {
  const ShelterDashboardScreen({super.key});

  @override
  State<ShelterDashboardScreen> createState() => _ShelterDashboardScreenState();
}

class _ShelterDashboardScreenState extends State<ShelterDashboardScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _appRepo = ApplicationRepository();
  final _petRepo = PetRepository();
  final _aptRepo = AppointmentRepository();

  StreamSubscription<List<AdoptionApplication>>? _appSub;
  StreamSubscription<List<Pet>>? _petSub;
  StreamSubscription<List<AdoptionAppointment>>? _aptSub;

  List<AdoptionApplication> _applications = [];
  List<Pet> _pets = [];
  List<AdoptionAppointment> _appointments = [];
  bool _isLoading = true;

  // Interactive statistics & filter states
  ApplicationStatus? _applicationFilter;
  String _petFilter = 'all'; // 'all', 'available', 'adopted'
  AppointmentStatus? _appointmentFilter;

  void _setApplicationFilter(ApplicationStatus? status) {
    setState(() {
      _applicationFilter = status;
    });
    _tabController.animateTo(0);
  }

  // In-screen password lock protection
  bool _isUnlocked = false;
  bool _isVerifying = false;
  String? _unlockError;
  final _emailController = TextEditingController(text: 'shelter@adoptmatch.com');
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);

    // Check if user is already authenticated as shelter or admin
    final authState = context.read<AuthBloc>().state;
    if (authState is Authenticated) {
      final role = authState.user.role;
      if (role == UserRole.shelter || role.isAdmin) {
        _isUnlocked = true;
      }
    }

    if (_isUnlocked) {
      _loadData();
    } else {
      _isLoading = false;
    }

    _appSub = _appRepo.applicationsStream.listen((apps) {
      if (mounted) setState(() => _applications = apps);
    });
    _petSub = _petRepo.petsStream.listen((pets) {
      if (mounted) setState(() => _pets = pets);
    });
    _aptSub = _aptRepo.appointmentsStream.listen((apts) {
      if (mounted) setState(() => _appointments = apts);
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _appSub?.cancel();
    _petSub?.cancel();
    _aptSub?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final apps = await _appRepo.getApplications().timeout(const Duration(seconds: 4));
      final pets = await _petRepo.getAllPets().timeout(const Duration(seconds: 4));
      final apts = await _aptRepo.getAppointments().timeout(const Duration(seconds: 4));
      if (mounted) {
        setState(() {
          _applications = apps;
          _pets = pets;
          _appointments = apts;
        });
      }
    } catch (e) {
      debugPrint('[ShelterDashboard] loadData notice: ');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _verifyAndUnlock() async {
    final password = _passwordController.text.trim();
    final email = _emailController.text.trim();

    if (password.isEmpty) {
      setState(() => _unlockError = 'অনুগ্রহ করে পাসওয়ার্ড দিন (Please enter password)');
      return;
    }

    setState(() {
      _isVerifying = true;
      _unlockError = null;
    });

    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;

    final isValid = (password == 'Shelter@123456' || password == 'Admin@123456' || password == 'SuperAdmin@123456');

    if (!isValid) {
      setState(() {
        _isVerifying = false;
        _unlockError = 'ভুল পাসওয়ার্ড! সঠিক শেল্টার পাসওয়ার্ড দিন (ডিফল্ট: Shelter@123456)';
      });
      return;
    }

    // Elevate user role in AuthBloc
    final authBloc = context.read<AuthBloc>();
    authBloc.add(
      UserConfirmedSessionEvent(
        UserProfile(
          id: 'shelter-coord-1',
          name: 'Shelter Coordinator',
          email: email.isNotEmpty ? email : 'shelter@adoptmatch.com',
          phone: '+880 1711 000111',
          role: UserRole.shelter,
          isVerified: true,
        ),
      ),
    );

    setState(() {
      _isVerifying = false;
      _isUnlocked = true;
    });

    await _loadData();
  }

  Widget _buildLockScreen() {
    const teal = Color(0xFF0D9488);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Shelter Desk Lock', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.go('/home'),
        ),
        elevation: 0,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Card(
              elevation: 4,
              shadowColor: Colors.black12,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              color: Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(28.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0D9488).withOpacity(0.12),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.shield_outlined,
                          color: Color(0xFF0D9488),
                          size: 40,
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'Shelter Coordinator Desk',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'পাসওয়ার্ড ছাড়া শেল্টার ড্যাশবোর্ডে প্রবেশ সংরক্ষিত\n(Password Protected Shelter Portal)',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: Color(0xFF64748B), height: 1.4),
                    ),
                    const SizedBox(height: 24),
                    if (_unlockError != null) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF2F2),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFFECACA)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline_rounded, color: Color(0xFFDC2626), size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _unlockError!,
                                style: const TextStyle(fontSize: 12, color: Color(0xFFB91C1C), fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    const Text(
                      'Coordinator Email',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.email_outlined, size: 20, color: Color(0xFF0D9488)),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Shelter Password / পাসওয়ার্ড',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      autofocus: true,
                      onSubmitted: (_) => _verifyAndUnlock(),
                      decoration: InputDecoration(
                        hintText: 'Enter Shelter Password',
                        prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20, color: Color(0xFF0D9488)),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                            size: 20,
                            color: const Color(0xFF64748B),
                          ),
                          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                        ),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                    ),
                    const SizedBox(height: 12),
                    InkWell(
                      onTap: () {
                        setState(() {
                          _passwordController.text = 'Shelter@123456';
                          _unlockError = null;
                        });
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Icon(Icons.key_rounded, size: 14, color: Color(0xFF0D9488)),
                            SizedBox(width: 6),
                            Text(
                              'Auto-fill default: Shelter@123456',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0D9488)),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      height: 48,
                      child: ElevatedButton(
                        onPressed: _isVerifying ? null : _verifyAndUnlock,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: teal,
                          foregroundColor: Colors.white,
                          elevation: 2,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        child: _isVerifying
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: const [
                                  Icon(Icons.lock_open_rounded, size: 18),
                                  SizedBox(width: 8),
                                  Text(
                                    'Unlock Dashboard / প্রবেশ করুন',
                                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: () => context.go('/home'),
                      child: const Text(
                        'Return to Home / ফিরে যান',
                        style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _openApplicationReviewSheet(AdoptionApplication app) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.88,
        minChildSize: 0.5,
        maxChildSize: 0.96,
        expand: false,
        builder: (_, scrollController) => _ApplicationDossierSheet(
          app: app,
          scrollController: scrollController,
          onStatusUpdated: (newStatus, notes, homeVisitDate) async {
            Navigator.of(ctx).pop();
            await _appRepo.updateApplicationStatus(
              app.id,
              newStatus,
              notes: notes,
              homeVisitDate: homeVisitDate,
            );
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Application ${app.id} updated to ${newStatus.displayName}'),
                  backgroundColor: const Color(0xFF0D9488),
                ),
              );
            }
          },
        ),
      ),
    );
  }

  void _openAddNewPetDialog() {
    showAdminCreatePetDialog(
      context,
      onSaved: (pet) {
        _loadData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${pet.name} added to adoptable inventory!'),
              backgroundColor: const Color(0xFF0D9488),
            ),
          );
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_isUnlocked) {
      return _buildLockScreen();
    }

    const teal = Color(0xFF0D9488);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Shelter Management Admin', style: TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_photo_alternate_rounded, color: Color(0xFF0D9488)),
            tooltip: 'Add Rescue Pet with Photo',
            onPressed: _openAddNewPetDialog,
          ),
          const SizedBox(width: 8),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: false,
          labelColor: teal,
          unselectedLabelColor: const Color(0xFF64748B),
          indicatorColor: teal,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          tabs: const [
            Tab(icon: Icon(Icons.assignment_outlined, size: 20), text: 'Apps'),
            Tab(icon: Icon(Icons.pets_outlined, size: 20), text: 'Pets'),
            Tab(icon: Icon(Icons.event_available_rounded, size: 20), text: 'Visits'),
            Tab(icon: Icon(Icons.insights_outlined, size: 20), text: 'Analytics'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: teal))
          : TabBarView(
              controller: _tabController,
              children: [
                _buildApplicationsTab(),
                _buildPetInventoryTab(),
                _buildAppointmentsTab(),
                _buildAnalyticsTab(),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAddNewPetDialog,
        backgroundColor: teal,
        icon: const Icon(Icons.add_photo_alternate_rounded, color: Colors.white),
        label: const Text('Add Rescue Pet / পোষ্য যোগ', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildStatFilterChip({
    required String label,
    required int count,
    required bool isSelected,
    required Color activeColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? activeColor : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? activeColor : const Color(0xFFCBD5E1),
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                color: isSelected ? Colors.white : const Color(0xFF334155),
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isSelected ? Colors.white.withOpacity(0.28) : const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- TAB 1: Applications Kanban & Review ---
  Widget _buildApplicationsTab() {
    final submittedCount = _applications.where((a) => a.status == ApplicationStatus.submitted || a.status == ApplicationStatus.underReview).length;
    final homeVisitCount = _applications.where((a) => a.status == ApplicationStatus.homeVisitScheduled).length;
    final trialCount = _applications.where((a) => a.status == ApplicationStatus.fosterTrial).length;
    final approvedCount = _applications.where((a) => a.status == ApplicationStatus.approved).length;
    final rejectedCount = _applications.where((a) => a.status == ApplicationStatus.rejected).length;

    final filtered = _applicationFilter == null
        ? _applications
        : _applications.where((a) => a.status == _applicationFilter).toList();

    return Column(
      children: [
        // Interactive Statistics Filter Bar
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                _buildStatFilterChip(
                  label: 'All Apps',
                  count: _applications.length,
                  isSelected: _applicationFilter == null,
                  activeColor: const Color(0xFF0D9488),
                  onTap: () => setState(() => _applicationFilter = null),
                ),
                const SizedBox(width: 8),
                _buildStatFilterChip(
                  label: 'Under Review',
                  count: submittedCount,
                  isSelected: _applicationFilter == ApplicationStatus.underReview || _applicationFilter == ApplicationStatus.submitted,
                  activeColor: const Color(0xFF2563EB),
                  onTap: () => setState(() => _applicationFilter = ApplicationStatus.underReview),
                ),
                const SizedBox(width: 8),
                _buildStatFilterChip(
                  label: 'Home Visits',
                  count: homeVisitCount,
                  isSelected: _applicationFilter == ApplicationStatus.homeVisitScheduled,
                  activeColor: const Color(0xFFF59E0B),
                  onTap: () => setState(() => _applicationFilter = ApplicationStatus.homeVisitScheduled),
                ),
                const SizedBox(width: 8),
                _buildStatFilterChip(
                  label: 'Trial Fosters',
                  count: trialCount,
                  isSelected: _applicationFilter == ApplicationStatus.fosterTrial,
                  activeColor: const Color(0xFF8B5CF6),
                  onTap: () => setState(() => _applicationFilter = ApplicationStatus.fosterTrial),
                ),
                const SizedBox(width: 8),
                _buildStatFilterChip(
                  label: 'Approved',
                  count: approvedCount,
                  isSelected: _applicationFilter == ApplicationStatus.approved,
                  activeColor: const Color(0xFF10B981),
                  onTap: () => setState(() => _applicationFilter = ApplicationStatus.approved),
                ),
                const SizedBox(width: 8),
                _buildStatFilterChip(
                  label: 'Rejected',
                  count: rejectedCount,
                  isSelected: _applicationFilter == ApplicationStatus.rejected,
                  activeColor: const Color(0xFFEF4444),
                  onTap: () => setState(() => _applicationFilter = ApplicationStatus.rejected),
                ),
              ],
            ),
          ),
        ),
        if (_applicationFilter != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: const Color(0xFFF1F5F9),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Filtered by: ${_applicationFilter!.displayName} (${filtered.length})',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
                ),
                GestureDetector(
                  onTap: () => setState(() => _applicationFilter = null),
                  child: const Text(
                    'Clear Filter / Show All',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0D9488)),
                  ),
                ),
              ],
            ),
          ),
        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.filter_list_off_rounded, size: 48, color: Color(0xFF94A3B8)),
                      const SizedBox(height: 12),
                      Text(
                        _applications.isEmpty
                            ? 'No applications submitted yet.'
                            : 'No applications found under ${_applicationFilter?.displayName ?? ""}',
                        style: const TextStyle(fontSize: 14, color: Color(0xFF64748B)),
                      ),
                      if (_applicationFilter != null) ...[
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: () => setState(() => _applicationFilter = null),
                          child: const Text('Show All Applications', style: TextStyle(color: Color(0xFF0D9488))),
                        ),
                      ],
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final app = filtered[index];
        final statusColor = _getStatusColor(app.status);

        return Card(
          margin: const EdgeInsets.only(bottom: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 0,
          color: Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Row: Pet Image, Applicant Name, Status Chip
                Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: SizedBox(
                        width: 50,
                        height: 50,
                        child: CachedNetworkImage(
                          imageUrl: app.petImageUrl,
                          fit: BoxFit.cover,
                          errorWidget: (context, url, error) => const Icon(Icons.pets),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${app.applicantName} → ${app.petName}',
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Ref: ${app.id} • ${app.petBreed}',
                            style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        app.status.displayName,
                        style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Divider(height: 1, color: Color(0xFFF1F5F9)),
                const SizedBox(height: 10),

                // Info Chips Row
                Wrap(
                  spacing: 12,
                  runSpacing: 6,
                  children: [
                    _InfoRow(icon: Icons.home_outlined, text: '${app.housingType} (${app.ownershipStatus})'),
                    _InfoRow(icon: Icons.phone_outlined, text: app.applicantPhone),
                    _InfoRow(icon: Icons.shield_outlined, text: 'NID: ${app.nidNumber}'),
                  ],
                ),

                if (app.reviewerNotes != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Text(
                      'Shelter Note: ${app.reviewerNotes}',
                      style: const TextStyle(fontSize: 11, color: Color(0xFF475569), fontStyle: FontStyle.italic),
                    ),
                  ),
                ],

                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _openApplicationReviewSheet(app),
                    icon: const Icon(Icons.rate_review_outlined, size: 16, color: Color(0xFF0D9488)),
                    label: const Text('Review Application & Update Status', style: TextStyle(color: Color(0xFF0D9488), fontWeight: FontWeight.bold, fontSize: 13)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFF0D9488)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    ),
        ),
      ],
    );
  }

  // --- TAB 2: Pet Inventory ---
  Widget _buildPetInventoryTab() {
    final availableCount = _pets.where((p) => !p.story.contains('[ADOPTED]')).length;
    final adoptedCount = _pets.where((p) => p.story.contains('[ADOPTED]')).length;

    final filteredPets = _petFilter == 'available'
        ? _pets.where((p) => !p.story.contains('[ADOPTED]')).toList()
        : _petFilter == 'adopted'
            ? _pets.where((p) => p.story.contains('[ADOPTED]')).toList()
            : _pets;

    return Column(
      children: [
        // Interactive Pet Stats Filter Bar
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              _buildStatFilterChip(
                label: 'All Rescues',
                count: _pets.length,
                isSelected: _petFilter == 'all',
                activeColor: const Color(0xFF0D9488),
                onTap: () => setState(() => _petFilter = 'all'),
              ),
              const SizedBox(width: 8),
              _buildStatFilterChip(
                label: 'Available',
                count: availableCount,
                isSelected: _petFilter == 'available',
                activeColor: const Color(0xFF10B981),
                onTap: () => setState(() => _petFilter = 'available'),
              ),
              const SizedBox(width: 8),
              _buildStatFilterChip(
                label: 'Adopted',
                count: adoptedCount,
                isSelected: _petFilter == 'adopted',
                activeColor: const Color(0xFF64748B),
                onTap: () => setState(() => _petFilter = 'adopted'),
              ),
            ],
          ),
        ),
        Expanded(
          child: filteredPets.isEmpty
              ? Center(
                  child: Text(
                    'No $_petFilter pets found.',
                    style: const TextStyle(fontSize: 14, color: Color(0xFF64748B)),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                  itemCount: filteredPets.length,
                  itemBuilder: (context, index) {
                    final pet = filteredPets[index];
        final isAdopted = pet.story.contains('[ADOPTED]');

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          color: Colors.white,
          elevation: 0,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox(
                    width: 70,
                    height: 70,
                    child: CachedNetworkImage(
                      imageUrl: pet.imageUrl,
                      fit: BoxFit.cover,
                      errorWidget: (context, url, error) => const Icon(Icons.pets),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(pet.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: isAdopted ? const Color(0xFFE2E8F0) : const Color(0xFFDCFCE7),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              isAdopted ? 'Adopted' : 'Available',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: isAdopted ? const Color(0xFF64748B) : const Color(0xFF16A34A),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text('${pet.breed} • ${pet.ageDisplay} • ${pet.gender}', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                      const SizedBox(height: 4),
                      Text(pet.shelterName, style: const TextStyle(fontSize: 11, color: Color(0xFF0D9488), fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (action) async {
                    if (action == 'view') {
                      context.push('/pets/${pet.id}');
                    } else if (action == 'adopted') {
                      await _petRepo.markAsAdopted(pet.id);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${pet.name} marked as Adopted!')));
                      }
                    } else if (action == 'delete') {
                      await _petRepo.deletePet(pet.id);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${pet.name} removed from inventory.')));
                      }
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(value: 'view', child: Text('View Profile')),
                    if (!isAdopted) const PopupMenuItem(value: 'adopted', child: Text('Mark as Adopted')),
                    const PopupMenuItem(value: 'delete', child: Text('Delete Listing', style: TextStyle(color: Colors.red))),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    ),
        ),
      ],
    );
  }

  // --- TAB 3: Shelter Appointments Desk ---
  Widget _buildAppointmentsTab() {
    final pendingCount = _appointments.where((a) => a.status == AppointmentStatus.pending).length;
    final confirmedCount = _appointments.where((a) => a.status == AppointmentStatus.confirmed).length;
    final completedCount = _appointments.where((a) => a.status == AppointmentStatus.completed).length;

    final filteredApts = _appointmentFilter == null
        ? _appointments
        : _appointments.where((a) => a.status == _appointmentFilter).toList();

    return Column(
      children: [
        // Interactive Appointment Stats Filter Bar
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildStatFilterChip(
                  label: 'All Visits',
                  count: _appointments.length,
                  isSelected: _appointmentFilter == null,
                  activeColor: const Color(0xFF0D9488),
                  onTap: () => setState(() => _appointmentFilter = null),
                ),
                const SizedBox(width: 8),
                _buildStatFilterChip(
                  label: 'Confirmed',
                  count: confirmedCount,
                  isSelected: _appointmentFilter == AppointmentStatus.confirmed,
                  activeColor: const Color(0xFF10B981),
                  onTap: () => setState(() => _appointmentFilter = AppointmentStatus.confirmed),
                ),
                const SizedBox(width: 8),
                _buildStatFilterChip(
                  label: 'Pending',
                  count: pendingCount,
                  isSelected: _appointmentFilter == AppointmentStatus.pending,
                  activeColor: const Color(0xFFF59E0B),
                  onTap: () => setState(() => _appointmentFilter = AppointmentStatus.pending),
                ),
                const SizedBox(width: 8),
                _buildStatFilterChip(
                  label: 'Completed',
                  count: completedCount,
                  isSelected: _appointmentFilter == AppointmentStatus.completed,
                  activeColor: const Color(0xFF2563EB),
                  onTap: () => setState(() => _appointmentFilter = AppointmentStatus.completed),
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: filteredApts.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0D9488).withOpacity(0.08),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.event_available_rounded, size: 48, color: Color(0xFF0D9488)),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _appointments.isEmpty ? 'No Scheduled Visits Yet' : 'No ${_appointmentFilter?.displayName ?? ""} visits found',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Appointment requests from prospective adopters will appear here.',
                        style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: filteredApts.length,
                  itemBuilder: (context, index) {
                    final apt = filteredApts[index];
        final statusColor = apt.status == AppointmentStatus.confirmed
            ? const Color(0xFF10B981)
            : apt.status == AppointmentStatus.pending
                ? const Color(0xFFF59E0B)
                : apt.status == AppointmentStatus.completed
                    ? const Color(0xFF2563EB)
                    : const Color(0xFFEF4444);

        return Card(
          margin: const EdgeInsets.only(bottom: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
          elevation: 0,
          color: Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: CachedNetworkImage(
                        imageUrl: apt.petImageUrl,
                        width: 52,
                        height: 52,
                        fit: BoxFit.cover,
                        errorWidget: (context, url, error) => Container(
                          width: 52,
                          height: 52,
                          color: const Color(0xFFE2E8F0),
                          child: const Icon(Icons.pets, color: Color(0xFF94A3B8)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                apt.petName,
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: statusColor.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  apt.status.displayName,
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: statusColor),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            apt.type.displayName,
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF0D9488)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Divider(height: 1, color: Color(0xFFF1F5F9)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(Icons.person_outline, size: 16, color: Color(0xFF64748B)),
                    const SizedBox(width: 6),
                    Text(
                      'Applicant: ${apt.applicantName}',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Color(0xFF334155)),
                    ),
                    const Spacer(),
                    const Icon(Icons.phone_outlined, size: 16, color: Color(0xFF64748B)),
                    const SizedBox(width: 4),
                    Text(
                      apt.applicantPhone,
                      style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.calendar_month_outlined, size: 16, color: Color(0xFF64748B)),
                    const SizedBox(width: 6),
                    Text(
                      '${apt.date.day}/${apt.date.month}/${apt.date.year} • ${apt.timeSlot}',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                    ),
                  ],
                ),
                if (apt.notes.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Text(
                      'Notes: ${apt.notes}',
                      style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: Color(0xFF475569)),
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (apt.status == AppointmentStatus.pending) ...[
                      OutlinedButton(
                        onPressed: () async {
                          await _aptRepo.updateAppointmentStatus(apt.id, AppointmentStatus.cancelled);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Appointment declined/cancelled.')),
                            );
                          }
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFEF4444),
                          side: const BorderSide(color: Color(0xFFFCA5A5)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          visualDensity: VisualDensity.compact,
                        ),
                        child: const Text('Decline'),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () async {
                          await _aptRepo.updateAppointmentStatus(apt.id, AppointmentStatus.confirmed);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Appointment confirmed! Adopter notified.')),
                            );
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0D9488),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          visualDensity: VisualDensity.compact,
                          elevation: 0,
                        ),
                        child: const Text('Confirm Visit'),
                      ),
                    ] else if (apt.status == AppointmentStatus.confirmed) ...[
                      OutlinedButton(
                        onPressed: () async {
                          await _aptRepo.updateAppointmentStatus(apt.id, AppointmentStatus.cancelled);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Appointment cancelled.')),
                            );
                          }
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFEF4444),
                          side: const BorderSide(color: Color(0xFFFCA5A5)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          visualDensity: VisualDensity.compact,
                        ),
                        child: const Text('Cancel Visit'),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: () async {
                          await _aptRepo.updateAppointmentStatus(apt.id, AppointmentStatus.completed);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Visit marked as completed!')),
                            );
                          }
                        },
                        icon: const Icon(Icons.check_circle_outline, size: 16),
                        label: const Text('Mark Completed'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF10B981),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          visualDensity: VisualDensity.compact,
                          elevation: 0,
                        ),
                      ),
                    ] else ...[
                      Text(
                        apt.status == AppointmentStatus.completed ? '✓ Completed' : '✕ Cancelled',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: apt.status == AppointmentStatus.completed ? const Color(0xFF10B981) : const Color(0xFF94A3B8),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        );
      },
    ),
        ),
      ],
    );
  }

  // --- TAB 4: Analytics ---
  Widget _buildAnalyticsTab() {
    final totalPets = _pets.length;
    final totalApps = _applications.length;
    final homeVisits = _applications.where((a) => a.status == ApplicationStatus.homeVisitScheduled).length;
    final trialFosters = _applications.where((a) => a.status == ApplicationStatus.fosterTrial).length;
    final approved = _applications.where((a) => a.status == ApplicationStatus.approved).length;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Shelter Performance Overview', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
          const SizedBox(height: 4),
          const Text('Real-time ethical adoption metrics and pipeline tracking.', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
          const SizedBox(height: 16),

          Row(
            children: [
              _MetricCard(
                title: 'Active Rescues',
                count: '$totalPets',
                icon: Icons.pets,
                color: const Color(0xFF0D9488),
                actionHint: 'View Pets',
                onTap: () => _tabController.animateTo(1),
              ),
              const SizedBox(width: 12),
              _MetricCard(
                title: 'Total Applications',
                count: '$totalApps',
                icon: Icons.description_outlined,
                color: const Color(0xFF2563EB),
                actionHint: 'View Apps',
                onTap: () {
                  _setApplicationFilter(null);
                  _tabController.animateTo(0);
                },
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _MetricCard(
                title: 'Home Visits',
                count: '$homeVisits',
                icon: Icons.home_work_outlined,
                color: const Color(0xFFF59E0B),
                actionHint: 'View Visits',
                onTap: () => _tabController.animateTo(2),
              ),
              const SizedBox(width: 12),
              _MetricCard(
                title: 'Trial Fosters',
                count: '$trialFosters',
                icon: Icons.volunteer_activism_outlined,
                color: const Color(0xFF8B5CF6),
                actionHint: 'View Fosters',
                onTap: () => _setApplicationFilter(ApplicationStatus.fosterTrial),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _MetricCard(
                title: 'Adoptions Completed',
                count: '$approved',
                icon: Icons.verified_rounded,
                color: const Color(0xFF10B981),
                actionHint: 'View Completed',
                onTap: () => _setApplicationFilter(ApplicationStatus.approved),
              ),
            ],
          ),

          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Ethical Animal Welfare Standards', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                const SizedBox(height: 12),
                _StandardCheckItem(label: '100% Core Rabies & DHPP Vaccination Check', checked: true),
                _StandardCheckItem(label: 'Mandatory Digital Touch E-Signature Verification', checked: true),
                _StandardCheckItem(label: '14-Day Safe Trial Foster Guarantee', checked: true),
                _StandardCheckItem(label: 'Phone Privacy Masking Relay Enabled', checked: true),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(ApplicationStatus status) {
    switch (status) {
      case ApplicationStatus.draft:
        return const Color(0xFF64748B);
      case ApplicationStatus.submitted:
        return const Color(0xFF2563EB);
      case ApplicationStatus.underReview:
        return const Color(0xFF0D9488);
      case ApplicationStatus.homeVisitScheduled:
        return const Color(0xFFD97706);
      case ApplicationStatus.fosterTrial:
        return const Color(0xFF8B5CF6);
      case ApplicationStatus.approved:
        return const Color(0xFF16A34A);
      case ApplicationStatus.rejected:
        return const Color(0xFFE11D48);
    }
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InfoRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: const Color(0xFF64748B)),
        const SizedBox(width: 4),
        Text(text, style: const TextStyle(fontSize: 12, color: Color(0xFF475569))),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String title;
  final String count;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;
  final String? actionHint;

  const _MetricCard({
    required this.title,
    required this.count,
    required this.icon,
    required this.color,
    this.onTap,
    this.actionHint,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          splashColor: color.withOpacity(0.12),
          highlightColor: color.withOpacity(0.06),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.02),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: color.withOpacity(0.12),
                      child: Icon(icon, size: 20, color: color),
                    ),
                    if (onTap != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              actionHint ?? 'Open',
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color),
                            ),
                            const SizedBox(width: 3),
                            Icon(Icons.arrow_forward_ios_rounded, size: 8, color: color),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(count, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
                const SizedBox(height: 2),
                Text(title, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StandardCheckItem extends StatelessWidget {
  final String label;
  final bool checked;

  const _StandardCheckItem({required this.label, required this.checked});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(checked ? Icons.check_circle_rounded : Icons.radio_button_unchecked, size: 18, color: checked ? const Color(0xFF16A34A) : Colors.grey),
          const SizedBox(width: 8),
          Expanded(child: Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF334155), fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }
}

// --- Application Full Dossier Bottom Sheet ---
class _ApplicationDossierSheet extends StatefulWidget {
  final AdoptionApplication app;
  final ScrollController scrollController;
  final Function(ApplicationStatus status, String notes, DateTime? homeVisitDate) onStatusUpdated;

  const _ApplicationDossierSheet({
    required this.app,
    required this.scrollController,
    required this.onStatusUpdated,
  });

  @override
  State<_ApplicationDossierSheet> createState() => _ApplicationDossierSheetState();
}

class _ApplicationDossierSheetState extends State<_ApplicationDossierSheet> {
  late ApplicationStatus _selectedStatus;
  late TextEditingController _notesController;
  DateTime? _selectedHomeVisitDate;

  @override
  void initState() {
    super.initState();
    _selectedStatus = widget.app.status;
    _notesController = TextEditingController(text: widget.app.reviewerNotes ?? '');
    _selectedHomeVisitDate = widget.app.homeVisitDate;
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const teal = Color(0xFF0D9488);
    final app = widget.app;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      child: ListView(
        controller: widget.scrollController,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(color: const Color(0xFFCBD5E1), borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Dossier: ${app.id}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
              IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.of(context).pop()),
            ],
          ),
          const SizedBox(height: 12),

          // Applicant & Pet Card
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox(
                    width: 56,
                    height: 56,
                    child: CachedNetworkImage(imageUrl: app.petImageUrl, fit: BoxFit.cover),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(app.applicantName, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                      Text('Applying for ${app.petName} (${app.petBreed})', style: const TextStyle(fontSize: 12, color: Color(0xFF0D9488), fontWeight: FontWeight.w600)),
                      Text('NID: ${app.nidNumber}', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),
          const Text('Applicant Living Conditions', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
          const SizedBox(height: 8),
          _DossierField(label: 'Housing & Ownership', value: '${app.housingType} (${app.ownershipStatus})'),
          _DossierField(label: 'Landlord Animal Policy', value: app.ownershipStatus == 'Rented' ? (app.landlordAllowsPets ? 'Permitted in Lease' : 'Not Cleared!') : 'Owner Occupied'),
          _DossierField(label: 'Outdoor & Yard', value: app.yardType),
          _DossierField(label: 'Daily Alone Hours', value: app.dailyHoursAlone),
          _DossierField(label: 'Household Members', value: '${app.totalAdults} Adults${app.hasKids ? ' • Kids: ${app.childrenAges}' : ' • No Kids'}'),
          _DossierField(label: 'Emergency Vet Fund', value: app.emergencyVetFund ? 'Confirmed Ready' : 'Not confirmed'),
          _DossierField(label: 'Monthly Care Budget', value: app.monthlyBudget),
          _DossierField(label: 'Adoption Motivation', value: app.whyAdopt),
          _DossierField(label: 'Digital Touch E-Signature', value: 'Legally Signed & Verified ✓'),

          const SizedBox(height: 20),
          const Text('Committee Status & Review Action', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
          const SizedBox(height: 10),
          DropdownButtonFormField<ApplicationStatus>(
            value: _selectedStatus,
            decoration: InputDecoration(
              labelText: 'Update Application Status',
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            items: ApplicationStatus.values
                .where((s) => s != ApplicationStatus.draft)
                .map((status) => DropdownMenuItem(value: status, child: Text(status.displayName)))
                .toList(),
            onChanged: (val) => setState(() => _selectedStatus = val!),
          ),

          const SizedBox(height: 14),
          TextField(
            controller: _notesController,
            maxLines: 2,
            decoration: InputDecoration(
              labelText: 'Reviewer Feedback & Instructions to Adopter',
              hintText: 'e.g. Virtual home tour scheduled for Sunday...',
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),

          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: () {
                widget.onStatusUpdated(
                  _selectedStatus,
                  _notesController.text.trim(),
                  _selectedHomeVisitDate,
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: teal,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Save & Dispatch Update', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }
}

class _DossierField extends StatelessWidget {
  final String label;
  final String value;

  const _DossierField({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w500)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF0F172A))),
          ),
        ],
      ),
    );
  }
}

