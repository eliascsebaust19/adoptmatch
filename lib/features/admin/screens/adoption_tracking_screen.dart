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
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Application status saved on the server.')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(backgroundColor: const Color(0xFFE11D48), content: Text('Status not saved: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Expanded(child: Text('Adoption Application Review',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800))),
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
        ]),
        const SizedBox(height: 8),
        const Text('Status changes are sent to the authenticated adoption API. '
          'Digital signatures are recorded evidence, not a legal enforceability guarantee.',
          style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
        const SizedBox(height: 16),
        if (_error != null) Padding(padding: const EdgeInsets.only(bottom: 12),
          child: Text(_error!, style: const TextStyle(color: Color(0xFFE11D48)))),
        Expanded(child: _loading ? const Center(child: CircularProgressIndicator())
          : _rows.isEmpty ? const Center(child: Text('No received applications found.'))
          : RefreshIndicator(onRefresh: _load, child: ListView.separated(
              itemCount: _rows.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final app = _rows[index];
                return Card(child: ListTile(
                  title: Text('${app.petName} • ${app.applicantName}',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('${app.id}\nStatus: ${app.status.displayName}'
                    '${app.homeVisitDate == null ? '' : '\nHome visit: ${app.homeVisitDate!.toLocal()}'}'),
                  isThreeLine: true,
                  trailing: ElevatedButton(onPressed: () => _review(app), child: const Text('Review')),
                ));
              }))),
      ]),
    );
  }
}
