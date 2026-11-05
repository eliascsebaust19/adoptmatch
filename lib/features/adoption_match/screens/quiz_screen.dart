import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../bloc/pet_match_bloc.dart';
import '../../../core/widgets/adoptmatch_back_button.dart';
import '../../../shared/widgets/custom_button.dart';

class CompatibilityQuizScreen extends StatefulWidget {
  const CompatibilityQuizScreen({super.key});

  @override
  State<CompatibilityQuizScreen> createState() => _CompatibilityQuizScreenState();
}

class _CompatibilityQuizScreenState extends State<CompatibilityQuizScreen> {
  int _currentStep = 0;

  // Answers
  String _selectedHousing = 'Apartment';
  bool _hasKids = false;
  bool _hasPets = false;
  int _hoursAlone = 4;
  String _experience = 'Intermediate';

  final List<String> _housingOptions = ['Apartment', 'House with Yard', 'Farm / Rural'];
  final List<String> _kidsOptions = ['Yes, toddlers or young kids', 'No children in household'];
  final List<String> _petsOptions = ['Yes, have dogs or cats', 'No other pets currently'];
  final List<String> _hoursOptions = ['Less than 2 hours', '2 - 4 hours', '4 - 8 hours', '8+ hours'];
  final List<String> _expOptions = ['First-time pet parent', 'Intermediate (Owned pets before)', 'Experienced trainer / foster'];

  void _nextStep() {
    if (_currentStep < 4) {
      setState(() => _currentStep++);
    } else {
      // Finished!
      context.read<PetMatchBloc>().add(
        ApplyQuizFilterEvent(
          housing: _selectedHousing,
          hasKids: _hasKids,
          hasPets: _hasPets,
          hoursAlone: _hoursAlone,
          experience: _experience,
        ),
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🎉 Lifestyle Quiz completed! Pets ranked by your compatibility score.'),
          backgroundColor: Color(0xFF0D9488),
        ),
      );

      context.go('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    const teal = Color(0xFF0D9488);
    const slateDark = Color(0xFF0F172A);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        leading: const AdoptMatchBackButton(fallbackPath: '/home'),
        title: const Text('Compatibility Quiz'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Progress Bar
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Step ${_currentStep + 1} of 5',
                    style: const TextStyle(fontWeight: FontWeight.w700, color: teal, fontSize: 13),
                  ),
                  Text(
                    '${((_currentStep + 1) / 5 * 100).toInt()}% Complete',
                    style: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: (_currentStep + 1) / 5,
                  backgroundColor: const Color(0xFFE2E8F0),
                  color: teal,
                  minHeight: 6,
                ),
              ),
              const SizedBox(height: 28),

              // Step Content
              Expanded(
                child: SingleChildScrollView(
                  child: _buildCurrentQuestion(slateDark, teal),
                ),
              ),

              // Action buttons
              Row(
                children: [
                  if (_currentStep > 0) ...[
                    Expanded(
                      flex: 1,
                      child: CustomButton(
                        text: 'Back',
                        isOutlined: true,
                        backgroundColor: const Color(0xFF64748B),
                        onPressed: () => setState(() => _currentStep--),
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    flex: 2,
                    child: CustomButton(
                      text: _currentStep == 4 ? 'Calculate Matches' : 'Continue',
                      backgroundColor: teal,
                      onPressed: _nextStep,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentQuestion(Color slateDark, Color teal) {
    switch (_currentStep) {
      case 0:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'What type of home do you live in?',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
            ),
            const SizedBox(height: 8),
            const Text(
              'This helps match pets with the right activity and space requirements.',
              style: TextStyle(fontSize: 14, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 24),
            ..._housingOptions.map((opt) {
              final isSelected = _selectedHousing == opt;
              return _QuizOptionTile(
                title: opt,
                isSelected: isSelected,
                onTap: () => setState(() => _selectedHousing = opt),
              );
            }),
          ],
        );

      case 1:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Are there children in your household?',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
            ),
            const SizedBox(height: 8),
            const Text(
              'We prioritize kid-tested and patient companion animals.',
              style: TextStyle(fontSize: 14, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 24),
            _QuizOptionTile(
              title: _kidsOptions[0],
              isSelected: _hasKids,
              onTap: () => setState(() => _hasKids = true),
            ),
            _QuizOptionTile(
              title: _kidsOptions[1],
              isSelected: !_hasKids,
              onTap: () => setState(() => _hasKids = false),
            ),
          ],
        );

      case 2:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Do you currently have other pets?',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
            ),
            const SizedBox(height: 8),
            const Text(
              'Ensures compatible social temperament and socialization.',
              style: TextStyle(fontSize: 14, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 24),
            _QuizOptionTile(
              title: _petsOptions[0],
              isSelected: _hasPets,
              onTap: () => setState(() => _hasPets = true),
            ),
            _QuizOptionTile(
              title: _petsOptions[1],
              isSelected: !_hasPets,
              onTap: () => setState(() => _hasPets = false),
            ),
          ],
        );

      case 3:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'How many hours will the pet be home alone daily?',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
            ),
            const SizedBox(height: 8),
            const Text(
              'Some breeds require frequent interaction while others are very independent.',
              style: TextStyle(fontSize: 14, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 24),
            ..._hoursOptions.asMap().entries.map((entry) {
              final idx = entry.key;
              final opt = entry.value;
              final hourVal = [1, 3, 6, 9][idx];
              final isSelected = _hoursAlone == hourVal;
              return _QuizOptionTile(
                title: opt,
                isSelected: isSelected,
                onTap: () => setState(() => _hoursAlone = hourVal),
              );
            }),
          ],
        );

      case 4:
      default:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'What is your pet parenting experience level?',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
            ),
            const SizedBox(height: 8),
            const Text(
              'Helps suggest rescues matching your comfort with training and healthcare.',
              style: TextStyle(fontSize: 14, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 24),
            ..._expOptions.map((opt) {
              final isSelected = _experience == opt;
              return _QuizOptionTile(
                title: opt,
                isSelected: isSelected,
                onTap: () => setState(() => _experience = opt),
              );
            }),
          ],
        );
    }
  }
}

class _QuizOptionTile extends StatelessWidget {
  final String title;
  final bool isSelected;
  final VoidCallback onTap;

  const _QuizOptionTile({
    required this.title,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const teal = Color(0xFF0D9488);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFF0FDFA) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? teal : const Color(0xFFE2E8F0),
            width: isSelected ? 2 : 1,
          ),
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
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? teal : const Color(0xFFCBD5E1),
                  width: 2,
                ),
                color: isSelected ? teal : Colors.transparent,
              ),
              child: isSelected
                  ? const Icon(Icons.check, size: 14, color: Colors.white)
                  : null,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? const Color(0xFF0F766E) : const Color(0xFF1E293B),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

