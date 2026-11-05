import 'package:flutter/material.dart';
import '../../../shared/widgets/custom_button.dart';

class FilterModalSheet extends StatefulWidget {
  final double currentDistance;
  final bool kidSafe;
  final bool apartmentFriendly;
  final bool vaccinated;
  final Function(double distance, bool kidSafe, bool apartment, bool vaccinated) onApply;

  const FilterModalSheet({
    super.key,
    required this.currentDistance,
    required this.kidSafe,
    required this.apartmentFriendly,
    required this.vaccinated,
    required this.onApply,
  });

  @override
  State<FilterModalSheet> createState() => _FilterModalSheetState();
}

class _FilterModalSheetState extends State<FilterModalSheet> {
  late double _distance;
  late bool _kidSafe;
  late bool _apartmentFriendly;
  late bool _vaccinated;

  @override
  void initState() {
    super.initState();
    _distance = widget.currentDistance;
    _kidSafe = widget.kidSafe;
    _apartmentFriendly = widget.apartmentFriendly;
    _vaccinated = widget.vaccinated;
  }

  @override
  Widget build(BuildContext context) {
    const teal = Color(0xFF0D9488);
    const slateDark = Color(0xFF0F172A);

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 18),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Filter Pets',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: slateDark,
                ),
              ),
              TextButton(
                onPressed: () {
                  setState(() {
                    _distance = 50.0;
                    _kidSafe = false;
                    _apartmentFriendly = false;
                    _vaccinated = false;
                  });
                },
                child: const Text('Reset', style: TextStyle(color: Color(0xFF64748B))),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Proximity Radius
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Maximum Distance',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: slateDark),
              ),
              Text(
                _distance >= 50 ? 'Nationwide' : '${_distance.toInt()} km',
                style: const TextStyle(fontWeight: FontWeight.w700, color: teal),
              ),
            ],
          ),
          Slider(
            value: _distance,
            min: 5,
            max: 50,
            divisions: 9,
            activeColor: teal,
            inactiveColor: const Color(0xFFE2E8F0),
            onChanged: (val) => setState(() => _distance = val),
          ),
          const SizedBox(height: 16),

          // Behavioral & Lifestyle Filters
          const Text(
            'Lifestyle & Environment',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: slateDark),
          ),
          const SizedBox(height: 12),

          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilterChip(
                selected: _apartmentFriendly,
                label: const Text('Apartment Friendly'),
                selectedColor: const Color(0xFFCCFBF1),
                checkmarkColor: teal,
                labelStyle: TextStyle(
                  color: _apartmentFriendly ? teal : const Color(0xFF334155),
                  fontWeight: FontWeight.w600,
                ),
                onSelected: (val) => setState(() => _apartmentFriendly = val),
              ),
              FilterChip(
                selected: _kidSafe,
                label: const Text('Good for Kids'),
                selectedColor: const Color(0xFFCCFBF1),
                checkmarkColor: teal,
                labelStyle: TextStyle(
                  color: _kidSafe ? teal : const Color(0xFF334155),
                  fontWeight: FontWeight.w600,
                ),
                onSelected: (val) => setState(() => _kidSafe = val),
              ),
              FilterChip(
                selected: _vaccinated,
                label: const Text('Vaccinated Only'),
                selectedColor: const Color(0xFFCCFBF1),
                checkmarkColor: teal,
                labelStyle: TextStyle(
                  color: _vaccinated ? teal : const Color(0xFF334155),
                  fontWeight: FontWeight.w600,
                ),
                onSelected: (val) => setState(() => _vaccinated = val),
              ),
            ],
          ),
          const SizedBox(height: 28),

            CustomButton(
              text: 'Apply Filters',
              backgroundColor: teal,
              onPressed: () {
                widget.onApply(_distance, _kidSafe, _apartmentFriendly, _vaccinated);
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    ),
  );
  }
}

