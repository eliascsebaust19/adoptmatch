import 'package:flutter/material.dart';
import '../../../core/models/pet_model.dart';
import '../../../shared/widgets/status_badge.dart';
import '../../../shared/widgets/app_network_image.dart';

class PetCardGridItem extends StatelessWidget {
  final Pet pet;
  final VoidCallback onTap;
  final VoidCallback onFavoriteToggle;
  final bool showMatchScore;

  const PetCardGridItem({
    super.key,
    required this.pet,
    required this.onTap,
    required this.onFavoriteToggle,
    this.showMatchScore = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image Stack
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  AppNetworkImage(
                    imageUrl: pet.imageUrl,
                    fit: BoxFit.cover,
                  ),

                  // Gradient overlay at bottom
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    height: 40,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [
                            Colors.black.withOpacity(0.3),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Favorite Button
                  Positioned(
                    top: 8,
                    right: 8,
                    child: GestureDetector(
                      onTap: onFavoriteToggle,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.85),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          pet.isFavorite ? Icons.favorite : Icons.favorite_border,
                          size: 16,
                          color: pet.isFavorite ? const Color(0xFFE11D48) : const Color(0xFF64748B),
                        ),
                      ),
                    ),
                  ),

                  // Distance or Urgent tag if applicable
                  if (pet.isUrgent)
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE11D48),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'URGENT',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Pet Info
            Padding(
              padding: const EdgeInsets.all(10.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          pet.name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0F172A),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (showMatchScore) MatchScoreBadge(score: pet.matchScore),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${pet.breed} • ${pet.ageDisplay}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF64748B),
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.location_on_outlined, size: 12, color: Color(0xFF94A3B8)),
                      const SizedBox(width: 2),
                      Expanded(
                        child: Text(
                          '${pet.distanceLabel} away',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF94A3B8),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
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

