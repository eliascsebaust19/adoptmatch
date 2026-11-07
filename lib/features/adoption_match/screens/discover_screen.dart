import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../bloc/pet_match_bloc.dart';
import '../widgets/pet_card_grid_item.dart';
import '../widgets/filter_modal_sheet.dart';
import '../widgets/adoption_banner.dart';
import '../widgets/quick_stats_bar.dart';
import '../../../core/repositories/notification_repository.dart';
import '../../../core/localization/app_locale.dart';
import '../../../core/widgets/language_selector_sheet.dart';
import '../../auth/bloc/auth_bloc.dart';
import '../../../core/services/notification_service.dart';
import '../../../shared/widgets/app_network_image.dart';

class DiscoverScreen extends StatefulWidget {
  const DiscoverScreen({super.key});

  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen> {
  final _searchController = TextEditingController();
  String _selectedCategory = 'All Pets';
  double _filterDistance = 50.0;
  bool _filterKidSafe = false;
  bool _filterApartment = false;
  bool _filterVaccinated = false;
  int _unreadNotifs = 0;
  bool _hasShownWelcome = false;
  final Set<String> _precachedPetIds = <String>{};

  void _precachePetImages(List<dynamic> pets) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      for (int i = 0; i < pets.length && i < 10; i++) {
        final p = pets[i];
        if (p.imageUrl != null && p.imageUrl.isNotEmpty && !_precachedPetIds.contains(p.id)) {
          _precachedPetIds.add(p.id);
          precacheImage(AppNetworkImage.provider(p.imageUrl), context);
        }
      }
    });
  }

  final List<String> _categories = [
    'All Pets',
    'Dogs 🐶',
    'Cats 🐱',
    'Birds 🦜',
    'Fish & Goldfish 🐠',
    'Turtles / কচ্ছপ 🐢',
    'Geckos & Dragons 🦎',
    'Rabbits 🐰',
    'Seniors 🐾',
  ];

  @override
  void initState() {
    super.initState();
    // Initial fetch
    context.read<PetMatchBloc>().add(const LoadPetsEvent());
    _loadUnreadNotifs();
    NotificationRepository().notificationsStream.listen((_) {
      _loadUnreadNotifs();
    });

    final authState = context.read<AuthBloc>().state;
    _checkAndShowWelcome(context, authState);
  }

  void _checkAndShowWelcome(BuildContext context, AuthState state) {
    if (_hasShownWelcome) return;
    if (state is Authenticated && state.isNewUser) {
      _hasShownWelcome = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final userName = state.user.name.trim().isNotEmpty
            ? state.user.name.trim()
            : 'Pet Lover';
        _showWelcomeToastAndNotification(userName);
      });
    }
  }

  void _showWelcomeToastAndNotification(String userName) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF0D9488),
        elevation: 6,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        duration: const Duration(seconds: 5),
        content: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.pets, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Welcome to AdoptMatch, $userName! 🎉',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Account created successfully. Start swiping to find pets!',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    NotificationService.showNotification(
      title: 'Welcome to AdoptMatch! 🐾',
      body:
          'Your account has been created successfully. Discover adoptable pets near you today!',
    );
  }

  Future<void> _loadUnreadNotifs() async {
    final count = await NotificationRepository().getUnreadCount();
    if (mounted) setState(() => _unreadNotifs = count);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onCategorySelected(String category) {
    setState(() => _selectedCategory = category);
    _applyFilters();
  }

  void _applyFilters() {
    context.read<PetMatchBloc>().add(
      LoadPetsEvent(
        category: _selectedCategory,
        searchQuery: _searchController.text.trim(),
        maxDistanceKm: _filterDistance,
        kidSafeOnly: _filterKidSafe,
        apartmentOnly: _filterApartment,
        vaccinatedOnly: _filterVaccinated,
      ),
    );
  }

  void _openFilterSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => FilterModalSheet(
        currentDistance: _filterDistance,
        kidSafe: _filterKidSafe,
        apartmentFriendly: _filterApartment,
        vaccinated: _filterVaccinated,
        onApply: (distance, kidSafe, apartment, vaccinated) {
          setState(() {
            _filterDistance = distance;
            _filterKidSafe = kidSafe;
            _filterApartment = apartment;
            _filterVaccinated = vaccinated;
          });
          _applyFilters();
        },
      ),
    );
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      return 'Good Morning';
    } else if (hour < 17) {
      return 'Good Afternoon';
    } else {
      return 'Good Evening';
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.select<AuthBloc, UserProfile?>((bloc) {
      if (bloc.state is Authenticated) {
        return (bloc.state as Authenticated).user;
      }
      return null;
    });

    final rawName = user?.name.trim();
    final displayName = (rawName != null && rawName.isNotEmpty)
        ? rawName.split(' ').first
        : 'Friend';
    final greetingText = '${_getGreeting()}, $displayName 👋';

    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        _checkAndShowWelcome(context, state);
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
      drawer: _buildAppDrawer(context),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF8FAFC),
        elevation: 0,
        titleSpacing: 12,
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu_rounded, color: Color(0xFF0F172A), size: 28),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        title: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            greetingText,
            style: const TextStyle(
              color: Color(0xFF0F172A),
              fontSize: 17,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.2,
            ),
            maxLines: 1,
          ),
        ),
        actions: [
          IconButton(
            icon: Stack(
              children: [
                const Icon(Icons.notifications_none_rounded, color: Color(0xFF0F172A), size: 26),
                if (_unreadNotifs > 0)
                  Positioned(
                    right: 2,
                    top: 2,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: const BoxDecoration(
                        color: Color(0xFFE11D48),
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(minWidth: 14, minHeight: 14),
                      child: Text(
                        '$_unreadNotifs',
                        style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
            onPressed: () => context.push('/notifications'),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 4.0, left: 4.0),
            child: GestureDetector(
              onTap: () => context.push('/profile'),
              child: (user != null && (user.avatarUrl.isNotEmpty || user.googlePhotoUrl.isNotEmpty))
                  ? CircleAvatar(
                      radius: 17,
                      backgroundColor: const Color(0xFFE0E7FF),
                      backgroundImage: AppNetworkImage.provider(
                        user.avatarUrl.isNotEmpty ? user.avatarUrl : user.googlePhotoUrl,
                      ),
                    )
                  : CircleAvatar(
                      radius: 17,
                      backgroundColor: const Color(0xFFE0E7FF),
                      child: Text(
                        displayName.isNotEmpty ? displayName[0].toUpperCase() : 'U',
                        style: const TextStyle(
                          color: Color(0xFF6366F1),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
            ),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded, color: Color(0xFF0F172A)),
            tooltip: 'Options',
            onSelected: (value) {
              if (value == 'language') {
                showProfessionalLanguageSelector(context);
              } else if (value == 'quiz') {
                context.push('/quiz');
              } else if (value == 'profile') {
                context.push('/profile');
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'language',
                child: Row(
                  children: [
                    Icon(Icons.language_rounded, color: Color(0xFF0D9488), size: 20),
                    SizedBox(width: 10),
                    Text('Change Language / ভাষা', style: TextStyle(fontSize: 14)),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'quiz',
                child: Row(
                  children: [
                    Icon(Icons.psychology_outlined, color: Color(0xFF0D9488), size: 20),
                    SizedBox(width: 10),
                    Text('Compatibility Quiz / কুইজ', style: TextStyle(fontSize: 14)),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'profile',
                child: Row(
                  children: [
                    Icon(Icons.person_outline_rounded, color: Color(0xFF6366F1), size: 20),
                    SizedBox(width: 10),
                    Text('My Profile / সেটিংস', style: TextStyle(fontSize: 14)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          _applyFilters();
        },
        color: const Color(0xFFE05626),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 12),

              // Title from Figma: "Find your new best friend."
              Center(
                child: Text(
                  AppStrings.tr(context, 'hero_title'),
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                    color: Color(0xFF1E293B),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Search Bar & Filter Icon matching Figma
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.02),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: TextField(
                  controller: _searchController,
                  onChanged: (val) => _applyFilters(),
                  decoration: InputDecoration(
                    hintText: AppStrings.tr(context, 'search_hint'),
                    hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
                    prefixIcon: const Icon(Icons.search, color: Color(0xFF94A3B8)),
                    suffixIcon: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_searchController.text.isNotEmpty)
                          IconButton(
                            icon: const Icon(Icons.clear, size: 18, color: Color(0xFF94A3B8)),
                            onPressed: () {
                              _searchController.clear();
                              _applyFilters();
                            },
                          ),
                        IconButton(
                          icon: const Icon(Icons.tune_rounded, size: 20, color: Color(0xFFE05626)),
                          onPressed: _openFilterSheet,
                        ),
                      ],
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Interactive Quick Stats Bar (Adoptable Pets, My Requests, Digital Passports)
              const QuickStatsBar(),
              const SizedBox(height: 14),

              // Guest Mode Preview Banner
              if (user?.role.isGuest ?? false)
                Container(
                  margin: const EdgeInsets.only(bottom: 14),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFFDE68A)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.visibility_outlined, size: 20, color: Color(0xFFD97706)),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'Guest Demo Mode: Browsing only. Sign in to apply for pets or chat with rescues.',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF92400E),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      TextButton(
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          backgroundColor: const Color(0xFFD97706),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: () => context.push('/auth/login'),
                        child: const Text('Sign In', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ),

              // AdoptMatch Hero Banner ("Don't Shop... Adopt!")
              const AdoptionBanner(),
              const SizedBox(height: 16),

              // Quick Actions Bar: Swipe, Quiz, Compare Pets, Nearby Clinics
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _QuickActionCard(
                      icon: Icons.style_rounded,
                      iconColor: const Color(0xFFE11D48),
                      title: 'Swipe Match',
                      subtitle: 'Find with 1 swipe',
                      onTap: () => context.push('/swipe'),
                    ),
                    const SizedBox(width: 10),
                    _QuickActionCard(
                      icon: Icons.quiz_rounded,
                      iconColor: const Color(0xFF0D9488),
                      title: 'Lifestyle Quiz',
                      subtitle: '5-step match quiz',
                      onTap: () => context.push('/quiz'),
                    ),
                    const SizedBox(width: 10),
                    _QuickActionCard(
                      icon: Icons.compare_arrows_rounded,
                      iconColor: const Color(0xFF6366F1),
                      title: 'Compare Pets',
                      subtitle: 'Side-by-side view',
                      onTap: () => context.push('/compare'),
                    ),
                    const SizedBox(width: 10),
                    _QuickActionCard(
                      icon: Icons.local_hospital_rounded,
                      iconColor: const Color(0xFFE25B2D),
                      title: 'Nearby Clinics',
                      subtitle: '24/7 emergency care',
                      onTap: () => context.push('/clinics'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Category Pills from Figma
              SizedBox(
                height: 38,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _categories.length,
                  separatorBuilder: (context, index) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final cat = _categories[index];
                    final isSelected = cat == _selectedCategory;
                    return GestureDetector(
                      onTap: () => _onCategorySelected(cat),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                        decoration: BoxDecoration(
                          color: isSelected ? const Color(0xFF6366F1) : Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isSelected ? const Color(0xFF6366F1) : const Color(0xFFE2E8F0),
                          ),
                        ),
                        child: Text(
                          cat,
                          style: TextStyle(
                            color: isSelected ? Colors.white : const Color(0xFF334155),
                            fontSize: 13,
                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 20),

              // Section Header: "Recommended for You" & "View All (48)"
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    AppStrings.tr(context, 'recommended_for_you'),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      setState(() => _selectedCategory = 'All Pets');
                      _applyFilters();
                    },
                    child: const Text(
                      'View All (48)',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF6366F1),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Two-column Pet Cards Grid
              BlocBuilder<PetMatchBloc, PetMatchState>(
                builder: (context, state) {
                  if (state is PetMatchLoading) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 40.0),
                      child: Center(
                        child: CircularProgressIndicator(color: Color(0xFFE05626)),
                      ),
                    );
                  }

                  if (state is PetMatchLoaded) {
                    final pets = state.pets;
                    _precachePetImages(pets);
                    if (pets.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 48.0),
                        child: Center(
                          child: Column(
                            children: [
                              Icon(Icons.pets, size: 54, color: Colors.grey.shade400),
                              const SizedBox(height: 12),
                              const Text(
                                'No companion found matching criteria',
                                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                              ),
                              const SizedBox(height: 6),
                              const Text(
                                'Try clearing some filters or searching a wider area.',
                                style: TextStyle(color: Colors.grey, fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (state.hasCompletedQuiz)
                          Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE6FFFA),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: const Color(0xFF0D9488).withOpacity(0.3)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.verified_rounded, size: 18, color: Color(0xFF0D9488)),
                                const SizedBox(width: 8),
                                const Expanded(
                                  child: Text(
                                    'Ranked by your Compatibility Quiz',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF0D9488),
                                    ),
                                  ),
                                ),
                                InkWell(
                                  onTap: () => context.push('/quiz'),
                                  child: const Text(
                                    'Retake Quiz',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF0D9488),
                                      decoration: TextDecoration.underline,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          )
                        else
                          InkWell(
                            onTap: () => context.push('/quiz'),
                            borderRadius: BorderRadius.circular(14),
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEFF6FF),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: const Color(0xFF3B82F6).withOpacity(0.25)),
                              ),
                              child: Row(
                                children: const [
                                  Icon(Icons.quiz_rounded, size: 18, color: Color(0xFF2563EB)),
                                  SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Take 2-min Quiz to unlock your Compatibility Match %',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF2563EB),
                                      ),
                                    ),
                                  ),
                                  Icon(Icons.arrow_forward_ios_rounded, size: 12, color: Color(0xFF2563EB)),
                                ],
                              ),
                            ),
                          ),
                        GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                            childAspectRatio: 0.76,
                          ),
                          itemCount: pets.length,
                          itemBuilder: (context, index) {
                            final pet = pets[index];
                            return PetCardGridItem(
                              pet: pet,
                              showMatchScore: state.hasCompletedQuiz,
                              onTap: () => context.push('/pets/${pet.id}'),
                              onFavoriteToggle: () {
                                context.read<PetMatchBloc>().add(TogglePetFavoriteEvent(pet.id));
                              },
                            );
                          },
                        ),
                      ],
                    );
                  }

                  return const SizedBox();
                },
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 72),
        child: FloatingActionButton.extended(
          backgroundColor: const Color(0xFFE05626),
          elevation: 5,
          icon: const Icon(Icons.auto_awesome, color: Colors.white, size: 20),
          label: const Text(
            'AI Advisor',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
          ),
          onPressed: () => context.push('/ai-assistant'),
        ),
      ),
    ),
  );
}

  Widget _buildAppDrawer(BuildContext context) {
    final language = AppLocaleScope.of(context).language;

    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: Color(0xFFE05626),
              ),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.12),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.asset(
                        'assets/images/app_logo.png',
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            const Icon(Icons.pets, color: Color(0xFFE05626), size: 28),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          'AdoptMatch BD',
                          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          '100% Free Ethical Adoption',
                          style: TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  ListTile(
                    leading: const Icon(Icons.style, color: Color(0xFFE11D48)),
                    title: const Text('Swipe & Match'),
                    onTap: () {
                      Navigator.pop(context);
                      context.push('/swipe');
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.quiz, color: Color(0xFFE05626)),
                    title: const Text('Compatibility Quiz'),
                    onTap: () {
                      Navigator.pop(context);
                      context.push('/quiz');
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.emergency, color: Color(0xFFE11D48)),
                    title: const Text('24/7 Lost Pet SOS & Clinics'),
                    onTap: () {
                      Navigator.pop(context);
                      context.push('/emergency');
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.assignment, color: Color(0xFF2563EB)),
                    title: const Text('My Adoption Applications'),
                    onTap: () {
                      Navigator.pop(context);
                      context.push('/applications');
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.qr_code, color: Color(0xFFE05626)),
                    title: const Text('Pet Health Passport & QR'),
                    onTap: () {
                      Navigator.pop(context);
                      context.push('/health/p1');
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.forum, color: Color(0xFFF59E0B)),
                    title: const Text('Happy Tails Social Feed'),
                    onTap: () {
                      Navigator.pop(context);
                      context.push('/community');
                    },
                  ),
                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.language_rounded, color: Color(0xFF0D9488)),
                    title: const Text('Change Language / ভাষা পরিবর্তন'),
                    subtitle: Text(language == AppLanguage.en ? 'English (US)' : 'বাংলা (Bangladesh)'),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () {
                      Navigator.pop(context);
                      showProfessionalLanguageSelector(context);
                    },
                  ),
                  const Divider(color: Color(0xFFE2E8F0)),
                  ListTile(
                    leading: const Icon(Icons.logout, color: Color(0xFFEF4444)),
                    title: const Text(
                      'Logout',
                      style: TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.w600),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      showDialog(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          title: const Text('Confirm Logout', style: TextStyle(fontWeight: FontWeight.bold)),
                          content: const Text('Are you sure you want to log out of AdoptMatch?'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx),
                              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
                            ),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFEF4444),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              onPressed: () {
                                Navigator.pop(ctx);
                                context.read<AuthBloc>().add(LogoutEvent());
                                context.go('/auth/login');
                              },
                              child: const Text('Logout'),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                'AdoptMatch v1.0.0 (Production Verified)\nZero Breeder Sales • Non-Profit Animal Welfare',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _QuickActionCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 155,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
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
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF0F172A)),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 10, color: Color(0xFF64748B)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
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

