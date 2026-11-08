import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/models/pet_model.dart';
import '../../../core/repositories/pet_repository.dart';
import '../../../core/repositories/chat_repository.dart';
import '../../../core/widgets/adoptmatch_back_button.dart';
import '../../../core/widgets/guest_restriction_dialog.dart';
import '../../../shared/widgets/status_badge.dart';
import '../../../shared/widgets/custom_button.dart';
import '../../../shared/widgets/app_network_image.dart';
import '../../appointments/widgets/book_appointment_modal.dart';

class PetDetailScreen extends StatefulWidget {
  final String petId;

  const PetDetailScreen({super.key, required this.petId});

  @override
  State<PetDetailScreen> createState() => _PetDetailScreenState();
}

class _PetDetailScreenState extends State<PetDetailScreen> {
  final _petRepo = PetRepository();
  Pet? _pet;
  bool _isLoading = true;
  int _activeImageIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadPet();
  }

  Future<void> _loadPet() async {
    final pet = await _petRepo.getPetById(widget.petId);
    if (!mounted) return;
    setState(() {
      _pet = pet;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    const teal = Color(0xFF0D9488);
    const slateDark = Color(0xFF0F172A);

    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: teal)),
      );
    }

    if (_pet == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Pet Details')),
        body: const Center(child: Text('Pet not found')),
      );
    }

    final pet = _pet!;
    final images = pet.galleryUrls.isNotEmpty
        ? pet.galleryUrls
        : [pet.imageUrl];

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              // Sliver App Bar with Media Carousel
              SliverAppBar(
                expandedHeight: 340,
                pinned: true,
                backgroundColor: Colors.white,
                leading: const AdoptMatchBackButton(
                  fallbackPath: '/home',
                ),
                actions: [
                  Container(
                    margin: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.85),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: Icon(
                        pet.isFavorite ? Icons.favorite : Icons.favorite_border,
                        color: pet.isFavorite
                            ? const Color(0xFFE11D48)
                            : slateDark,
                        size: 20,
                      ),
                      onPressed: () async {
                        try {
                          await _petRepo.toggleFavorite(pet.id);
                          if (mounted) setState(() => _pet = pet.copyWith(isFavorite: !pet.isFavorite));
                        } catch (e) {
                          if (mounted) ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Favorite was not saved: $e')));
                        }
                      },
                    ),
                  ),
                ],
                flexibleSpace: FlexibleSpaceBar(
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      PageView.builder(
                        itemCount: images.length,
                        onPageChanged: (idx) =>
                            setState(() => _activeImageIndex = idx),
                        itemBuilder: (context, index) {
                          return AppNetworkImage(
                            imageUrl: images[index],
                            fit: BoxFit.cover,
                          );
                        },
                      ),
                      // Carousel Indicator Dots
                      if (images.length > 1)
                        Positioned(
                          bottom: 16,
                          left: 0,
                          right: 0,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(images.length, (idx) {
                              final active = idx == _activeImageIndex;
                              return AnimatedContainer(
                                duration: const Duration(milliseconds: 250),
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 3,
                                ),
                                width: active ? 20 : 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  color: active ? teal : Colors.white70,
                                  borderRadius: BorderRadius.circular(3),
                                ),
                              );
                            }),
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              // Content Body
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header Row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  pet.name,
                                  style: const TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.w800,
                                    color: slateDark,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${pet.breed} • ${pet.ageDisplay} old',
                                  style: const TextStyle(
                                    fontSize: 15,
                                    color: Color(0xFF64748B),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (_petRepo.hasCompletedQuiz)
                            MatchScoreBadge(score: pet.matchScore, isLarge: true)
                          else
                            InkWell(
                              onTap: () => context.push('/quiz'),
                              borderRadius: BorderRadius.circular(16),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEFF6FF),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: const Color(0xFF3B82F6).withOpacity(0.3)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: const [
                                    Icon(Icons.quiz_rounded, size: 14, color: Color(0xFF2563EB)),
                                    SizedBox(width: 4),
                                    Text(
                                      'Quiz for Match %',
                                      style: TextStyle(
                                        color: Color(0xFF2563EB),
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Location & Gender Bar
                      Row(
                        children: [
                          const Icon(Icons.location_on, size: 16, color: teal),
                          const SizedBox(width: 4),
                          Text(
                            '${pet.distanceLabel} away (${pet.shelterAddress.split(',').first})',
                            style: const TextStyle(
                              color: Color(0xFF475569),
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '100% Free Adoption',
                            style: TextStyle(
                              color: Colors.green.shade700,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Physical Attribute Cards
                      Row(
                        children: [
                          Expanded(
                            child: _AttributeCard(
                              title: 'Gender',
                              value: pet.gender,
                              icon: pet.gender == 'Male'
                                  ? Icons.male
                                  : Icons.female,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _AttributeCard(
                              title: 'Weight',
                              value: '${pet.weightKg} kg',
                              icon: Icons.scale,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _AttributeCard(
                              title: 'Species',
                              value: pet.species,
                              icon: Icons.pets,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Behavioral Tags
                      const Text(
                        'Temperament & Readiness',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: slateDark,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          if (pet.isApartmentFriendly)
                            _FeatureChip(
                              icon: Icons.apartment,
                              label: 'Apartment Ready',
                              color: Colors.blue,
                            ),
                          if (pet.isKidSafe)
                            _FeatureChip(
                              icon: Icons.child_friendly,
                              label: 'Kid-Safe Tested',
                              color: Colors.green,
                            ),
                          if (pet.isVaccinated)
                            _FeatureChip(
                              icon: Icons.verified_user,
                              label: 'Vaccines Up-to-date',
                              color: Colors.teal,
                            ),
                          if (pet.isNeutered)
                            _FeatureChip(
                              icon: Icons.health_and_safety,
                              label: 'Spayed / Neutered',
                              color: Colors.indigo,
                            ),
                          if (pet.isHouseTrained)
                            _FeatureChip(
                              icon: Icons.home,
                              label: 'House-Trained',
                              color: Colors.amber.shade800,
                            ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Story Section
                      const Text(
                        'About Me',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: slateDark,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        pet.story,
                        style: const TextStyle(
                          fontSize: 14,
                          height: 1.6,
                          color: Color(0xFF334155),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Digital Health Passport Quick Link
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0FDFA),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFCCFBF1)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: teal.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.qr_code_scanner,
                                color: teal,
                                size: 28,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: const [
                                  Text(
                                    'Digital Health Passport',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 15,
                                      color: slateDark,
                                    ),
                                  ),
                                  SizedBox(height: 2),
                                  Text(
                                    'Verified vaccine logs & scannable QR collar tag',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF64748B),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.arrow_forward_ios,
                                size: 16,
                                color: teal,
                              ),
                              onPressed: () =>
                                  context.push('/health/${pet.id}'),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Verified Shelter Card
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          children: [
                            const CircleAvatar(
                              radius: 24,
                              backgroundColor: Color(0xFF0D9488),
                              child: Icon(
                                Icons.shield,
                                color: Colors.white,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Flexible(
                                        child: Text(
                                          pet.shelterName,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 14,
                                            color: slateDark,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      const Icon(
                                        Icons.verified,
                                        size: 16,
                                        color: Color(0xFF2563EB),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${pet.shelterAddress} • ★ ${pet.shelterRating}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF64748B),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),

                      // Schedule Meet & Greet & Comparison Action Row
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              icon: const Icon(
                                Icons.event_available,
                                size: 16,
                                color: teal,
                              ),
                              label: const Text(
                                'Schedule Visit',
                                style: TextStyle(
                                  color: teal,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                side: const BorderSide(color: teal),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              onPressed: () async {
                                final isRestricted = await GuestRestrictionDialog.checkAndShow(
                                  context,
                                  featureName: 'Shelter Visit Appointment',
                                  customMessage: 'Scheduling a physical shelter visit requires a verified profile to confirm your contact info with the shelter coordinator.\n\nসেল্টার ভিজিটের সময় বুক করতে অনুগ্রহ করে সাইন ইন করুন।',
                                );
                                if (isRestricted || !context.mounted) return;

                                showModalBottomSheet(
                                  context: context,
                                  isScrollControlled: true,
                                  shape: const RoundedRectangleBorder(
                                    borderRadius: BorderRadius.vertical(
                                      top: Radius.circular(24),
                                    ),
                                  ),
                                  builder: (context) =>
                                      BookAppointmentModal(pet: pet),
                                );
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: OutlinedButton.icon(
                              icon: const Icon(
                                Icons.compare_arrows_rounded,
                                size: 16,
                                color: Color(0xFF6366F1),
                              ),
                              label: const Text(
                                'Compare Pet',
                                style: TextStyle(
                                  color: Color(0xFF6366F1),
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                side: const BorderSide(
                                  color: Color(0xFF6366F1),
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              onPressed: () =>
                                  context.push('/compare/${pet.id}'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 100),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // Sticky Bottom CTA Bar
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 16,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
                child: Row(
                  children: [
                    // Chat Button
                    InkWell(
                      onTap: () async {
                        final isRestricted = await GuestRestrictionDialog.checkAndShow(
                          context,
                          featureName: 'Direct Shelter Messaging',
                          customMessage: 'Direct communication with shelter managers is restricted in demo mode. Please sign in or register to message.\n\nসেল্টারের সাথে সরাসরি চ্যাট করতে সাইন ইন করুন।',
                        );
                        if (isRestricted || !context.mounted) return;

                        try {
                          final conv = await ChatRepository().getOrCreateConversationForPet(pet);
                          if (context.mounted) context.push('/chat/${conv.id}');
                        } catch (e) {
                          if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('$e')));
                        }
                      },
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        height: 52,
                        width: 52,
                        decoration: BoxDecoration(
                          border: Border.all(color: teal, width: 1.5),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(
                          Icons.chat_bubble_outline_rounded,
                          color: teal,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Apply Button
                    Expanded(
                      child: CustomButton(
                        text: 'Apply for Adoption',
                        backgroundColor: teal,
                        onPressed: () async {
                          final isRestricted = await GuestRestrictionDialog.checkAndShow(
                            context,
                            featureName: 'Adoption Application',
                            customMessage: 'Submitting a legal adoption application requires an active account to review your application status and sign adoption agreements.\n\nঅ্যাডপশন আবেদন জমা দেওয়ার জন্য একটি একাউন্ট প্রয়োজন। ডেমো মোডে শুধু পেট দেখা যাবে।',
                          );
                          if (isRestricted || !context.mounted) return;

                          context.push('/apply/${pet.id}');
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AttributeCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;

  const _AttributeCard({
    required this.title,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          Icon(icon, size: 20, color: const Color(0xFF0D9488)),
          const SizedBox(height: 6),
          Text(
            title,
            style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Color(0xFF0F172A),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _FeatureChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _FeatureChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
