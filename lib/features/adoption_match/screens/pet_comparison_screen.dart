import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/models/pet_model.dart';
import '../../../core/repositories/pet_repository.dart';
import '../../../shared/widgets/app_network_image.dart';

class PetComparisonScreen extends StatefulWidget {
  final String? initialPetId;

  const PetComparisonScreen({super.key, this.initialPetId});

  @override
  State<PetComparisonScreen> createState() => _PetComparisonScreenState();
}

class _PetComparisonScreenState extends State<PetComparisonScreen> {
  final _petRepo = PetRepository();
  List<Pet> _allPets = [];
  Pet? _petA;
  Pet? _petB;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPets();
  }

  Future<void> _loadPets() async {
    final pets = await _petRepo.getAllPets();
    if (!mounted) return;
    setState(() {
      _allPets = pets;
      if (widget.initialPetId != null) {
        _petA = pets.firstWhere((p) => p.id == widget.initialPetId, orElse: () => pets[0]);
        _petB = pets.firstWhere((p) => p.id != _petA?.id, orElse: () => pets[1]);
      } else {
        _petA = pets.isNotEmpty ? pets[0] : null;
        _petB = pets.length > 1 ? pets[1] : null;
      }
      _isLoading = false;
    });
  }

  void _selectPet(bool isSlotA) async {
    final selected = await showModalBottomSheet<Pet>(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: _allPets.length,
          itemBuilder: (context, index) {
            final p = _allPets[index];
            return ListTile(
              leading: CircleAvatar(backgroundImage: AppNetworkImage.provider(p.imageUrl)),
              title: Text('${p.name} (${p.breed})', style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text('${p.matchScore}% Match • ${p.ageDisplay}'),
              onTap: () => Navigator.pop(context, p),
            );
          },
        );
      },
    );

    if (selected != null) {
      setState(() {
        if (isSlotA) {
          _petA = selected;
        } else {
          _petB = selected;
        }
      });
    }
  }

  Widget _buildComparisonRow(String label, String valA, String valB, {bool isHighlight = false}) {
    const slateDark = Color(0xFF0F172A);
    const teal = Color(0xFF0D9488);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
      decoration: BoxDecoration(
        color: isHighlight ? const Color(0xFFF0FDFA) : Colors.transparent,
        border: const Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: Text(
              valA,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isHighlight ? FontWeight.bold : FontWeight.w600,
                color: isHighlight ? teal : slateDark,
              ),
            ),
          ),
          Expanded(
            flex: 4,
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            flex: 4,
            child: Text(
              valB,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isHighlight ? FontWeight.bold : FontWeight.w600,
                color: isHighlight ? teal : slateDark,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCheckRow(String label, bool checkA, bool checkB) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: Icon(
              checkA ? Icons.check_circle_rounded : Icons.cancel_rounded,
              color: checkA ? const Color(0xFF0D9488) : const Color(0xFFCBD5E1),
              size: 20,
            ),
          ),
          Expanded(
            flex: 4,
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            flex: 4,
            child: Icon(
              checkB ? Icons.check_circle_rounded : Icons.cancel_rounded,
              color: checkB ? const Color(0xFF0D9488) : const Color(0xFFCBD5E1),
              size: 20,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const teal = Color(0xFF0D9488);
    const slateDark = Color(0xFF0F172A);

    if (_isLoading || _petA == null || _petB == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: teal)),
      );
    }

    final pA = _petA!;
    final pB = _petB!;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Side-by-Side Comparison'),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Top Pet Selector Cards
            Container(
              color: Colors.white,
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  // Slot A
                  Expanded(
                    child: Column(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: SizedBox(
                            width: 110,
                            height: 110,
                            child: AppNetworkImage(
                              imageUrl: pA.imageUrl,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          pA.name,
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: slateDark),
                        ),
                        Text(
                          pA.breed,
                          style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            minimumSize: Size.zero,
                          ),
                          onPressed: () => _selectPet(true),
                          child: const Text('Switch', style: TextStyle(fontSize: 11)),
                        ),
                      ],
                    ),
                  ),

                  Container(
                    width: 32,
                    height: 32,
                    decoration: const BoxDecoration(
                      color: Color(0xFFF1F5F9),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: const Text('VS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF64748B))),
                  ),

                  // Slot B
                  Expanded(
                    child: Column(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: SizedBox(
                            width: 110,
                            height: 110,
                            child: AppNetworkImage(
                              imageUrl: pB.imageUrl,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          pB.name,
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: slateDark),
                        ),
                        Text(
                          pB.breed,
                          style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            minimumSize: Size.zero,
                          ),
                          onPressed: () => _selectPet(false),
                          child: const Text('Switch', style: TextStyle(fontSize: 11)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Comparison Metrics Card
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                children: [
                  _buildComparisonRow('Compatibility', '${pA.matchScore}%', '${pB.matchScore}%', isHighlight: true),
                  _buildComparisonRow('Species', pA.species, pB.species),
                  _buildComparisonRow('Age', pA.ageDisplay, pB.ageDisplay),
                  _buildComparisonRow('Gender', pA.gender, pB.gender),
                  _buildComparisonRow('Weight', '${pA.weightKg} kg', '${pB.weightKg} kg'),
                  _buildComparisonRow('Distance', '${pA.distanceLabel}', '${pB.distanceLabel}'),
                  _buildCheckRow('Apartment Friendly', pA.isApartmentFriendly, pB.isApartmentFriendly),
                  _buildCheckRow('Good with Children', pA.isKidSafe, pB.isKidSafe),
                  _buildCheckRow('House Trained', pA.isHouseTrained, pB.isHouseTrained),
                  _buildCheckRow('Spayed / Neutered', pA.isNeutered, pB.isNeutered),
                  _buildCheckRow('Core Vaccinated', pA.isVaccinated, pB.isVaccinated),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // 1-Click Apply Buttons
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: teal,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: () => context.push('/apply/${pA.id}'),
                      child: Text('Apply for ${pA.name}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: teal,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: () => context.push('/apply/${pB.id}'),
                      child: Text('Apply for ${pB.name}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

