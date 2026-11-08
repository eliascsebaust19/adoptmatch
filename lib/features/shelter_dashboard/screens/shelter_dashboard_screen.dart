import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/models/application_model.dart';
import '../../../core/models/pet_model.dart';
import '../../../core/repositories/application_repository.dart';
import '../../../core/services/laravel_pet_service.dart';
import '../../../core/services/storage_service.dart';
import '../../../shared/widgets/shared_widgets.dart';
import '../../auth/bloc/auth_bloc.dart';

/// Shelter desk backed by received applications and the owner's Laravel listings.
class ShelterDashboardScreen extends StatefulWidget {
  const ShelterDashboardScreen({super.key});
  @override
  State<ShelterDashboardScreen> createState() => _ShelterDashboardScreenState();
}

class _ShelterDashboardScreenState extends State<ShelterDashboardScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 4, vsync: this);
  final _applications = ApplicationRepository();
  final _petsApi = LaravelPetService();
  final _email = TextEditingController();
  final _password = TextEditingController();

  List<AdoptionApplication> _apps = [];
  List<Pet> _pets = [];
  bool _loading = true;
  bool _verifying = false;
  String? _error;

  bool _authorized(UserRole role) => role.isShelter || role.isAdmin;

  @override
  void initState() {
    super.initState();
    final state = context.read<AuthBloc>().state;
    if (state is Authenticated && _authorized(state.user.role)) {
      _load();
    } else {
      _loading = false;
    }
  }

  @override
  void dispose() {
    _tabs.dispose(); _email.dispose(); _password.dispose(); super.dispose();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final apps = await _applications.getApplications(received: true);
      final pets = await _petsApi.getMyPets();
      if (mounted) setState(() { _apps = apps; _pets = pets; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = '$e'; _loading = false; });
    }
  }

  void _unlock() {
    if (_email.text.trim().isEmpty || _password.text.trim().isEmpty) {
      setState(() => _error = 'Enter your shelter account email and password.');
      return;
    }
    setState(() { _verifying = true; _error = null; });
    context.read<AuthBloc>().add(AdminLoginWithEmailEvent(_email.text.trim(), _password.text.trim()));
  }

  Future<void> _review(AdoptionApplication app) async {
    var selected = app.status;
    final notes = TextEditingController(text: app.reviewerNotes ?? '');
    final ok = await showDialog<bool>(context: context, builder: (ctx) =>
      StatefulBuilder(builder: (ctx, setDialog) => AlertDialog(
        title: Text('Review ${app.id}'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          DropdownButtonFormField<ApplicationStatus>(value: selected,
            items: ApplicationStatus.values.where((s) => s != ApplicationStatus.draft)
              .map((s) => DropdownMenuItem(value: s, child: Text(s.displayName))).toList(),
            onChanged: (v) => setDialog(() => selected = v ?? selected)),
          TextField(controller: notes, maxLines: 3,
            decoration: const InputDecoration(labelText: 'Reviewer notes')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save to server')),
        ],
      )));
    if (ok != true || !mounted) return;
    try {
      await _applications.updateApplicationStatus(app.id, selected, notes: notes.text.trim());
      await _load();
    } catch (e) { _showError('Status not saved: $e'); }
  }

  void _showError(String message) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(backgroundColor: const Color(0xFFE11D48), content: Text(message)));
  }

  Future<void> _petStatus(Pet pet, String status) async {
    try { await _petsApi.updatePetStatus(pet.id, status); await _load(); }
    catch (e) { _showError('Listing not updated: $e'); }
  }

  Future<void> _deletePet(Pet pet) async {
    final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: Text('Delete ${pet.name}?'),
      content: const Text('This removes the listing from the server.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
      ]));
    if (ok != true) return;
    try { await _petsApi.deletePet(pet.id); await _load(); }
    catch (e) { _showError('Listing not deleted: $e'); }
  }

  Future<void> _addPet() async {
    final name = TextEditingController(), breed = TextEditingController();
    final age = TextEditingController(text: '12'), description = TextEditingController();
    var species = 'dog', gender = 'unknown', size = 'medium';
    String? imageUrl; var uploading = false;
    final ok = await showDialog<bool>(context: context, builder: (ctx) =>
      StatefulBuilder(builder: (ctx, setDialog) => AlertDialog(
        title: const Text('New server listing'),
        content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: name, decoration: const InputDecoration(labelText: 'Name')),
          TextField(controller: breed, decoration: const InputDecoration(labelText: 'Breed')),
          DropdownButtonFormField<String>(value: species,
            items: const ['dog', 'cat', 'bird', 'rabbit', 'other'].map((s) =>
              DropdownMenuItem(value: s, child: Text(s))).toList(),
            onChanged: (v) => setDialog(() => species = v ?? species)),
          TextField(controller: age, keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Age in months')),
          DropdownButtonFormField<String>(value: gender,
            items: const ['unknown', 'male', 'female'].map((s) =>
              DropdownMenuItem(value: s, child: Text(s))).toList(),
            onChanged: (v) => setDialog(() => gender = v ?? gender)),
          DropdownButtonFormField<String>(value: size,
            items: const ['small', 'medium', 'large', 'giant'].map((s) =>
              DropdownMenuItem(value: s, child: Text(s))).toList(),
            onChanged: (v) => setDialog(() => size = v ?? size)),
          TextField(controller: description, maxLines: 3,
            decoration: const InputDecoration(labelText: 'Description')),
          const SizedBox(height: 8),
          OutlinedButton.icon(onPressed: uploading ? null : () async {
            setDialog(() => uploading = true);
            try {
              final file = await StorageService.pickImageFromGallery();
              if (file != null) {
                final url = await StorageService.uploadPetImage(
                  bytes: await file.readAsBytes(), fileName: file.name);
                setDialog(() => imageUrl = url);
              }
            } catch (e) { _showError('Photo upload failed: $e'); }
            finally { setDialog(() => uploading = false); }
          }, icon: const Icon(Icons.photo), label: Text(imageUrl == null ? 'Upload photo' : 'Photo uploaded')),
        ])),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: uploading ? null : () {
            if (name.text.trim().isEmpty || breed.text.trim().isEmpty ||
                description.text.trim().isEmpty || imageUrl == null ||
                int.tryParse(age.text) == null) {
              _showError('Name, breed, age, description and an uploaded photo are required.');
              return;
            }
            Navigator.pop(ctx, true);
          }, child: const Text('Create')),
        ],
      )));
    if (ok != true || !mounted) return;
    try {
      await _petsApi.createPet({'name': name.text.trim(), 'species': species,
        'breed': breed.text.trim(), 'age_months': int.parse(age.text), 'gender': gender,
        'size': size, 'vaccination_status': 'unknown', 'is_spayed_neutered': false,
        'description': description.text.trim(), 'adoption_fee': 0, 'images': [imageUrl]});
      await _load();
    } catch (e) { _showError('Listing not created: $e'); }
  }

  Widget _lockScreen() => Scaffold(
    appBar: AppBar(title: const Text('Shelter Desk'),
      leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.go('/home'))),
    body: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 420),
      child: Card(child: Padding(padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Sign in with a server-verified shelter or admin account.',
            textAlign: TextAlign.center),
          const SizedBox(height: 16),
          TextField(controller: _email, keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(labelText: 'Email')),
          const SizedBox(height: 12),
          TextField(controller: _password, obscureText: true,
            decoration: const InputDecoration(labelText: 'Password'), onSubmitted: (_) => _unlock()),
          if (_error != null) Padding(padding: const EdgeInsets.only(top: 12),
            child: Text(_error!, style: const TextStyle(color: Color(0xFFE11D48)))),
          const SizedBox(height: 16),
          ElevatedButton(onPressed: _verifying ? null : _unlock,
            child: _verifying ? const SizedBox(width: 18, height: 18,
              child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Verify & Enter')),
        ]))))),
  );

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AuthBloc>().state;
    final unlocked = state is Authenticated && _authorized(state.user.role);
    if (!unlocked) {
      return BlocListener<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state is Authenticated && _authorized(state.user.role)) { _load(); }
          else if (state is AuthFailure) setState(() { _verifying = false; _error = state.errorMessage; });
          else if (state is AuthLoading) setState(() => _verifying = true);
        }, child: _lockScreen());
    }
    final visits = _apps.where((a) => a.status == ApplicationStatus.homeVisitScheduled ||
      a.status == ApplicationStatus.fosterTrial || a.homeVisitDate != null).toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Shelter Management'), actions: [
        IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
        IconButton(onPressed: _addPet, icon: const Icon(Icons.add)),
      ], bottom: TabBar(controller: _tabs, tabs: [
        Tab(text: 'Apps (${_apps.length})'), Tab(text: 'Pets (${_pets.length})'),
        Tab(text: 'Visits (${visits.length})'), const Tab(text: 'Analytics'),
      ])),
      body: _loading ? const Center(child: CircularProgressIndicator())
        : _error != null ? Center(child: Padding(padding: const EdgeInsets.all(24),
            child: Text(_error!, style: const TextStyle(color: Color(0xFFE11D48)))))
        : TabBarView(controller: _tabs, children: [
            _appList(_apps),
            ListView.separated(padding: const EdgeInsets.all(16), itemCount: _pets.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, i) { final pet = _pets[i]; return Card(child: ListTile(
                leading: SizedBox(width: 48, height: 48, child: AppNetworkImage(imageUrl: pet.imageUrl, fit: BoxFit.cover)),
                title: Text(pet.name), subtitle: Text('${pet.breed} • ${pet.adoptionStatus}'),
                trailing: PopupMenuButton<String>(onSelected: (v) {
                  if (v == 'delete') { _deletePet(pet); }
                  else { _petStatus(pet, v); }
                }, itemBuilder: (_) => [
                  const PopupMenuItem(value: 'available', child: Text('Mark available')),
                  const PopupMenuItem(value: 'adopted', child: Text('Mark adopted')),
                  const PopupMenuItem(value: 'delete', child: Text('Delete')),
                ]),
              )); }),
            _appList(visits),
            ListView(padding: const EdgeInsets.all(24), children: [
              _metric('Received applications', _apps.length),
              _metric('Awaiting review', _apps.where((a) => a.status == ApplicationStatus.submitted ||
                a.status == ApplicationStatus.underReview).length),
              _metric('Approved', _apps.where((a) => a.status == ApplicationStatus.approved).length),
              _metric('Available listings', _pets.where((p) => p.adoptionStatus == 'available').length),
              const SizedBox(height: 12),
              const Text('Revenue and device-broadcast metrics are not measured by this API.',
                style: TextStyle(color: Color(0xFF64748B))),
            ]),
          ]),
    );
  }

  Widget _metric(String label, int value) => Card(child: ListTile(
    title: Text(label), trailing: Text('$value', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold))));

  Widget _appList(List<AdoptionApplication> apps) => apps.isEmpty
    ? const Center(child: Text('No server applications in this queue.'))
    : ListView.separated(padding: const EdgeInsets.all(16), itemCount: apps.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, i) { final app = apps[i]; return Card(child: ListTile(
          title: Text('${app.petName} • ${app.applicantName}'),
          subtitle: Text('${app.id}\n${app.status.displayName}'
            '${app.homeVisitDate == null ? '' : '\nVisit: ${app.homeVisitDate!.toLocal()}'}'),
          isThreeLine: true,
          trailing: ElevatedButton(onPressed: () => _review(app), child: const Text('Review')),
        )); });
}
