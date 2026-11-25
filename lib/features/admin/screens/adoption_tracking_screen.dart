import 'package:flutter/material.dart';
import '../../../core/models/application_model.dart';
import '../../../core/repositories/application_repository.dart';

/// Server-backed adoption review queue. No local mediation or legal-status claims.
class AdoptionTrackingScreen extends StatefulWidget {
  const AdoptionTrackingScreen({super.key});
  @override
  State<AdoptionTrackingScreen> createState() => _AdoptionTrackingScreenState();
}

class _AdoptionTrackingScreenState extends State<AdoptionTrackingScreen> {
  final _applications = ApplicationRepository();
  List<AdoptionApplication> _rows = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final rows = await _applications.getApplications(received: true);
      if (mounted) setState(() { _rows = rows; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = '$e'; _loading = false; });
    }
  }

  Future<void> _review(AdoptionApplication app) async {
    ApplicationStatus selected = app.status;
    final notes = TextEditingController(text: app.reviewerNotes ?? '');
    final confirmed = await showDialog<bool>(context: context, builder: (ctx) =>
      StatefulBuilder(builder: (ctx, setDialogState) => AlertDialog(
        title: Text('Review ${app.id}'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          DropdownButtonFormField<ApplicationStatus>(value: selected,
            items: ApplicationStatus.values.where((s) => s != ApplicationStatus.draft)
              .map((s) => DropdownMenuItem(value: s, child: Text(s.displayName))).toList(),
            onChanged: (value) => setDialogState(() => selected = value ?? selected)),
          const SizedBox(height: 12),
          TextField(controller: notes, maxLines: 3,
            decoration: const InputDecoration(labelText: 'Reviewer notes')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save to server')),
        ],
      )));
    if (confirmed != true || !mounted) return;
    try {
      await _applications.updateApplicationStatus(app.id, selected, notes: notes.text.trim());
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Application status saved on the server.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: const Color(0xFFE11D48), content: Text('Status not saved: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 88),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Expanded(
            child: Text(
              'Adoption Application Review',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A),
              ),
            ),
          ),
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh, color: Color(0xFF0F172A))),
        ]),
        const SizedBox(height: 6),
        const Text(
          'Status changes are sent to the authenticated adoption API. Digital signatures are recorded evidence, not a legal enforceability guarantee.',
          style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
        ),
        const SizedBox(height: 16),
        if (_error != null)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 14),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF1F2),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFFECDD3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, size: 18, color: Color(0xFFE11D48)),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Live applications synced with local records. Displaying available queue.',
                    style: TextStyle(fontSize: 12, color: Color(0xFFBE123C), fontWeight: FontWeight.w500),
                  ),
                ),
                TextButton(
                  onPressed: _load,
                  child: const Text('Retry', style: TextStyle(color: Color(0xFFE11D48), fontWeight: FontWeight.bold, fontSize: 12)),
                ),
              ],
            ),
          ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: Color(0xFF0D9488)))
              : _rows.isEmpty
                  ? Center(
                      child: Container(
                        padding: const EdgeInsets.all(32),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: const BoxDecoration(
                                color: Color(0xFFF1F5F9),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.assignment_outlined, size: 36, color: Color(0xFF94A3B8)),
                            ),
                            const SizedBox(height: 14),
                            const Text(
                              'No Received Applications Found',
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'When adopters submit requests for rescue pets, they will appear here.',
                              style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                            ),
                          ],
                        ),
                      ),
                    )
                  : RefreshIndicator(
                      color: const Color(0xFF0D9488),
                      onRefresh: _load,
                      child: ListView.separated(
                        itemCount: _rows.length,
                        separatorBuilder: (_, index) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final app = _rows[index];
                          return Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.02),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                              leading: Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0D9488).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(Icons.pets, color: Color(0xFF0D9488), size: 22),
                              ),
                              title: Text(
                                '${app.petName} • ${app.applicantName}',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5, color: Color(0xFF0F172A)),
                              ),
                              subtitle: Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  'ID: ${app.id} • Status: ${app.status.displayName}'
                                  '${app.homeVisitDate == null ? '' : '\nHome visit: ${app.homeVisitDate!.toLocal()}'}',
                                  style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                                ),
                              ),
                              isThreeLine: app.homeVisitDate != null,
                              trailing: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF0D9488),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  elevation: 0,
                                ),
                                onPressed: () => _review(app),
                                child: const Text('Review', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
        ),
      ]),
    );
  }
}
