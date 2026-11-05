import 'package:flutter/material.dart';
import '../../../core/models/emergency_alert_model.dart';
import '../../../core/repositories/emergency_repository.dart';

class NearbyClinicsScreen extends StatefulWidget {
  const NearbyClinicsScreen({super.key});

  @override
  State<NearbyClinicsScreen> createState() => _NearbyClinicsScreenState();
}

class _NearbyClinicsScreenState extends State<NearbyClinicsScreen> {
  final _emergencyRepo = EmergencyRepository();
  List<VetClinic> _clinics = [];
  bool _isLoading = true;
  bool _emergency24_7Only = false;
  String _selectedArea = 'All Areas';

  final List<String> _areas = ['All Areas', 'Dhanmondi', 'Gulshan', 'Uttara', 'Mirpur'];

  @override
  void initState() {
    super.initState();
    _loadClinics();
  }

  Future<void> _loadClinics() async {
    final list = await _emergencyRepo.getEmergencyClinics();
    if (!mounted) return;
    setState(() {
      _clinics = list;
      _isLoading = false;
    });
  }

  List<VetClinic> get _filteredClinics {
    var result = List<VetClinic>.from(_clinics);
    if (_emergency24_7Only) {
      result = result.where((c) => c.is24Hours).toList();
    }
    if (_selectedArea != 'All Areas') {
      result = result.where((c) => c.address.toLowerCase().contains(_selectedArea.toLowerCase())).toList();
    }
    // Sort by distance ascending
    result.sort((a, b) => a.distanceKm.compareTo(b.distanceKm));
    return result;
  }

  @override
  Widget build(BuildContext context) {
    const teal = Color(0xFF0D9488);
    const slateDark = Color(0xFF0F172A);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Nearby Vet Clinics & Shelters'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: teal))
          : Column(
              children: [
                // Top Filter Controls Card
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: const [
                              Icon(Icons.local_hospital_rounded, color: Color(0xFFE11D48), size: 20),
                              SizedBox(width: 8),
                              Text(
                                '24/7 Emergency Care Only',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: slateDark),
                              ),
                            ],
                          ),
                          Switch(
                            value: _emergency24_7Only,
                            activeColor: const Color(0xFFE11D48),
                            onChanged: (val) => setState(() => _emergency24_7Only = val),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      SizedBox(
                        height: 36,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: _areas.length,
                          separatorBuilder: (context, index) => const SizedBox(width: 8),
                          itemBuilder: (context, index) {
                            final area = _areas[index];
                            final isSelected = _selectedArea == area;
                            return ChoiceChip(
                              label: Text(area),
                              selected: isSelected,
                              selectedColor: const Color(0xFFCCFBF1),
                              labelStyle: TextStyle(
                                fontSize: 12,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                color: isSelected ? teal : const Color(0xFF475569),
                              ),
                              onSelected: (val) {
                                if (val) setState(() => _selectedArea = area);
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),

                // Clinic List View
                Expanded(
                  child: _filteredClinics.isEmpty
                      ? const Center(
                          child: Text('No clinics found matching criteria.'),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: _filteredClinics.length,
                          separatorBuilder: (context, index) => const SizedBox(height: 14),
                          itemBuilder: (context, index) {
                            final clinic = _filteredClinics[index];

                            return Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.02),
                                    blurRadius: 8,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: clinic.is24Hours
                                              ? const Color(0xFFFFE4E6)
                                              : const Color(0xFFCCFBF1),
                                          borderRadius: BorderRadius.circular(14),
                                        ),
                                        child: Icon(
                                          clinic.is24Hours ? Icons.emergency : Icons.medical_services,
                                          color: clinic.is24Hours
                                              ? const Color(0xFFE11D48)
                                              : teal,
                                          size: 22,
                                        ),
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              clinic.name,
                                              style: const TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w800,
                                                color: slateDark,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              clinic.address,
                                              style: const TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF1F5F9),
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: Row(
                                          children: [
                                            const Icon(Icons.near_me, size: 12, color: teal),
                                            const SizedBox(width: 3),
                                            Text(
                                              '${clinic.distanceKm} km',
                                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: teal),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const Divider(height: 20),
                                  Row(
                                    children: [
                                      const Icon(Icons.phone_rounded, size: 15, color: teal),
                                      const SizedBox(width: 6),
                                      Text(
                                        clinic.phone,
                                        style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: slateDark),
                                      ),
                                      const Spacer(),
                                      if (clinic.is24Hours)
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFFFE4E6),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: const Text(
                                            '24/7 OPEN',
                                            style: TextStyle(color: Color(0xFFE11D48), fontSize: 10, fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                      const SizedBox(width: 8),
                                      ElevatedButton.icon(
                                        icon: const Icon(Icons.call, size: 14),
                                        label: const Text('Call', style: TextStyle(fontSize: 12)),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: teal,
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                          minimumSize: Size.zero,
                                        ),
                                        onPressed: () {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(content: Text('Dialing ${clinic.name} (${clinic.phone})...')),
                                          );
                                        },
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}

