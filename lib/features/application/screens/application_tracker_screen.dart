import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../auth/bloc/auth_bloc.dart';
import '../../../core/models/application_model.dart';
import '../../../core/repositories/application_repository.dart';
import '../../../core/repositories/pet_repository.dart';
import '../../../core/repositories/chat_repository.dart';
import '../../../shared/widgets/shared_widgets.dart';

class ApplicationTrackerScreen extends StatefulWidget {
  const ApplicationTrackerScreen({super.key});

  @override
  State<ApplicationTrackerScreen> createState() =>
      _ApplicationTrackerScreenState();
}

class _ApplicationTrackerScreenState extends State<ApplicationTrackerScreen> {
  final _appRepo = ApplicationRepository();
  List<AdoptionApplication> _applications = [];
  bool _isLoading = true;
  StreamSubscription? _sub;

  @override
  void initState() {
    super.initState();
    _loadApplications();
    _sub = _appRepo.applicationsStream.listen((apps) {
      if (mounted) {
        setState(() {
          _applications = apps;
          _isLoading = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _loadApplications() async {
    try {
      final apps = await _appRepo.getApplications();
      if (mounted) setState(() { _applications = apps; _isLoading = false; });
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not sync applications: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const teal = Color(0xFF0D9488);
    final authState = context.watch<AuthBloc>().state;
    final isGuest = authState is Authenticated && authState.user.role.isGuest;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(title: const Text('My Adoption Applications')),
      body: _isLoading
          ? const Center(child: AppLoadingIndicator(message: 'Loading your applications...'))
          : Column(
              children: [
                if (isGuest)
                  Container(
                    margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFFDE68A)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.visibility_outlined, size: 20, color: Color(0xFFD97706)),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Text(
                            'Guest Demo Mode: Viewing sample application tracking. Sign in to submit and track your actual applications.',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF92400E)),
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
                Expanded(
                  child: _applications.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24.0),
                            child: AppEmptyState(
                              icon: Icons.assignment_outlined,
                              title: 'No applications yet',
                              message: 'Browse pets and submit an application to start your journey.',
                              actionText: 'Find Pets to Adopt',
                              onAction: () => context.go('/home'),
                            ),
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: _loadApplications,
                          color: teal,
                          child: ListView.separated(
                            padding: const EdgeInsets.all(16),
                            itemCount: _applications.length,
                            separatorBuilder: (context, index) =>
                                const SizedBox(height: 16),
                            itemBuilder: (context, index) {
                              final app = _applications[index];
                              return _ApplicationStatusCard(app: app);
                            },
                          ),
                        ),
                ),
              ],
            ),
    );
  }
}

class _ApplicationStatusCard extends StatelessWidget {
  final AdoptionApplication app;

  const _ApplicationStatusCard({required this.app});

  @override
  Widget build(BuildContext context) {
    const teal = Color(0xFF0D9488);
    const slateDark = Color(0xFF0F172A);

    final stages = [
      'Submitted',
      'Under Review',
      'Home Visit',
      'Trial Foster',
      'Approved',
    ];

    final currentStep = app.status.stepIndex;

    return Container(
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
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Pet Header
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: 54,
                  height: 54,
                  child: AppNetworkImage(
                    imageUrl: app.petImageUrl,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      app.petName,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: slateDark,
                      ),
                    ),
                    Text(
                      '${app.petBreed} • Ref #${app.id}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFCCFBF1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  app.status.displayName,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F766E),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Stepper Indicator
          Row(
            children: List.generate(stages.length, (idx) {
              final isPassed = idx <= currentStep;
              final isCurrent = idx == currentStep;
              return Expanded(
                child: Row(
                  children: [
                    Container(
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        color: isPassed ? teal : const Color(0xFFE2E8F0),
                        shape: BoxShape.circle,
                        border: isCurrent
                            ? Border.all(
                                color: const Color(0xFF14B8A6),
                                width: 3,
                              )
                            : null,
                      ),
                      child: isPassed
                          ? const Icon(
                              Icons.check,
                              size: 10,
                              color: Colors.white,
                            )
                          : null,
                    ),
                    if (idx < stages.length - 1)
                      Expanded(
                        child: Container(
                          height: 3,
                          color: idx < currentStep
                              ? teal
                              : const Color(0xFFE2E8F0),
                        ),
                      ),
                  ],
                ),
              );
            }),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Current Stage: ${stages[currentStep.clamp(0, stages.length - 1)]}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: slateDark,
                ),
              ),
              Text(
                '${app.submittedAt.day}/${app.submittedAt.month}/${app.submittedAt.year}',
                style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Reviewer Notes box
          if (app.reviewerNotes != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.chat_outlined, size: 16, color: teal),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Shelter Update: ${app.reviewerNotes}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF334155),
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 14),

          // Actions
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                icon: const Icon(Icons.pets, size: 16, color: slateDark),
                label: const Text(
                  'View Pet',
                  style: TextStyle(color: slateDark, fontSize: 13),
                ),
                onPressed: () => context.push('/pets/${app.petId}'),
              ),
              const SizedBox(width: 4),
              TextButton.icon(
                icon: const Icon(
                  Icons.chat_bubble_outline,
                  size: 16,
                  color: teal,
                ),
                label: const Text(
                  'Contact Shelter',
                  style: TextStyle(color: teal, fontSize: 13),
                ),
                onPressed: () async {
                  try {
                    final pet = await PetRepository().getPetById(app.petId);
                    if (pet == null) throw Exception('The listing is no longer available.');
                    final conv = await ChatRepository().getOrCreateConversationForPet(pet);
                    if (context.mounted) context.push('/chat/${conv.id}');
                  } catch (e) {
                    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
                  }
                },
              ),
              const SizedBox(width: 4),
              OutlinedButton.icon(
                icon: const Icon(Icons.qr_code, size: 16, color: slateDark),
                label: const Text(
                  'Health Passport',
                  style: TextStyle(color: slateDark, fontSize: 13),
                ),
                onPressed: () => context.push('/health/${app.petId}'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
