import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/repositories/pet_repository.dart';
import '../../../core/repositories/application_repository.dart';

/// Interactive Quick Stats Bar on Home Screen.
/// Displays live counts for:
/// - Adoptable Pets (routes to /find)
/// - My Requests (routes to /applications)
/// - Digital Passports (routes to /health-passport)
class QuickStatsBar extends StatefulWidget {
  const QuickStatsBar({super.key});

  @override
  State<QuickStatsBar> createState() => _QuickStatsBarState();
}

class _QuickStatsBarState extends State<QuickStatsBar> {
  final _petRepo = PetRepository();
  final _appRepo = ApplicationRepository();

  int _petsCount = 0;
  int _requestsCount = 0;
  int _passportsCount = 0;

  StreamSubscription? _petSub;
  StreamSubscription? _appSub;

  @override
  void initState() {
    super.initState();
    _loadInitialCounts();

    _petSub = _petRepo.petsStream.listen((pets) {
      if (mounted) {
        setState(() {
          _petsCount = pets.length;
          _passportsCount = pets.where((p) => p.qrHash.isNotEmpty).length;
        });
      }
    });

    _appSub = _appRepo.applicationsStream.listen((apps) {
      if (mounted) {
        setState(() {
          _requestsCount = apps.length;
        });
      }
    });
  }

  Future<void> _loadInitialCounts() async {
    final pets = await _petRepo.fetchAvailablePets();
    final apps = await _appRepo.getApplications();
    if (mounted) {
      setState(() {
        _petsCount = pets.length;
        _passportsCount = pets.where((p) => p.qrHash.isNotEmpty).length;
        _requestsCount = apps.length;
      });
    }
  }

  @override
  void dispose() {
    _petSub?.cancel();
    _appSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          // 1. Adoptable Pets
          Expanded(
            child: _QuickStatCard(
              icon: Icons.pets_rounded,
              iconColor: const Color(0xFFE05626), // Terra Cotta
              accentBg: const Color(0xFFFFF1EB),
              value: '$_petsCount',
              label: 'Adoptable Pets',
              onTap: () => context.push('/find'),
            ),
          ),
          const SizedBox(width: 8),

          // 2. My Requests
          Expanded(
            child: _QuickStatCard(
              icon: Icons.assignment_outlined,
              iconColor: const Color(0xFF0D9488), // Teal
              accentBg: const Color(0xFFE6FFFA),
              value: '$_requestsCount',
              label: 'My Requests',
              onTap: () => context.push('/applications'),
            ),
          ),
          const SizedBox(width: 8),

          // 3. Digital Passports
          Expanded(
            child: _QuickStatCard(
              icon: Icons.qr_code_2_rounded,
              iconColor: const Color(0xFF6366F1), // Indigo
              accentBg: const Color(0xFFEEF2FF),
              value: '$_passportsCount',
              label: 'Digital Passports',
              onTap: () => context.push('/health-passport'),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickStatCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color accentBg;
  final String value;
  final String label;
  final VoidCallback onTap;

  const _QuickStatCard({
    required this.icon,
    required this.iconColor,
    required this.accentBg,
    required this.value,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0F172A).withOpacity(0.02),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: accentBg,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, color: iconColor, size: 17),
                  ),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF64748B),
                  height: 1.15,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

