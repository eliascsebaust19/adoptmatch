import 'package:flutter/material.dart';

import '../../../core/models/emergency_alert_model.dart';
import '../../../core/repositories/emergency_repository.dart';
import '../../../shared/widgets/custom_button.dart';
import '../../../shared/widgets/app_network_image.dart';

class EmergencySosScreen extends StatefulWidget {
  const EmergencySosScreen({super.key});

  @override
  State<EmergencySosScreen> createState() => _EmergencySosScreenState();
}

class _EmergencySosScreenState extends State<EmergencySosScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _emergencyRepo = EmergencyRepository();

  List<EmergencyAlert> _alerts = [];
  List<VetClinic> _clinics = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  Future<void> _loadData() async {
    final alerts = await _emergencyRepo.getActiveAlerts();
    final clinics = await _emergencyRepo.getEmergencyClinics();
    if (!mounted) return;
    setState(() {
      _alerts = alerts;
      _clinics = clinics;
      _isLoading = false;
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _openBroadcastDialog() {
    final nameCtrl = TextEditingController();
    final breedCtrl = TextEditingController();
    final locationCtrl = TextEditingController(text: 'Dhanmondi, Dhaka');
    final rewardCtrl = TextEditingController(text: '5000');
    final descCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: const [
                    Icon(
                      Icons.warning_amber_rounded,
                      color: Color(0xFFE11D48),
                      size: 28,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Broadcast 5km SOS Alert',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'SOS broadcasting requires a configured emergency backend. No alert is sent until the server confirms it.',
                  style: TextStyle(color: Colors.grey, fontSize: 13),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Pet Name',
                    hintText: 'e.g. Bruno',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: breedCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Breed / Species',
                    hintText: 'e.g. Golden Retriever',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: locationCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Last Seen Location',
                    hintText: 'Road, Area, Landmark',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: rewardCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Reward (BDT)',
                    hintText: '5000',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Collar details, markings, temperament',
                  ),
                ),
                const SizedBox(height: 20),
                CustomButton(
                  text: 'Broadcast High-Priority Alert',
                  backgroundColor: const Color(0xFFE11D48),
                  onPressed: () async {
                    if (nameCtrl.text.isNotEmpty) {
                      try {
                      await _emergencyRepo.broadcastAlert(
                        petName: nameCtrl.text.trim(),
                        petBreed: breedCtrl.text.trim().isNotEmpty
                            ? breedCtrl.text.trim()
                            : 'Dog',
                        imageUrl: 'https://images.unsplash.com/photo-1558788353-f76d92427f16?auto=format&fit=crop&w=800&q=80',
                        lastSeenLocation: locationCtrl.text.trim(),
                        lat: 23.75,
                        lng: 90.38,
                        radiusKm: 5,
                        rewardBdt: int.tryParse(rewardCtrl.text) ?? 5000,
                        description: descCtrl.text.trim(),
                        contactPhone: '+880 17•• ••••22',
                      );
                      if (!context.mounted) return;
                      Navigator.pop(context);
                      await _loadData();
                      } catch (e) {
                        if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(backgroundColor: const Color(0xFFE11D48), content: Text('$e')));
                      }
                    }
                  },
                ),
              ],
            ),
          ),
        );
      },
    ).whenComplete(() {
      nameCtrl.dispose();
      breedCtrl.dispose();
      locationCtrl.dispose();
      rewardCtrl.dispose();
      descCtrl.dispose();
    });
  }

  @override
  Widget build(BuildContext context) {
    const teal = Color(0xFF0D9488);
    const rose = Color(0xFFE11D48);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('24/7 Emergency & SOS'),
        bottom: TabBar(
          controller: _tabController,
          labelColor: teal,
          indicatorColor: teal,
          tabs: const [
            Tab(text: 'Lost Pet Alerts (5km)'),
            Tab(text: '24/7 Vet Clinics'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: rose,
        icon: const Icon(Icons.campaign, color: Colors.white),
        label: const Text(
          'Report Lost Pet',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        onPressed: _openBroadcastDialog,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: teal))
          : TabBarView(
              controller: _tabController,
              children: [
                // Tab 1: Active Lost Pet Alerts
                RefreshIndicator(
                  onRefresh: _loadData,
                  color: teal,
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                    itemCount: _alerts.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 14),
                    itemBuilder: (context, index) {
                      final alert = _alerts[index];
                      return _LostPetAlertCard(alert: alert);
                    },
                  ),
                ),

                // Tab 2: 24/7 Emergency Vet Clinics
                ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                  itemCount: _clinics.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 14),
                  itemBuilder: (context, index) {
                    final clinic = _clinics[index];
                    return _VetClinicCard(clinic: clinic);
                  },
                ),
              ],
            ),
    );
  }
}

class _LostPetAlertCard extends StatelessWidget {
  final EmergencyAlert alert;

  const _LostPetAlertCard({required this.alert});

  @override
  Widget build(BuildContext context) {
    const rose = Color(0xFFE11D48);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: rose.withOpacity(0.3), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: rose.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: rose,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.radar, color: Colors.white, size: 14),
                    SizedBox(width: 4),
                    Text(
                      '5KM BROADCAST ACTIVE',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Text(
                'Reward: ৳${alert.rewardBdt}',
                style: const TextStyle(
                  color: Color(0xFF059669),
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: 72,
                  height: 72,
                  child: AppNetworkImage(
                    imageUrl: alert.imageUrl,
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
                      alert.petName,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    Text(
                      alert.petBreed,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.location_on, size: 14, color: rose),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            alert.lastSeenLocation,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF334155),
                              fontWeight: FontWeight.w500,
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
          const SizedBox(height: 10),
          Text(
            alert.description,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF475569),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),

          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              OutlinedButton.icon(
                icon: const Icon(Icons.map_outlined, size: 16),
                label: const Text(
                  'Open in Maps',
                  style: TextStyle(fontSize: 12),
                ),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Opening coordinates ${alert.lat}, ${alert.lng} in Maps...',
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                icon: const Icon(Icons.call, size: 16, color: Colors.white),
                label: const Text(
                  'Call Owner (Masked)',
                  style: TextStyle(color: Colors.white, fontSize: 12),
                ),
                style: ElevatedButton.styleFrom(backgroundColor: rose),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Connecting via secure masked proxy to ${alert.contactPhone}...',
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _VetClinicCard extends StatelessWidget {
  final VetClinic clinic;

  const _VetClinicCard({required this.clinic});

  @override
  Widget build(BuildContext context) {
    const teal = Color(0xFF0D9488);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
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
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFDCFCE7),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.schedule, size: 12, color: Color(0xFF15803D)),
                    SizedBox(width: 4),
                    Text(
                      'OPEN 24/7',
                      style: TextStyle(
                        color: Color(0xFF15803D),
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Text(
                '${clinic.distanceKm} km away',
                style: const TextStyle(
                  color: Color(0xFF64748B),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            clinic.name,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            clinic.address,
            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 6),
          Text(
            'Services: ${clinic.services}',
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF334155),
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.call, size: 18, color: Colors.white),
              label: Text(
                'Emergency Hotline: ${clinic.phone}',
                style: const TextStyle(color: Colors.white, fontSize: 13),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: teal,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Dialing ${clinic.phone}...')),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
