import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../bloc/pet_match_bloc.dart';
import '../widgets/match_success_dialog.dart';
import '../../../core/models/pet_model.dart';
import '../../../shared/widgets/shared_widgets.dart';

class SwipeMatchScreen extends StatefulWidget {
  const SwipeMatchScreen({super.key});

  @override
  State<SwipeMatchScreen> createState() => _SwipeMatchScreenState();
}

class _SwipeMatchScreenState extends State<SwipeMatchScreen> {
  int _currentIndex = 0;
  Offset _dragOffset = Offset.zero;

  @override
  Widget build(BuildContext context) {
    const teal = Color(0xFF0D9488);
    const rose = Color(0xFFE11D48);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Swipe & Match'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() => _currentIndex = 0);
              context.read<PetMatchBloc>().add(const LoadPetsEvent());
            },
          ),
        ],
      ),
      body: BlocConsumer<PetMatchBloc, PetMatchState>(
        listener: (context, state) {
          if (state is PetMatchLoaded && state.lastMatchedPet != null) {
            showDialog(
              context: context,
              builder: (context) => MatchSuccessDialog(pet: state.lastMatchedPet!),
            );
          }
        },
        builder: (context, state) {
          if (state is PetMatchLoading) {
            return const Center(
              child: AppLoadingIndicator(message: 'Finding best companion matches...'),
            );
          }

          if (state is PetMatchLoaded) {
            final pets = state.pets;
            if (_currentIndex >= pets.length) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: AppEmptyState(
                    title: 'You\'ve seen all nearby matches!',
                    message: 'Check back later as shelters register new rescues every day.',
                    icon: Icons.check_circle_outline,
                    actionText: 'Start Over',
                    onAction: () => setState(() => _currentIndex = 0),
                  ),
                ),
              );
            }

            final currentPet = pets[_currentIndex];
            final nextPet = _currentIndex + 1 < pets.length ? pets[_currentIndex + 1] : null;

            return SafeArea(
              child: Column(
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          if (nextPet != null)
                            _buildPetCard(
                              nextPet,
                              isBackground: true,
                              showMatchScore: state.hasCompletedQuiz,
                            ),
                          GestureDetector(
                            onPanUpdate: (details) {
                              setState(() {
                                _dragOffset += details.delta;
                              });
                            },
                            onPanEnd: (details) {
                              if (_dragOffset.dx > 120) {
                                _handleSwipeRight(currentPet);
                              } else if (_dragOffset.dx < -120) {
                                _handleSwipeLeft(currentPet);
                              } else if (_dragOffset.dy < -120) {
                                _handleSwipeUp(currentPet);
                              } else {
                                setState(() {
                                  _dragOffset = Offset.zero;
                                });
                              }
                            },
                            child: Transform.translate(
                              offset: _dragOffset,
                              child: Transform.rotate(
                                angle: _dragOffset.dx / 1000,
                                child: _buildPetCard(
                                  currentPet,
                                  isBackground: false,
                                  showMatchScore: state.hasCompletedQuiz,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Bottom Action Buttons
                  Padding(
                    padding: const EdgeInsets.only(bottom: 24, top: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        // Pass (X)
                        _ActionButton(
                          icon: Icons.close,
                          iconColor: const Color(0xFF64748B),
                          size: 54,
                          onTap: () => _handleSwipeLeft(currentPet),
                        ),
                        // Super Like (Star)
                        _ActionButton(
                          icon: Icons.star_rounded,
                          iconColor: const Color(0xFF3B82F6),
                          size: 48,
                          onTap: () => _handleSwipeUp(currentPet),
                        ),
                        // Like / Match (Heart)
                        _ActionButton(
                          icon: Icons.favorite,
                          iconColor: rose,
                          size: 60,
                          onTap: () => _handleSwipeRight(currentPet),
                        ),
                        // Details Info
                        _ActionButton(
                          icon: Icons.info_outline_rounded,
                          iconColor: teal,
                          size: 48,
                          onTap: () => context.push('/pets/${currentPet.id}'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }

          return const SizedBox();
        },
      ),
    );
  }

  void _handleSwipeLeft(Pet pet) {
    context.read<PetMatchBloc>().add(SwipePetLeft(pet.id));
    setState(() {
      _currentIndex++;
      _dragOffset = Offset.zero;
    });
  }

  void _handleSwipeRight(Pet pet) {
    context.read<PetMatchBloc>().add(SwipePetRight(pet.id));
    setState(() {
      _currentIndex++;
      _dragOffset = Offset.zero;
    });
  }

  void _handleSwipeUp(Pet pet) {
    context.read<PetMatchBloc>().add(SwipePetUp(pet.id));
    setState(() {
      _currentIndex++;
      _dragOffset = Offset.zero;
    });
  }

  Widget _buildPetCard(
    Pet pet, {
    required bool isBackground,
    bool showMatchScore = false,
  }) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      margin: EdgeInsets.all(isBackground ? 12 : 0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isBackground ? 0.04 : 0.1),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          AppNetworkImage(
            imageUrl: pet.imageUrl,
            fit: BoxFit.cover,
          ),

          // Gradient scrim
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            height: 220,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Colors.black.withOpacity(0.9),
                    Colors.black.withOpacity(0.5),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          // Overlay Tag if dragging
          if (!isBackground && _dragOffset.dx.abs() > 40)
            Positioned(
              top: 32,
              left: _dragOffset.dx > 0 ? 32 : null,
              right: _dragOffset.dx < 0 ? 32 : null,
              child: Transform.rotate(
                angle: _dragOffset.dx > 0 ? -0.2 : 0.2,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: _dragOffset.dx > 0 ? const Color(0xFF10B981) : const Color(0xFFE11D48),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _dragOffset.dx > 0 ? 'MATCH' : 'PASS',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2,
                    ),
                  ),
                ),
              ),
            ),

          // Match Score Badge Top Right (Shown only after quiz)
          if (showMatchScore)
            Positioned(
              top: 20,
              right: 20,
              child: MatchScoreBadge(score: pet.matchScore, isLarge: true),
            ),

          // Info Overlay
          Positioned(
            bottom: 20,
            left: 20,
            right: 20,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Flexible(
                      child: Text(
                        pet.name,
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      pet.ageDisplay,
                      style: const TextStyle(
                        fontSize: 20,
                        color: Colors.white70,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${pet.breed} • ${pet.gender} • ${pet.distanceKm} km away',
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.white70,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    if (pet.isApartmentFriendly)
                      _BadgeChip(label: 'Apartment Ready', icon: Icons.apartment),
                    if (pet.isKidSafe)
                      _BadgeChip(label: 'Kid-Safe', icon: Icons.child_care),
                    if (pet.isVaccinated)
                      _BadgeChip(label: 'Vaccinated', icon: Icons.verified),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  pet.story,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final double size;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.iconColor,
    required this.size,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Icon(icon, color: iconColor, size: size * 0.5),
      ),
    );
  }
}

class _BadgeChip extends StatelessWidget {
  final String label;
  final IconData icon;

  const _BadgeChip({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: Colors.white),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

