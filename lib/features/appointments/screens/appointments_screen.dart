import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/models/appointment_model.dart';
import '../../../core/repositories/appointment_repository.dart';
import '../../../core/widgets/adoptmatch_back_button.dart';
import '../../../shared/widgets/shared_widgets.dart';

class AppointmentsScreen extends StatefulWidget {
  const AppointmentsScreen({super.key});

  @override
  State<AppointmentsScreen> createState() => _AppointmentsScreenState();
}

class _AppointmentsScreenState extends State<AppointmentsScreen> {
  final _aptRepo = AppointmentRepository();
  StreamSubscription? _aptSub;
  List<AdoptionAppointment> _appointments = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
    _aptSub = _aptRepo.appointmentsStream.listen((list) {
      if (mounted) setState(() => _appointments = list);
    });
  }

  @override
  void dispose() {
    _aptSub?.cancel();
    super.dispose();
  }

  Future<void> _loadData() async {
    final list = await _aptRepo.getAppointments();
    if (mounted) {
      setState(() {
        _appointments = list;
        _isLoading = false;
      });
    }
  }

  Color _getStatusColor(AppointmentStatus status) {
    switch (status) {
      case AppointmentStatus.confirmed:
        return const Color(0xFF0D9488); // Teal
      case AppointmentStatus.pending:
        return const Color(0xFFD97706); // Amber
      case AppointmentStatus.completed:
        return const Color(0xFF4F46E5); // Indigo
      case AppointmentStatus.cancelled:
        return const Color(0xFFE11D48); // Rose
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
        title: const Text('My Scheduled Visits'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: teal))
          : _appointments.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.calendar_today_outlined, size: 64, color: Colors.grey.shade400),
                      const SizedBox(height: 16),
                      const Text(
                        'No appointments scheduled',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: slateDark),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'View a pet profile to schedule a visit or meet & greet.',
                        style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: teal,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () => context.go('/home'),
                        child: const Text('Discover Pets', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _appointments.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 16),
                  itemBuilder: (context, index) {
                    final apt = _appointments[index];
                    final statusColor = _getStatusColor(apt.status);

                    return Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.02),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(14),
                                child: SizedBox(
                                  width: 52,
                                  height: 52,
                                  child: AppNetworkImage(
                                    imageUrl: apt.petImageUrl,
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
                                      apt.type.displayName,
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w800,
                                        color: slateDark,
                                      ),
                                    ),
                                    Text(
                                      'With ${apt.petName} • ${apt.shelterName}',
                                      style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: statusColor.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  apt.status.displayName,
                                  style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: statusColor),
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 24),
                          Row(
                            children: [
                              const Icon(Icons.calendar_month, size: 16, color: teal),
                              const SizedBox(width: 8),
                              Text(
                                '${apt.date.day}/${apt.date.month}/${apt.date.year}',
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: slateDark),
                              ),
                              const SizedBox(width: 16),
                              const Icon(Icons.schedule, size: 16, color: teal),
                              const SizedBox(width: 8),
                              Text(
                                apt.timeSlot,
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: slateDark),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(Icons.location_on_outlined, size: 16, color: Color(0xFF64748B)),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  apt.shelterAddress,
                                  style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                                ),
                              ),
                            ],
                          ),
                          if (apt.notes.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              child: Text(
                                'Note: ${apt.notes}',
                                style: const TextStyle(fontSize: 11.5, color: Color(0xFF475569)),
                              ),
                            ),
                          ],
                          const SizedBox(height: 14),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              if (apt.status != AppointmentStatus.cancelled && apt.status != AppointmentStatus.completed)
                                TextButton(
                                  onPressed: () async {
                                    final confirm = await showDialog<bool>(
                                      context: context,
                                      builder: (context) => AlertDialog(
                                        title: const Text('Cancel Appointment?'),
                                        content: const Text('Are you sure you want to cancel this scheduled visit?'),
                                        actions: [
                                          TextButton(
                                            onPressed: () => Navigator.pop(context, false),
                                            child: const Text('No, Keep'),
                                          ),
                                          TextButton(
                                            onPressed: () => Navigator.pop(context, true),
                                            child: const Text('Yes, Cancel', style: TextStyle(color: Colors.red)),
                                          ),
                                        ],
                                      ),
                                    );
                                    if (confirm == true) {
                                      await _aptRepo.updateAppointmentStatus(apt.id, AppointmentStatus.cancelled);
                                    }
                                  },
                                  child: const Text('Cancel Visit', style: TextStyle(color: Color(0xFFE11D48), fontSize: 13)),
                                ),
                              const SizedBox(width: 8),
                              OutlinedButton.icon(
                                icon: const Icon(Icons.pets, size: 15, color: teal),
                                label: const Text('View Pet', style: TextStyle(color: teal, fontSize: 13)),
                                onPressed: () => context.push('/pets/${apt.petId}'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}

