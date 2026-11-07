import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/models/pet_model.dart';
import '../../../shared/widgets/custom_button.dart';
import '../../../shared/widgets/app_network_image.dart';

class MatchSuccessDialog extends StatelessWidget {
  final Pet pet;

  const MatchSuccessDialog({super.key, required this.pet});

  @override
  Widget build(BuildContext context) {
    const teal = Color(0xFF0D9488);
    const rose = Color(0xFFE11D48);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Floating Heart Badge
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFFFE4E6),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.favorite, color: rose, size: 36),
            ),
            const SizedBox(height: 16),

            const Text(
              'It\'s a Match!',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'You and ${pet.name} share an amazing ${pet.matchScore}% compatibility score!',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF64748B),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),

            // Pet Avatar
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: SizedBox(
                width: 140,
                height: 140,
                child: AppNetworkImage(
                  imageUrl: pet.imageUrl,
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '${pet.name} • ${pet.breed}',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 24),

            CustomButton(
              text: 'Apply for Adoption',
              backgroundColor: teal,
              onPressed: () {
                Navigator.pop(context);
                context.push('/apply/${pet.id}');
              },
            ),
            const SizedBox(height: 10),

            CustomButton(
              text: 'View Pet Details',
              isOutlined: true,
              backgroundColor: teal,
              onPressed: () {
                Navigator.pop(context);
                context.push('/pets/${pet.id}');
              },
            ),
          ],
        ),
      ),
    );
  }
}
