import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/services/local_storage_service.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentIndex = 0;

  final List<_OnboardingCardData> _cards = const [
    _OnboardingCardData(
      title: 'Swipe to Match Pets 🐾',
      subtitle: 'Location-Based Smart Pet Matching',
      description: 'Find your perfect animal companion tailored to your living space, lifestyle, and preferences. Discover adoptable shelter pets near you with ease.',
      icon: Icons.pets_rounded,
      primaryColor: Color(0xFF0D9488),
      secondaryColor: Color(0xFF14B8A6),
      features: [
        'Curated matches based on your lifestyle profile',
        'Filter adoptable pets by breed, age, and location radius',
        'Direct connection to registered rescue shelters',
      ],
    ),
    _OnboardingCardData(
      title: 'Digital Health Passport 🏥',
      subtitle: 'Medical History, QR Code Access & Vet Reminders',
      description: 'Every pet has a digital medical profile. Access vaccination history, upcoming treatment schedules, and verified vet health records anytime.',
      icon: Icons.health_and_safety_rounded,
      primaryColor: Color(0xFF0284C7),
      secondaryColor: Color(0xFF38BDF8),
      features: [
        'Tamper-proof medical records verified by licensed vets',
        'Instant pet ID and health verification via QR scan',
        'Smart reminders for vaccinations, deworming, and check-ups',
      ],
    ),
    _OnboardingCardData(
      title: 'Real-time Chat & SOS 🚨',
      subtitle: 'Direct Shelter Messaging & 5km Lost-Pet Broadcast',
      description: 'Coordinate directly with shelters throughout your adoption process, or trigger emergency alerts to notify pet lovers in your area if a pet goes missing.',
      icon: Icons.notifications_active_rounded,
      primaryColor: Color(0xFFE05626),
      secondaryColor: Color(0xFFF97316),
      features: [
        'Direct in-app messaging with shelters and foster parents',
        '5km neighborhood emergency broadcasts for lost pets',
        'Community-supported rescue reporting and updates',
      ],
    ),
  ];

  Future<void> _completeOnboarding() async {
    await LocalStorageService.instance.saveHasSeenOnboarding(true);
    if (!mounted) return;
    context.go('/login');
  }

  void _onNextPressed() {
    if (_currentIndex < _cards.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeInOutCubic,
      );
    } else {
      _completeOnboarding();
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLastPage = _currentIndex == _cards.length - 1;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar with Logo & Skip Action
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0D9488).withOpacity(0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.pets,
                          color: Color(0xFF0D9488),
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'AdoptMatch',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                          letterSpacing: -0.5,
                        ),
                      ),
                    ],
                  ),
                  TextButton(
                    onPressed: _completeOnboarding,
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF64748B),
                      textStyle: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    child: const Text('Skip'),
                  ),
                ],
              ),
            ),

            // PageView Carousel Cards
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _cards.length,
                onPageChanged: (index) {
                  setState(() {
                    _currentIndex = index;
                  });
                },
                itemBuilder: (context, index) {
                  final card = _cards[index];
                  return SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const SizedBox(height: 16),
                        // Visual Illustration Card
                        Container(
                          width: double.infinity,
                          height: 220,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                card.primaryColor.withOpacity(0.15),
                                card.secondaryColor.withOpacity(0.05),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: card.primaryColor.withOpacity(0.2),
                              width: 1.5,
                            ),
                          ),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Positioned(
                                right: -20,
                                bottom: -20,
                                child: Container(
                                  width: 120,
                                  height: 120,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: card.primaryColor.withOpacity(0.08),
                                  ),
                                ),
                              ),
                              Positioned(
                                left: -30,
                                top: -30,
                                child: Container(
                                  width: 100,
                                  height: 100,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: card.secondaryColor.withOpacity(
                                      0.08,
                                    ),
                                  ),
                                ),
                              ),
                              Container(
                                width: 88,
                                height: 88,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: LinearGradient(
                                    colors: [
                                      card.primaryColor,
                                      card.secondaryColor,
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: card.primaryColor.withOpacity(
                                        0.35,
                                      ),
                                      blurRadius: 20,
                                      offset: const Offset(0, 8),
                                    ),
                                  ],
                                ),
                                child: Icon(
                                  card.icon,
                                  size: 44,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 28),

                        // Title & Subtitle
                        Text(
                          card.title,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F172A),
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          card.subtitle,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: card.primaryColor,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          card.description,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 14,
                            color: Color(0xFF64748B),
                            height: 1.5,
                          ),
                        ),

                        const SizedBox(height: 20),

                        // Highlight Feature Bullets
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.02),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: card.features.map((feature) {
                              return Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 4,
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.only(
                                        top: 2,
                                        right: 10,
                                      ),
                                      child: Icon(
                                        Icons.check_circle_rounded,
                                        size: 16,
                                        color: card.primaryColor,
                                      ),
                                    ),
                                    Expanded(
                                      child: Text(
                                        feature,
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500,
                                          color: Color(0xFF334155),
                                          height: 1.35,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],
                    ),
                  );
                },
              ),
            ),

            // Bottom Navigation Indicators & Action Button
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Animated Indicator Dots
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(_cards.length, (index) {
                      final isSelected = _currentIndex == index;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        height: 8,
                        width: isSelected ? 24 : 8,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? const Color(0xFF0D9488)
                              : const Color(0xFFE2E8F0),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 16),

                  // Bottom Action Button
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _onNextPressed,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isLastPage
                            ? const Color(0xFF0D9488)
                            : const Color(0xFF0F172A),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text(
                        isLastPage ? 'Get Started 🎉' : 'Next ➔',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
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

class _OnboardingCardData {
  final String title;
  final String subtitle;
  final String description;
  final IconData icon;
  final Color primaryColor;
  final Color secondaryColor;
  final List<String> features;

  const _OnboardingCardData({
    required this.title,
    required this.subtitle,
    required this.description,
    required this.icon,
    required this.primaryColor,
    required this.secondaryColor,
    required this.features,
  });
}
