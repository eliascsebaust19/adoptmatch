import 'dart:convert';
import 'package:flutter/material.dart';
import '../../../core/models/pet_model.dart';
import '../../../core/repositories/admin_repository.dart';
import '../../../core/repositories/pet_repository.dart';
import '../../../core/services/storage_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/app_network_image.dart';

/// Shows the Admin Create or Edit Pet Dialog with full image support
/// (Gallery picker, Camera picker, URL input, and Presets).
void showAdminCreatePetDialog(
  BuildContext context, {
  Pet? existingPet,
  void Function(Pet pet)? onSaved,
}) {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => _AdminCreatePetDialog(existingPet: existingPet, onSaved: onSaved),
  );
}

class _AdminCreatePetDialog extends StatefulWidget {
  final Pet? existingPet;
  final void Function(Pet pet)? onSaved;

  const _AdminCreatePetDialog({this.existingPet, this.onSaved});

  @override
  State<_AdminCreatePetDialog> createState() => _AdminCreatePetDialogState();
}

class _AdminCreatePetDialogState extends State<_AdminCreatePetDialog> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameController;
  late TextEditingController _breedController;
  late TextEditingController _ageDisplayController;
  late TextEditingController _weightController;
  late TextEditingController _storyController;
  late TextEditingController _locationController;
  late TextEditingController _shelterNameController;
  late TextEditingController _medicalHistoryController;
  final TextEditingController _urlController = TextEditingController();

  late String _selectedSpecies;
  late String _selectedGender;
  late bool _isVaccinated;
  late bool _isNeutered;
  late bool _isHouseTrained;
  late bool _isKidSafe;
  late bool _isUrgent;
  late bool _isFeatured;
  late bool _isApartmentFriendly;

  final List<String> _carouselImages = [];
  bool _isProcessingImage = false;

  final List<String> _speciesOptions = ['Dog', 'Cat', 'Bird', 'Small', 'Senior'];
  final List<String> _genderOptions = ['Male', 'Female'];

  static const List<Map<String, String>> _samplePresets = [
    {
      'label': 'Golden Pup',
      'url': 'https://images.unsplash.com/photo-1552053831-71594a27632d?auto=format&fit=crop&w=800&q=80',
    },
    {
      'label': 'Tabby Cat',
      'url': 'https://images.unsplash.com/photo-1514888286974-6c03e2ca1dba?auto=format&fit=crop&w=800&q=80',
    },
    {
      'label': 'Husky',
      'url': 'https://images.unsplash.com/photo-1537151625747-768eb6cf92b2?auto=format&fit=crop&w=800&q=80',
    },
    {
      'label': 'Fluffy Bunny',
      'url': 'https://images.unsplash.com/photo-1585110396000-c9ffd4e4b308?auto=format&fit=crop&w=800&q=80',
    },
  ];

  @override
  void initState() {
    super.initState();
    final p = widget.existingPet;

    _nameController = TextEditingController(text: p?.name ?? '');
    _breedController = TextEditingController(text: p?.breed ?? '');
    _ageDisplayController = TextEditingController(text: p?.ageDisplay ?? '1 yr');
    _weightController = TextEditingController(text: p != null ? '${p.weightKg}' : '4.5');
    _storyController = TextEditingController(
      text: p?.story ?? 'Rescued with compassion and looking for a warm forever home.',
    );
    _locationController = TextEditingController(text: p?.shelterAddress ?? 'Gulshan, Dhaka, Bangladesh');
    _shelterNameController = TextEditingController(text: p?.shelterName ?? 'Dhaka Paws Rescue');
    _medicalHistoryController = TextEditingController(
      text: p?.medicalHistory ?? 'Fully checked by licensed veterinarian. Dewormed & healthy.',
    );

    _selectedSpecies = p?.species ?? 'Dog';
    _selectedGender = p?.gender ?? 'Male';
    _isVaccinated = p?.isVaccinated ?? true;
    _isNeutered = p?.isNeutered ?? true;
    _isHouseTrained = p?.isHouseTrained ?? true;
    _isKidSafe = p?.isKidSafe ?? true;
    _isUrgent = p?.isUrgent ?? false;
    _isFeatured = p?.isFeatured ?? false;
    _isApartmentFriendly = p?.isApartmentFriendly ?? true;

    if (p != null) {
      if (p.galleryUrls.isNotEmpty) {
        _carouselImages.addAll(p.galleryUrls);
      } else if (p.imageUrl.isNotEmpty) {
        _carouselImages.add(p.imageUrl);
      }
    } else {
      _carouselImages.add(
        'https://images.unsplash.com/photo-1552053831-71594a27632d?auto=format&fit=crop&w=800&q=80',
      );
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _breedController.dispose();
    _ageDisplayController.dispose();
    _weightController.dispose();
    _storyController.dispose();
    _locationController.dispose();
    _shelterNameController.dispose();
    _medicalHistoryController.dispose();
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _pickFromGallery() async {
    setState(() => _isProcessingImage = true);
    try {
      final file = await StorageService.pickImageFromGallery();
      if (file != null) {
        final bytes = await file.readAsBytes();
        final base64String = 'data:image/jpeg;base64,${base64Encode(bytes)}';
        setState(() {
          _carouselImages.add(base64String);
        });
      }
    } catch (e) {
      debugPrint('[AdminCreatePet] Gallery pick error: $e');
    } finally {
      if (mounted) setState(() => _isProcessingImage = false);
    }
  }

  Future<void> _takePhoto() async {
    setState(() => _isProcessingImage = true);
    try {
      final file = await StorageService.pickImageFromCamera();
      if (file != null) {
        final bytes = await file.readAsBytes();
        final base64String = 'data:image/jpeg;base64,${base64Encode(bytes)}';
        setState(() {
          _carouselImages.add(base64String);
        });
      }
    } catch (e) {
      debugPrint('[AdminCreatePet] Camera capture error: $e');
    } finally {
      if (mounted) setState(() => _isProcessingImage = false);
    }
  }

  void _addFromUrl() {
    final url = _urlController.text.trim();
    if (url.isNotEmpty && (url.startsWith('http://') || url.startsWith('https://'))) {
      setState(() {
        _carouselImages.add(url);
        _urlController.clear();
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid HTTP/HTTPS image URL')),
      );
    }
  }

  void _savePet() {
    if (!_formKey.currentState!.validate()) return;
    if (_carouselImages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please provide at least one photo of the pet.')),
      );
      return;
    }

    final weight = double.tryParse(_weightController.text.trim()) ?? 4.5;
    final id = widget.existingPet?.id ?? 'pet-admin-${DateTime.now().millisecondsSinceEpoch}';

    final pet = Pet(
      id: id,
      name: _nameController.text.trim(),
      species: _selectedSpecies,
      breed: _breedController.text.trim().isEmpty ? 'Mixed Breed' : _breedController.text.trim(),
      ageDisplay: _ageDisplayController.text.trim(),
      ageMonths: 14,
      gender: _selectedGender,
      weightKg: weight,
      distanceKm: 2.5,
      matchScore: 95,
      imageUrl: _carouselImages.first,
      galleryUrls: List.from(_carouselImages),
      isVaccinated: _isVaccinated,
      isNeutered: _isNeutered,
      isHouseTrained: _isHouseTrained,
      isKidSafe: _isKidSafe,
      isApartmentFriendly: _isApartmentFriendly,
      isFeatured: _isFeatured,
      isUrgent: _isUrgent,
      shelterName: _shelterNameController.text.trim(),
      shelterPhone: '+880 17•• ••••89',
      shelterAddress: _locationController.text.trim(),
      shelterRating: 4.9,
      story: _storyController.text.trim(),
      medicalHistory: _medicalHistoryController.text.trim(),
      qrHash: 'ADMIN-PET-$id',
    );

    // 1. Add to live catalog
    PetRepository().addPet(pet);

    // 2. Audit record in AdminRepository
    AdminRepository().createPetListing(pet);

    widget.onSaved?.call(pet);
    Navigator.of(context).pop();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('পোষ্য "${pet.name}" সফলভাবে যুক্ত হয়েছে! (Pet listing saved)'),
        backgroundColor: AppColors.secondary,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.existingPet != null;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 580, maxHeight: 720),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0D9488).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.pets, color: Color(0xFF0D9488), size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isEditing ? 'Edit Pet Listing' : 'Add Rescue Pet / পোষ্য যুক্ত করুন',
                            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                          ),
                          const Text(
                            'গ্যালারি বা ক্যামেরা দিয়ে ছবি যুক্ত করুন',
                            style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20, color: Color(0xFF64748B)),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Divider(height: 1, color: Color(0xFFE2E8F0)),
                const SizedBox(height: 14),

                // Scrollable Form Content
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // SECTION 1: PET PHOTOS
                        const Text(
                          'Pet Photos / পোষ্যের ছবি (At least 1 required)',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                        ),
                        const SizedBox(height: 8),

                        // Carousel / Thumbnails preview
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (_carouselImages.isNotEmpty)
                                SizedBox(
                                  height: 90,
                                  child: ListView.separated(
                                    scrollDirection: Axis.horizontal,
                                    itemCount: _carouselImages.length,
                                    separatorBuilder: (c, i) => const SizedBox(width: 8),
                                    itemBuilder: (ctx, idx) {
                                      final img = _carouselImages[idx];
                                      return Stack(
                                        clipBehavior: Clip.none,
                                        children: [
                                          ClipRRect(
                                            borderRadius: BorderRadius.circular(10),
                                            child: SizedBox(
                                              width: 90,
                                              height: 90,
                                              child: AppNetworkImage(imageUrl: img, fit: BoxFit.cover),
                                            ),
                                          ),
                                          if (idx == 0)
                                            Positioned(
                                              bottom: 4,
                                              left: 4,
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFF0D9488),
                                                  borderRadius: BorderRadius.circular(4),
                                                ),
                                                child: const Text(
                                                  'Cover',
                                                  style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                                                ),
                                              ),
                                            ),
                                          Positioned(
                                            top: 2,
                                            right: 2,
                                            child: InkWell(
                                              onTap: () {
                                                if (_carouselImages.length > 1) {
                                                  setState(() => _carouselImages.removeAt(idx));
                                                } else {
                                                  ScaffoldMessenger.of(context).showSnackBar(
                                                    const SnackBar(content: Text('At least one photo is required.')),
                                                  );
                                                }
                                              },
                                              child: Container(
                                                padding: const EdgeInsets.all(2),
                                                decoration: const BoxDecoration(
                                                  color: Colors.black54,
                                                  shape: BoxShape.circle,
                                                ),
                                                child: const Icon(Icons.close, size: 14, color: Colors.white),
                                              ),
                                            ),
                                          ),
                                        ],
                                      );
                                    },
                                  ),
                                ),
                              const SizedBox(height: 10),

                              // Quick Action Buttons for Photo Upload
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: const Color(0xFF0D9488),
                                        side: const BorderSide(color: Color(0xFF0D9488)),
                                        padding: const EdgeInsets.symmetric(vertical: 9),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                      ),
                                      icon: const Icon(Icons.photo_library_outlined, size: 16),
                                      label: const Text('Gallery / গ্যালারি', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                      onPressed: _isProcessingImage ? null : _pickFromGallery,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: const Color(0xFF0D9488),
                                        side: const BorderSide(color: Color(0xFF0D9488)),
                                        padding: const EdgeInsets.symmetric(vertical: 9),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                      ),
                                      icon: const Icon(Icons.camera_alt_outlined, size: 16),
                                      label: const Text('Camera / ক্যামেরা', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                      onPressed: _isProcessingImage ? null : _takePhoto,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),

                              // URL Input row
                              Row(
                                children: [
                                  Expanded(
                                    child: SizedBox(
                                      height: 36,
                                      child: TextField(
                                        controller: _urlController,
                                        style: const TextStyle(fontSize: 12),
                                        decoration: InputDecoration(
                                          hintText: 'Or paste image URL...',
                                          hintStyle: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                                          filled: true,
                                          fillColor: Colors.white,
                                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF0D9488),
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    ),
                                    onPressed: _addFromUrl,
                                    child: const Text('Add URL', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),

                              // Presets Row
                              Wrap(
                                spacing: 6,
                                runSpacing: 4,
                                children: _samplePresets.map((preset) {
                                  return ActionChip(
                                    avatar: const Icon(Icons.add_photo_alternate, size: 13, color: Color(0xFF0D9488)),
                                    label: Text(preset['label']!, style: const TextStyle(fontSize: 10, color: Color(0xFF0F766E))),
                                    backgroundColor: const Color(0xFFCCFBF1),
                                    padding: EdgeInsets.zero,
                                    onPressed: () {
                                      setState(() {
                                        _carouselImages.add(preset['url']!);
                                      });
                                    },
                                  );
                                }).toList(),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // SECTION 2: BASIC DETAILS
                        const Text(
                          'Basic Information',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                        ),
                        const SizedBox(height: 8),

                        TextFormField(
                          controller: _nameController,
                          decoration: InputDecoration(
                            labelText: 'Pet Name / নাম *',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          ),
                          validator: (v) => (v == null || v.trim().isEmpty) ? 'Name is required' : null,
                        ),
                        const SizedBox(height: 10),

                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                value: _selectedSpecies,
                                decoration: InputDecoration(
                                  labelText: 'Species / প্রজাতি',
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                ),
                                items: _speciesOptions.map((s) => DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(fontSize: 13)))).toList(),
                                onChanged: (v) => setState(() => _selectedSpecies = v ?? 'Dog'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                value: _selectedGender,
                                decoration: InputDecoration(
                                  labelText: 'Gender / লিঙ্গ',
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                ),
                                items: _genderOptions.map((g) => DropdownMenuItem(value: g, child: Text(g, style: const TextStyle(fontSize: 13)))).toList(),
                                onChanged: (v) => setState(() => _selectedGender = v ?? 'Male'),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),

                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _breedController,
                                decoration: InputDecoration(
                                  labelText: 'Breed / জাত',
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextFormField(
                                controller: _ageDisplayController,
                                decoration: InputDecoration(
                                  labelText: 'Age Display (e.g. 1 yr, 6 mos)',
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),

                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _weightController,
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(
                                  labelText: 'Weight (kg)',
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextFormField(
                                controller: _shelterNameController,
                                decoration: InputDecoration(
                                  labelText: 'Shelter Name',
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),

                        TextFormField(
                          controller: _locationController,
                          decoration: InputDecoration(
                            labelText: 'Shelter Location / ঠিকানা',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          ),
                        ),
                        const SizedBox(height: 10),

                        TextFormField(
                          controller: _storyController,
                          maxLines: 2,
                          decoration: InputDecoration(
                            labelText: 'Rescue Story & Notes / বিবরণ',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          ),
                        ),
                        const SizedBox(height: 10),

                        TextFormField(
                          controller: _medicalHistoryController,
                          decoration: InputDecoration(
                            labelText: 'Medical History / চিকিৎসা বিবরণ',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Health Tags
                        const Text(
                          'Health & Safety Certifications',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                        ),
                        Wrap(
                          spacing: 12,
                          children: [
                            FilterChip(
                              label: const Text('Vaccinated', style: TextStyle(fontSize: 11)),
                              selected: _isVaccinated,
                              onSelected: (v) => setState(() => _isVaccinated = v),
                            ),
                            FilterChip(
                              label: const Text('Neutered', style: TextStyle(fontSize: 11)),
                              selected: _isNeutered,
                              onSelected: (v) => setState(() => _isNeutered = v),
                            ),
                            FilterChip(
                              label: const Text('House Trained', style: TextStyle(fontSize: 11)),
                              selected: _isHouseTrained,
                              onSelected: (v) => setState(() => _isHouseTrained = v),
                            ),
                            FilterChip(
                              label: const Text('Kid Safe', style: TextStyle(fontSize: 11)),
                              selected: _isKidSafe,
                              onSelected: (v) => setState(() => _isKidSafe = v),
                            ),
                            FilterChip(
                              label: const Text('Apartment Friendly', style: TextStyle(fontSize: 11)),
                              selected: _isApartmentFriendly,
                              onSelected: (v) => setState(() => _isApartmentFriendly = v),
                            ),
                            FilterChip(
                              label: const Text('Urgent Rescue', style: TextStyle(fontSize: 11)),
                              selected: _isUrgent,
                              selectedColor: const Color(0xFFFFE4E6),
                              onSelected: (v) => setState(() => _isUrgent = v),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                const Divider(height: 1, color: Color(0xFFE2E8F0)),
                const SizedBox(height: 12),

                // Buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancel / বাতিল', style: TextStyle(color: Color(0xFF64748B))),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0D9488),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                      ),
                      icon: const Icon(Icons.check_circle_outline, size: 16),
                      label: Text(
                        isEditing ? 'Update Listing' : 'Publish Pet / যোগ করুন',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      onPressed: _savePet,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
