import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../core/models/pet_model.dart';
import '../../../core/repositories/pet_repository.dart';
import '../../../core/widgets/adoptmatch_back_button.dart';

class HealthPassportScreen extends StatefulWidget {
  final String petId;
  final String? petName;
  final String? qrPayload;

  const HealthPassportScreen({
    super.key,
    this.petId = 'p1',
    this.petName,
    this.qrPayload,
  });

  @override
  State<HealthPassportScreen> createState() => _HealthPassportScreenState();
}

class _HealthPassportScreenState extends State<HealthPassportScreen> {
  final _petRepo = PetRepository();
  Pet? _pet;
  bool _remindersEnabled = true;

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
    });
  }

  void _showScannedProfileModal(String payload, String name) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: const [
                    Icon(Icons.verified, color: Color(0xFF0D9488), size: 24),
                    SizedBox(width: 8),
                    Text(
                      'AdoptMatch Emergency Tag Verified',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  'Scanned Tag: $payload',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                    fontFamily: 'monospace',
                  ),
                ),
                const Divider(height: 24),
                Text(
                  'Pet: $name',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const Text('Registered Owner: Elias Ahmed'),
                const Text('Emergency Contact: +880 1711 234567'),
                const Text(
                  'Allergies: None known (Diet: Standard Hypoallergenic)',
                ),
                const Text(
                  'Primary Hospital: Central Veterinary Hospital, Farmgate',
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.phone, color: Colors.white),
                    label: const Text(
                      'Call Owner (Masked Proxy)',
                      style: TextStyle(color: Colors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0D9488),
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    const teal = Color(0xFF0D9488);
    const slateDark = Color(0xFF0F172A);

    final petName = widget.petName ?? _pet?.name ?? 'Luna';
    final payload =
        widget.qrPayload ?? _pet?.qrHash ?? 'ADOPT-PET-PASSPORT-BD-2026-X88';

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        leading: AdoptMatchBackButton(
          fallbackPath: widget.petId.isNotEmpty ? '/pets/${widget.petId}' : '/home',
        ),
        title: Text('$petName’s Health Passport'),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Collar QR tag link copied to clipboard.'),
                ),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Official Encrypted QR Collar Tag Card
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: QrImageView(
                        data: payload,
                        version: QrVersions.auto,
                        size: 180,
                        backgroundColor: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Scan for Emergency Vet & Owner ID',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        color: slateDark,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Official AdoptMatch Verified Record • Offline Cached',
                      style: TextStyle(color: Color(0xFF64748B), fontSize: 12),
                    ),
                    const SizedBox(height: 14),
                    OutlinedButton.icon(
                      icon: const Icon(
                        Icons.camera_alt_outlined,
                        size: 16,
                        color: teal,
                      ),
                      label: const Text(
                        'Simulate Collar Scan',
                        style: TextStyle(color: teal, fontSize: 13),
                      ),
                      onPressed: () =>
                          _showScannedProfileModal(payload, petName),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Smart Push Reminders Switcher
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.notifications_active_outlined, color: teal),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          'Vaccine & Booster Reminders',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: slateDark,
                          ),
                        ),
                        Text(
                          'Automated push alerts before due dates',
                          style: TextStyle(
                            fontSize: 11,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: _remindersEnabled,
                    activeColor: teal,
                    onChanged: (val) {
                      setState(() => _remindersEnabled = val);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            val
                                ? 'Booster alerts activated'
                                : 'Reminders muted',
                          ),
                          duration: const Duration(seconds: 1),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Vaccine Timeline Entries
            _buildVaccineItem(
              title: 'Rabies Booster Due',
              subtitle: 'Next Date: Nov 15, 2026 (Central Vet Hospital)',
              status: 'Scheduled',
              statusColor: const Color(0xFF0D9488),
              statusBg: const Color(0xFFE6FFFA),
              icon: Icons.vaccines,
            ),
            const SizedBox(height: 10),
            _buildVaccineItem(
              title: 'DHPP Core Vaccines (Series 3)',
              subtitle: 'Administered: Dec 12, 2025 • Dr. Rafiqul Islam',
              status: 'Completed',
              statusColor: const Color(0xFF2563EB),
              statusBg: const Color(0xFFEFF6FF),
              icon: Icons.check_circle_outline,
            ),
            const SizedBox(height: 10),
            _buildVaccineItem(
              title: 'Quarterly Deworming (Broad Spectrum)',
              subtitle: 'Administered: Jan 10, 2026 • Care For Paws',
              status: 'Completed',
              statusColor: const Color(0xFF2563EB),
              statusBg: const Color(0xFFEFF6FF),
              icon: Icons.medication_outlined,
            ),
            const SizedBox(height: 10),
            _buildVaccineItem(
              title: 'Microchip Registry Tag',
              subtitle: 'ID #BD-9821-4401 (National Pet Registry)',
              status: 'Active',
              statusColor: const Color(0xFF059669),
              statusBg: const Color(0xFFECFDF5),
              icon: Icons.tag,
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildVaccineItem({
    required String title,
    required String subtitle,
    required String status,
    required Color statusColor,
    required Color statusBg,
    required IconData icon,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: statusColor, size: 22),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 14,
            color: Color(0xFF0F172A),
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4.0),
          child: Text(
            subtitle,
            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
          ),
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: statusBg,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            status,
            style: TextStyle(
              color: statusColor,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}
