import 'package:flutter/material.dart';
import '../../../core/models/pet_model.dart';
import '../../../core/repositories/admin_repository.dart';
import '../../../shared/widgets/app_network_image.dart';
import '../widgets/admin_create_pet_dialog.dart';

class PetModerationScreen extends StatefulWidget {
  const PetModerationScreen({super.key});

  @override
  State<PetModerationScreen> createState() => _PetModerationScreenState();
}

class _PetModerationScreenState extends State<PetModerationScreen> {
  final _adminRepo = AdminRepository();

  String _searchQuery = '';
  String? _adminError;
  @override
  void initState() {
    super.initState();
    _loadAdminData();
  }
  Future<void> _loadAdminData() async {
    try { await _adminRepo.refresh(); if (mounted) setState(() => _adminError = null); }
    catch (e) { if (mounted) setState(() => _adminError = 'Could not load server data: $e'); }
  }
  Future<void> _runAdminAction(Future<void> action, String success) async {
    try {
      await action;
      if (!mounted) return;
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(_adminRepo.lastSyncError ?? success)));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: const Color(0xFFE11D48), content: Text('Action not saved: $e')));
    }
  }

  String _selectedFilter = 'ALL'; // ALL, FLAGGED, DOG, CAT

  void _confirmBanListing(String petId, String petName) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Ban Listing: $petName'),
        content: Text(
          'Are you sure you want to ban "$petName" from public discovery? It will be immediately hidden from consumer feeds and swipe matching.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE11D48),
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(ctx);
              _runAdminAction(_adminRepo.banPetListing(petId), 'Pet "$petName" banned.');
            },
            child: const Text('Confirm Ban'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteListing(Pet pet) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Delete Listing: ${pet.name}'),
        content: Text(
          'Are you sure you want to permanently delete the profile of "${pet.name}"? This action cannot be undone.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              await _runAdminAction(_adminRepo.deletePetListing(pet.id), 'Listing "${pet.name}" deleted.');
            },
            child: const Text('Delete Permanently'),
          ),
        ],
      ),
    );
  }

  /// Opens the Comprehensive Admin Pet Listing Creator & Anytime Override Dialog
  void _showCreateOrEditPetDialog([Pet? existingPet]) {
    showAdminCreatePetDialog(
      context,
      existingPet: existingPet,
      onSaved: (_) => setState(() {}),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Moderation uses the authoritative admin catalog, not local demo pets.
    final allPets = _adminRepo.getPets();
    final flaggedPets = _adminRepo.getFlaggedPets();

    List<Pet> displayedPets = allPets.where((pet) {
      if (_selectedFilter == 'DOG' && pet.species.toLowerCase() != 'dog') return false;
      if (_selectedFilter == 'CAT' && pet.species.toLowerCase() != 'cat') return false;
      if (_selectedFilter == 'FLAGGED') {
        final isFlagged = flaggedPets.any((f) => f.id == pet.id && !f.isBanned);
        if (!isFlagged) return false;
      }
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        return pet.name.toLowerCase().contains(q) ||
            pet.breed.toLowerCase().contains(q) ||
            pet.shelterName.toLowerCase().contains(q);
      }
      return true;
    }).toList();

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_adminError != null) Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(children: [Expanded(child: Text(_adminError!,
              style: const TextStyle(color: Color(0xFFE11D48)))),
              TextButton(onPressed: _loadAdminData, child: const Text('Retry'))]),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'Pet Listings: Anytime CRUD, Image Override & Moderation',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Full admin control: create pet listings, replace multi-image carousels, and override medical history anytime.',
                    style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                  ),
                ],
              ),
              Row(
                children: [
                  SizedBox(
                    width: 240,
                    height: 38,
                    child: TextField(
                      onChanged: (val) => setState(() => _searchQuery = val.trim()),
                      style: const TextStyle(fontSize: 12),
                      decoration: InputDecoration(
                        hintText: 'Search pets, breeds...',
                        hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                        prefixIcon: const Icon(Icons.search, size: 16, color: Color(0xFF94A3B8)),
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(vertical: 0),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0D9488),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: const Icon(Icons.add_circle_outline_rounded, size: 16),
                      label: const Text('Add Rescue Pet / পোষ্য যোগ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      onPressed: () => _showCreateOrEditPetDialog(null),
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Filter bar
          Row(
            children: [
              _buildFilterChip('ALL', 'All Listings (${allPets.length})'),
              const SizedBox(width: 8),
              _buildFilterChip('FLAGGED', 'Flagged Queue (${flaggedPets.where((p) => !p.isBanned).length})'),
              const SizedBox(width: 8),
              _buildFilterChip('DOG', 'Dogs Only'),
              const SizedBox(width: 8),
              _buildFilterChip('CAT', 'Cats Only'),
            ],
          ),
          const SizedBox(height: 16),

          Expanded(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 3)),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: SingleChildScrollView(
                  scrollDirection: Axis.vertical,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minWidth: 1100),
                      child: DataTable(
                        headingRowColor: MaterialStateProperty.all(const Color(0xFFF8FAFC)),
                        horizontalMargin: 18,
                        columnSpacing: 20,
                        columns: const [
                          DataColumn(label: Text('PET DETAILS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF475569)))),
                          DataColumn(label: Text('MULTI-PHOTO CAROUSEL', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF475569)))),
                          DataColumn(label: Text('ORGANIZATION', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF475569)))),
                          DataColumn(label: Text('MEDICAL PASSPORT', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF475569)))),
                          DataColumn(label: Text('BADGES', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF475569)))),
                          DataColumn(label: Text('ADMIN OVERRIDE & CRUD', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF475569)))),
                        ],
                        rows: displayedPets.map((pet) {
                          final carousel = pet.galleryUrls.isNotEmpty ? pet.galleryUrls : [pet.imageUrl];

                          return DataRow(
                            cells: [
                              DataCell(
                                Row(
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: SizedBox(
                                        width: 44,
                                        height: 44,
                                        child: AppNetworkImage(imageUrl: pet.imageUrl, fit: BoxFit.cover),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(pet.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A))),
                                        Text('${pet.species} • ${pet.breed} • ${pet.ageDisplay}', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              DataCell(
                                Row(
                                  children: [
                                    ...carousel.take(3).map((url) {
                                      return Container(
                                        margin: const EdgeInsets.only(right: 4),
                                        width: 32,
                                        height: 32,
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(color: const Color(0xFFE2E8F0)),
                                        ),
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(5),
                                          child: AppNetworkImage(imageUrl: url, fit: BoxFit.cover),
                                        ),
                                      );
                                    }),
                                    if (carousel.length > 3)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF1F5F9),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text('+${carousel.length - 3}', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF6366F1))),
                                      ),
                                  ],
                                ),
                              ),
                              DataCell(
                                Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(pet.shelterName, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                                    Text(pet.shelterPhone, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                                  ],
                                ),
                              ),
                              DataCell(
                                Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        _buildMiniTag(pet.isVaccinated ? 'Vaccinated' : 'Unvaccinated', pet.isVaccinated ? const Color(0xFF10B981) : const Color(0xFFEF4444)),
                                        const SizedBox(width: 4),
                                        _buildMiniTag(pet.isNeutered ? 'Neutered' : 'Intact', pet.isNeutered ? const Color(0xFF6366F1) : const Color(0xFF94A3B8)),
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    SizedBox(
                                      width: 140,
                                      child: Text(
                                        pet.medicalHistory,
                                        style: const TextStyle(fontSize: 10, color: Color(0xFF64748B)),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              DataCell(
                                Row(
                                  children: [
                                    if (pet.isUrgent)
                                      Container(
                                        margin: const EdgeInsets.only(right: 4),
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(color: const Color(0xFFFFE4E6), borderRadius: BorderRadius.circular(4)),
                                        child: const Text('Urgent', style: TextStyle(color: Color(0xFFE11D48), fontSize: 10, fontWeight: FontWeight.bold)),
                                      ),
                                    if (pet.isFeatured)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(color: const Color(0xFFEDE9FE), borderRadius: BorderRadius.circular(4)),
                                        child: const Text('Featured', style: TextStyle(color: Color(0xFF6366F1), fontSize: 10, fontWeight: FontWeight.bold)),
                                      ),
                                    if (!pet.isUrgent && !pet.isFeatured)
                                      const Text('Standard', style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                                  ],
                                ),
                              ),
                              DataCell(
                                Row(
                                  children: [
                                    IconButton(
                                      tooltip: 'Anytime Edit / Image Override',
                                      icon: const Icon(Icons.edit, size: 18, color: Color(0xFF6366F1)),
                                      onPressed: () => _showCreateOrEditPetDialog(pet),
                                    ),
                                    IconButton(
                                      tooltip: 'Ban Listing',
                                      icon: const Icon(Icons.block, size: 18, color: Color(0xFFE11D48)),
                                      onPressed: () => _confirmBanListing(pet.id, pet.name),
                                    ),
                                    IconButton(
                                      tooltip: 'Delete Listing',
                                      icon: const Icon(Icons.delete_outline, size: 18, color: Color(0xFF64748B)),
                                      onPressed: () => _confirmDeleteListing(pet),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String key, String label) {
    final isSelected = _selectedFilter == key;
    return ChoiceChip(
      label: Text(label, style: TextStyle(fontSize: 11, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, color: isSelected ? Colors.white : const Color(0xFF475569))),
      selected: isSelected,
      selectedColor: const Color(0xFF6366F1),
      backgroundColor: const Color(0xFFF1F5F9),
      onSelected: (val) {
        if (val) setState(() => _selectedFilter = key);
      },
    );
  }

  Widget _buildMiniTag(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(label, style: TextStyle(color: color, fontSize: 9.5, fontWeight: FontWeight.bold)),
    );
  }
}
