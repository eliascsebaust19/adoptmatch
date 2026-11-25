import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../core/models/pet_model.dart';
import '../../../core/repositories/admin_repository.dart';
import '../../../core/services/storage_service.dart';
import '../../../core/services/supabase_service.dart';
import '../../../shared/widgets/app_network_image.dart';

/// Shows the Admin Create or Edit Pet Dialog with full image support
/// (Drag-and-Drop area, Gallery picker, Camera picker, URL input, and instant previews).
void showAdminCreatePetDialog(
  BuildContext context, {
  Pet? existingPet,
  void Function(Pet pet)? onSaved,
}) {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (ctx) =>
        _AdminCreatePetDialog(existingPet: existingPet, onSaved: onSaved),
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
  late String _selectedAdoptionStatus;
  late bool _isVaccinated;
  late bool _isNeutered;
  late bool _isHouseTrained;
  late bool _isKidSafe;
  late bool _isUrgent;
  late bool _isFeatured;
  late bool _isApartmentFriendly;

  final List<String> _carouselImages = [];
  final Map<String, Future<String>> _pendingUploads = {};
  bool _isProcessingImage = false;
  bool _isSaving = false;
  bool _showUrlField = false;

  final List<String> _speciesOptions = [
    'Dog',
    'Cat',
    'Bird',
    'Small',
    'Senior',
  ];
  final List<String> _genderOptions = ['Male', 'Female'];
  final List<String> _adoptionStatusOptions = [
    'available',
    'pending',
    'foster',
    'adopted',
    'archived',
  ];

  // Reliable, high-resolution public animal presets (Unsplash CDN)
  static const List<Map<String, String>> _samplePresets = [
    {
      'label': 'Golden Pup',
      'url': 'https://images.unsplash.com/photo-1552053831-71594a27632d?auto=format&fit=crop&w=600&q=80',
    },
    {
      'label': 'Tabby Cat',
      'url': 'https://images.unsplash.com/photo-1514888286974-6c03e2ca1dba?auto=format&fit=crop&w=600&q=80',
    },
    {
      'label': 'Husky',
      'url': 'https://images.unsplash.com/photo-1537151625747-768eb6cf92b2?auto=format&fit=crop&w=600&q=80',
    },
    {
      'label': 'Fluffy Bunny',
      'url': 'https://images.unsplash.com/photo-1585110396000-c9ffd4e4b308?auto=format&fit=crop&w=600&q=80',
    },
    {
      'label': 'Rescue Kitten',
      'url': 'https://images.unsplash.com/photo-1543852786-1cf6624b9987?auto=format&fit=crop&w=600&q=80',
    },
  ];

  @override
  void initState() {
    super.initState();
    final p = widget.existingPet;

    _nameController = TextEditingController(text: p?.name ?? '');
    _breedController = TextEditingController(text: p?.breed ?? '');
    _ageDisplayController = TextEditingController(
      text: p?.ageDisplay ?? '1 yr',
    );
    _weightController = TextEditingController(
      text: p != null ? '${p.weightKg}' : '4.5',
    );
    _storyController = TextEditingController(
      text:
          p?.story ??
          'Rescued with compassion and looking for a warm forever home.',
    );
    _locationController = TextEditingController(
      text: p?.shelterAddress ?? 'Gulshan, Dhaka, Bangladesh',
    );
    _shelterNameController = TextEditingController(
      text: p?.shelterName ?? 'Dhaka Paws Rescue',
    );
    _medicalHistoryController = TextEditingController(
      text:
          p?.medicalHistory ??
          'Fully checked by licensed veterinarian. Dewormed & healthy.',
    );

    _selectedSpecies = p?.species ?? 'Dog';
    _selectedGender = p?.gender ?? 'Male';
    final rawStatus = (p?.adoptionStatus ?? 'available').toLowerCase();
    _selectedAdoptionStatus = _adoptionStatusOptions.contains(rawStatus)
        ? rawStatus
        : 'available';
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
      // Default to first reliable sample preset so preview is never empty
      _carouselImages.add(_samplePresets.first['url']!);
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

  /// Starts uploading picked bytes in the background while tracking the Future
  /// so `_savePet()` can await it instead of uploading twice.
  void _queueCloudUpload(
    String previewUri,
    List<int> bytes,
    String fileName,
  ) {
    final allowFallback =
        !SupabaseService.isInitialized || SupabaseService.auth.currentSession == null;
    final uploadFuture = StorageService.uploadPetImage(
      bytes: bytes is Uint8List ? bytes : Uint8List.fromList(bytes),
      fileName: fileName,
      petId: widget.existingPet?.id,
      allowLocalFallback: allowFallback,
    );
    _pendingUploads[previewUri] = uploadFuture;
    unawaited(() async {
      try {
        final cloudUrl = await uploadFuture;
        if (mounted && cloudUrl.startsWith('http')) {
          setState(() {
            final idx = _carouselImages.indexOf(previewUri);
            if (idx != -1) {
              _carouselImages[idx] = cloudUrl;
            }
          });
        }
      } catch (uploadErr) {
        debugPrint(
          '[AdminCreatePet] Cloud upload notice: $uploadErr',
        );
      } finally {
        _pendingUploads.remove(previewUri);
      }
    }());
  }

  /// Pick from gallery with validation (JPG/PNG/WebP <= 5 MB), instant preview & cloud upload
  Future<void> _pickFromGallery({bool replaceCover = false}) async {
    try {
      final file = await StorageService.pickImageFromGallery();
      if (file != null) {
        setState(() => _isProcessingImage = true);
        final bytes = await file.readAsBytes();
        final mime = StorageService.validateAndDetectPetImage(
          bytes: bytes,
          fileName: file.name,
        );

        // 1. Instant local base64 preview (appears in < 50ms)
        final previewUri = 'data:$mime;base64,${base64Encode(bytes)}';
        setState(() {
          if (replaceCover && _carouselImages.isNotEmpty) {
            _pendingUploads.remove(_carouselImages.first);
            _carouselImages[0] = previewUri;
          } else {
            _carouselImages.insert(0, previewUri);
          }
          _isProcessingImage = false;
        });

        // 2. Background upload to Supabase 'pet-images'
        _queueCloudUpload(previewUri, bytes, file.name);
      }
    } catch (e) {
      debugPrint('[AdminCreatePet] Gallery pick error: $e');
      if (mounted) {
        setState(() => _isProcessingImage = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$e'.replaceFirst('FormatException: ', '')),
            backgroundColor: const Color(0xFFE11D48),
          ),
        );
      }
    }
  }

  /// Pick multiple images to upload a completely new gallery
  Future<void> _replaceWithNewGallery() async {
    try {
      final files = await StorageService.pickMultipleImagesFromGallery();
      if (files.isEmpty) return;

      setState(() => _isProcessingImage = true);
      final newEntries = <({String uri, Uint8List bytes, String name})>[];
      for (final file in files) {
        final bytes = await file.readAsBytes();
        final mime = StorageService.validateAndDetectPetImage(
          bytes: bytes,
          fileName: file.name,
        );
        newEntries.add((
          uri: 'data:$mime;base64,${base64Encode(bytes)}',
          bytes: bytes,
          name: file.name,
        ));
      }

      setState(() {
        _pendingUploads.clear();
        _carouselImages
          ..clear()
          ..addAll(newEntries.map((e) => e.uri));
        _isProcessingImage = false;
      });

      for (final entry in newEntries) {
        _queueCloudUpload(entry.uri, entry.bytes, entry.name);
      }
    } catch (e) {
      debugPrint('[AdminCreatePet] New gallery pick error: $e');
      if (mounted) {
        setState(() => _isProcessingImage = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$e'.replaceFirst('FormatException: ', '')),
            backgroundColor: const Color(0xFFE11D48),
          ),
        );
      }
    }
  }

  /// Take photo using camera with validation, instant local preview & background cloud upload
  Future<void> _takePhoto() async {
    try {
      final file = await StorageService.pickImageFromCamera();
      if (file != null) {
        setState(() => _isProcessingImage = true);
        final bytes = await file.readAsBytes();
        final mime = StorageService.validateAndDetectPetImage(
          bytes: bytes,
          fileName: file.name,
        );

        final previewUri = 'data:$mime;base64,${base64Encode(bytes)}';
        setState(() {
          _carouselImages.insert(0, previewUri); // Make cover immediately
          _isProcessingImage = false;
        });

        _queueCloudUpload(previewUri, bytes, file.name);
      }
    } catch (e) {
      debugPrint('[AdminCreatePet] Camera error: $e');
      if (mounted) {
        setState(() => _isProcessingImage = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$e'.replaceFirst('FormatException: ', '')),
            backgroundColor: const Color(0xFFE11D48),
          ),
        );
      }
    }
  }

  void _addFromUrl() {
    final url = _urlController.text.trim();
    if (url.isNotEmpty &&
        (url.startsWith('http://') || url.startsWith('https://'))) {
      setState(() {
        _carouselImages.insert(0, url);
        _urlController.clear();
        _showUrlField = false;
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid HTTP/HTTPS image URL'),
        ),
      );
    }
  }

  void _setAsCover(int index) {
    if (index <= 0 || index >= _carouselImages.length) return;
    setState(() {
      final img = _carouselImages.removeAt(index);
      _carouselImages.insert(0, img);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Selected photo set as Cover / প্রধান ছবি নির্বাচন করা হয়েছে',
        ),
        duration: Duration(seconds: 1),
      ),
    );
  }

  void _removePhoto(int index) {
    if (_carouselImages.length > 1) {
      setState(() => _carouselImages.removeAt(index));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'At least one photo is required / কমপক্ষে একটি ছবি থাকা প্রয়োজন।',
          ),
        ),
      );
    }
  }

  Future<void> _savePet() async {
    if (!_formKey.currentState!.validate()) return;
    if (_carouselImages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please provide at least one photo of the pet.'),
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    final weight = double.tryParse(_weightController.text.trim()) ?? 4.5;
    final id =
        widget.existingPet?.id ??
        'pet-admin-${DateTime.now().millisecondsSinceEpoch}';

    final hasCloudSession =
        SupabaseService.isInitialized &&
        SupabaseService.auth.currentSession != null;

    // Ensure any data URI images are resolved/uploaded to cloud storage
    final resolvedImages = <String>[];
    for (int i = 0; i < _carouselImages.length; i++) {
      final img = _carouselImages[i];
      if (_pendingUploads.containsKey(img)) {
        try {
          final cloudUrl = await _pendingUploads[img]!;
          if (hasCloudSession && !cloudUrl.startsWith('http')) {
            throw Exception('Cloud image upload did not return a hosted URL.');
          }
          resolvedImages.add(cloudUrl.startsWith('http') ? cloudUrl : img);
        } catch (e) {
          if (hasCloudSession) {
            if (mounted) {
              setState(() => _isSaving = false);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  backgroundColor: const Color(0xFFE11D48),
                  content: Text('Image upload failed: $e'),
                ),
              );
            }
            return;
          }
          resolvedImages.add(img);
        }
      } else if (img.startsWith('data:image')) {
        try {
          final commaIdx = img.indexOf(',');
          final base64Str = commaIdx != -1 ? img.substring(commaIdx + 1) : img;
          final bytes = base64Decode(base64Str);
          final cloudUrl = await StorageService.uploadPetImage(
            bytes: bytes,
            fileName: 'pet_${id}_$i.jpg',
            petId: id,
            allowLocalFallback: !hasCloudSession,
          );
          if (cloudUrl.startsWith('http')) {
            resolvedImages.add(cloudUrl);
          } else {
            resolvedImages.add(img);
          }
        } catch (e) {
          if (hasCloudSession) {
            if (mounted) {
              setState(() => _isSaving = false);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  backgroundColor: const Color(0xFFE11D48),
                  content: Text('Cloud image upload failed: $e'),
                ),
              );
            }
            return;
          }
          debugPrint('[AdminCreatePet] Cloud upload for image $i: $e');
          resolvedImages.add(img);
        }
      } else {
        resolvedImages.add(img);
      }
    }

    _carouselImages.clear();
    _carouselImages.addAll(resolvedImages);

    final baseStory = _storyController.text.trim();
    final syncedStory = _selectedAdoptionStatus == 'adopted'
        ? (baseStory.startsWith('[ADOPTED]') ? baseStory : '[ADOPTED] $baseStory')
        : baseStory.replaceAll('[ADOPTED] ', '').replaceAll('[ADOPTED]', '');

    final pet = Pet(
      id: id,
      name: _nameController.text.trim(),
      species: _selectedSpecies,
      breed: _breedController.text.trim().isEmpty
          ? 'Mixed Breed'
          : _breedController.text.trim(),
      ageDisplay: _ageDisplayController.text.trim(),
      ageMonths: widget.existingPet?.ageMonths ?? 14,
      gender: _selectedGender,
      weightKg: weight,
      distanceKm: widget.existingPet?.distanceKm ?? 2.5,
      matchScore: widget.existingPet?.matchScore ?? 95,
      imageUrl: resolvedImages.first,
      galleryUrls: List.from(resolvedImages),
      isVaccinated: _isVaccinated,
      isNeutered: _isNeutered,
      isHouseTrained: _isHouseTrained,
      isKidSafe: _isKidSafe,
      isApartmentFriendly: _isApartmentFriendly,
      isFeatured: _isFeatured,
      isUrgent: _isUrgent,
      isFavorite: widget.existingPet?.isFavorite ?? false,
      isFoster: _selectedAdoptionStatus == 'foster',
      shelterName: _shelterNameController.text.trim(),
      shelterPhone: widget.existingPet?.shelterPhone ?? '+880 17•• ••••89',
      shelterAddress: _locationController.text.trim(),
      shelterRating: widget.existingPet?.shelterRating ?? 4.9,
      story: syncedStory,
      medicalHistory: _medicalHistoryController.text.trim(),
      qrHash: (widget.existingPet?.qrHash.isNotEmpty == true)
          ? widget.existingPet!.qrHash
          : 'ADMIN-PET-$id',
      adoptionStatus: _selectedAdoptionStatus,
    );

    Pet saved;
    try {
      if (widget.existingPet != null) {
        await AdminRepository().overridePetListing(pet);
        saved = pet;
        // Delete obsolete cloud images that were replaced or removed
        final previousUrls = <String>{
          if (widget.existingPet!.imageUrl.isNotEmpty)
            widget.existingPet!.imageUrl,
          ...widget.existingPet!.galleryUrls,
        };
        for (final oldUrl in previousUrls) {
          if (!resolvedImages.contains(oldUrl)) {
            unawaited(StorageService.deletePetImageByUrl(oldUrl));
          }
        }
      } else {
        saved = await AdminRepository().createPetListing(pet);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFFE11D48),
            content: Text('Listing not saved: $e'),
          ),
        );
      }
      return;
    }

    if (!mounted) return;
    setState(() => _isSaving = false);
    widget.onSaved?.call(saved);
    Navigator.of(context).pop();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          widget.existingPet != null
              ? 'পোষ্য "${pet.name}" এর তথ্য সফলভাবে আপডেট হয়েছে! (Updated successfully)'
              : 'পোষ্য "${pet.name}" সফলভাবে যুক্ত হয়েছে! (Pet saved successfully)',
        ),
        backgroundColor: const Color(0xFF0D9488),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.existingPet != null;
    final mediaQuery = MediaQuery.of(context);
    final dialogHeight = math.min(mediaQuery.size.height * 0.90, 780.0);
    final dialogWidth = math.min(mediaQuery.size.width * 0.94, 560.0);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      child: SizedBox(
        width: dialogWidth,
        height: dialogHeight,
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ==========================================
              // 1. PINNED DIALOG HEADER
              // ==========================================
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 14, 14),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0D9488).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.pets_rounded,
                        color: Color(0xFF0D9488),
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isEditing
                                ? 'Edit Pet Listing'
                                : 'Add Rescue Pet / পোষ্য যোগ করুন',
                            style: const TextStyle(
                              fontSize: 16.5,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0F172A),
                              letterSpacing: -0.2,
                            ),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'Quick publish with photos and live matching',
                            style: TextStyle(
                              fontSize: 11.5,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.close_rounded,
                        size: 22,
                        color: Color(0xFF64748B),
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                      tooltip: 'Close',
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: Color(0xFFE2E8F0)),

              // ==========================================
              // 2. SCROLLABLE FORM BODY (EXPANDED TO FILL)
              // ==========================================
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 14,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ------------------------------------------
                      // SECTION 1: PHOTO UPLOAD & PREVIEWS
                      // ------------------------------------------
                      _buildSectionTitle(
                        icon: Icons.photo_camera_back_rounded,
                        title: 'Pet Photos / পোষ্যের ছবি',
                        subtitle:
                            'Upload from gallery, camera, or choose a preset',
                      ),
                      const SizedBox(height: 10),

                      // Large Cover Photo Preview Card
                      if (_carouselImages.isNotEmpty) ...[
                        _buildCoverPhotoPreview(),
                        const SizedBox(height: 12),
                      ],

                      // Drag & Drop / Upload Card
                      _buildDropZoneCard(),
                      const SizedBox(height: 12),

                      // Photo Preview Carousel / Thumbnail Strip (when > 1 photo)
                      if (_carouselImages.length > 1) ...[
                        _buildPhotoPreviewStrip(),
                        const SizedBox(height: 16),
                      ],

                      // ------------------------------------------
                      // SECTION 2: BASIC PET PROFILE
                      // ------------------------------------------
                      _buildSectionTitle(
                        icon: Icons.badge_outlined,
                        title: 'Basic Information / মৌলিক তথ্য',
                        subtitle: 'Name, species, gender & appearance',
                      ),
                      const SizedBox(height: 10),

                      // Pet Name Field
                      TextFormField(
                        controller: _nameController,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                        decoration: _inputDecoration(
                          label: 'Pet Name / নাম *',
                          hint: 'e.g. Milo, Luna, বাঘা',
                          prefixIcon: Icons.pets,
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Pet name is required'
                            : null,
                      ),
                      const SizedBox(height: 12),

                      // Species Selection (Visual Chips)
                      const Text(
                        'Species / প্রজাতি:',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF334155),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: _speciesOptions.map((species) {
                          final isSelected = _selectedSpecies == species;
                          return ChoiceChip(
                            label: Text(
                              _getSpeciesLabel(species),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.w500,
                                color: isSelected
                                    ? Colors.white
                                    : const Color(0xFF334155),
                              ),
                            ),
                            selected: isSelected,
                            selectedColor: const Color(0xFF0D9488),
                            backgroundColor: const Color(0xFFF1F5F9),
                            side: BorderSide(
                              color: isSelected
                                  ? const Color(0xFF0D9488)
                                  : const Color(0xFFE2E8F0),
                            ),
                            onSelected: (val) {
                              if (val) {
                                setState(() => _selectedSpecies = species);
                              }
                            },
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 12),

                      // Gender & Age Row
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Gender / লিঙ্গ:',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF334155),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  children: _genderOptions.map((gender) {
                                    final isSelected =
                                        _selectedGender == gender;
                                    return Padding(
                                      padding: const EdgeInsets.only(right: 6),
                                      child: ChoiceChip(
                                        label: Text(
                                          gender == 'Male'
                                              ? '♂ Male'
                                              : '♀ Female',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: isSelected
                                                ? FontWeight.bold
                                                : FontWeight.w500,
                                            color: isSelected
                                                ? Colors.white
                                                : const Color(0xFF334155),
                                          ),
                                        ),
                                        selected: isSelected,
                                        selectedColor: const Color(0xFF0D9488),
                                        backgroundColor: const Color(
                                          0xFFF1F5F9,
                                        ),
                                        side: BorderSide(
                                          color: isSelected
                                              ? const Color(0xFF0D9488)
                                              : const Color(0xFFE2E8F0),
                                        ),
                                        onSelected: (val) {
                                          if (val) {
                                            setState(
                                              () => _selectedGender = gender,
                                            );
                                          }
                                        },
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextFormField(
                              controller: _ageDisplayController,
                              style: const TextStyle(fontSize: 13),
                              decoration: _inputDecoration(
                                label: 'Age / বয়স',
                                hint: 'e.g. 1 yr, 6 mos',
                                prefixIcon: Icons.cake_outlined,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Breed & Weight Row
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _breedController,
                              style: const TextStyle(fontSize: 13),
                              decoration: _inputDecoration(
                                label: 'Breed / জাত',
                                hint: 'e.g. Deshi / Mixed',
                                prefixIcon: Icons.category_outlined,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextFormField(
                              controller: _weightController,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              style: const TextStyle(fontSize: 13),
                              decoration: _inputDecoration(
                                label: 'Weight / ওজন (kg)',
                                hint: '4.5',
                                prefixIcon: Icons.scale_outlined,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // ------------------------------------------
                      // SECTION 3: SHELTER & HEALTH CERTIFICATIONS
                      // ------------------------------------------
                      _buildSectionTitle(
                        icon: Icons.health_and_safety_outlined,
                        title: 'Shelter & Health / শেল্টার ও চিকিৎসা',
                        subtitle:
                            'Shelter contact, medical background & health tags',
                      ),
                      const SizedBox(height: 10),

                      // Shelter Name & Location in one row
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _shelterNameController,
                              style: const TextStyle(fontSize: 13),
                              decoration: _inputDecoration(
                                label: 'Shelter / শেল্টার নাম',
                                hint: 'Dhaka Paws Rescue',
                                prefixIcon: Icons.home_work_outlined,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextFormField(
                              controller: _locationController,
                              style: const TextStyle(fontSize: 13),
                              decoration: _inputDecoration(
                                label: 'Location / ঠিকানা',
                                hint: 'Gulshan, Dhaka',
                                prefixIcon: Icons.location_on_outlined,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Rescue Story Notes (2 lines)
                      TextFormField(
                        controller: _storyController,
                        maxLines: 2,
                        style: const TextStyle(fontSize: 13),
                        decoration: _inputDecoration(
                          label: 'Rescue Story & Notes / বিবরণ',
                          hint: 'Rescued with compassion and looking for a warm forever home...',
                          prefixIcon: Icons.article_outlined,
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Medical History
                      TextFormField(
                        controller: _medicalHistoryController,
                        maxLines: 2,
                        style: const TextStyle(fontSize: 13),
                        decoration: _inputDecoration(
                          label: 'Medical History / চিকিৎসা বিবরণ',
                          hint: 'Fully checked by licensed veterinarian. Dewormed & healthy...',
                          prefixIcon: Icons.medical_services_outlined,
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Adoption Availability Status
                      const Text(
                        'Availability Status / বর্তমান অবস্থা:',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF334155),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: _adoptionStatusOptions.map((st) {
                          final isSelected = _selectedAdoptionStatus == st;
                          final label = st[0].toUpperCase() + st.substring(1);
                          return ChoiceChip(
                            label: Text(
                              label,
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                color: isSelected ? Colors.white : const Color(0xFF334155),
                              ),
                            ),
                            selected: isSelected,
                            selectedColor: st == 'adopted'
                                ? const Color(0xFF10B981)
                                : (st == 'pending'
                                    ? const Color(0xFFF59E0B)
                                    : (st == 'archived'
                                        ? const Color(0xFF64748B)
                                        : const Color(0xFF0D9488))),
                            backgroundColor: const Color(0xFFF1F5F9),
                            onSelected: (val) {
                              if (val) setState(() => _selectedAdoptionStatus = st);
                            },
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 14),

                      // Health & Safety Certification Chips
                      const Text(
                        'Health & Safety Certifications:',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF334155),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          _buildCertificationChip(
                            'Vaccinated',
                            _isVaccinated,
                            (v) => setState(() => _isVaccinated = v),
                          ),
                          _buildCertificationChip(
                            'Neutered',
                            _isNeutered,
                            (v) => setState(() => _isNeutered = v),
                          ),
                          _buildCertificationChip(
                            'House Trained',
                            _isHouseTrained,
                            (v) => setState(() => _isHouseTrained = v),
                          ),
                          _buildCertificationChip(
                            'Kid Safe',
                            _isKidSafe,
                            (v) => setState(() => _isKidSafe = v),
                          ),
                          _buildCertificationChip(
                            'Apartment Friendly',
                            _isApartmentFriendly,
                            (v) => setState(() => _isApartmentFriendly = v),
                          ),
                          _buildCertificationChip(
                            '🚨 Urgent Rescue',
                            _isUrgent,
                            (v) => setState(() => _isUrgent = v),
                            isUrgent: true,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),

              // ==========================================
              // 3. PINNED BOTTOM ACTION BAR (GUARANTEED VISIBLE)
              // ==========================================
              Container(
                padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(
                    top: BorderSide(color: Color(0xFFE2E8F0), width: 1),
                  ),
                  borderRadius: BorderRadius.vertical(
                    bottom: Radius.circular(24),
                  ),
                ),
                child: Row(
                  children: [
                    // Cancel Button
                    Expanded(
                      flex: 2,
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF64748B),
                          side: const BorderSide(color: Color(0xFFCBD5E1)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: _isSaving
                            ? null
                            : () => Navigator.of(context).pop(),
                        child: const Text(
                          'Cancel / বাতিল',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Add / Publish Button (Prominent & Always Visible)
                    Expanded(
                      flex: 3,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0D9488),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          elevation: 1,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: _isSaving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(
                                Icons.add_circle_outline_rounded,
                                size: 20,
                              ),
                        label: Text(
                          _isSaving
                              ? 'Saving Pet...'
                              : (isEditing
                                    ? 'Save Changes'
                                    : '+ Add Rescue Pet / পোষ্য যোগ করুন'),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13.5,
                          ),
                        ),
                        onPressed: _isSaving ? null : _savePet,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==========================================
  // HELPER WIDGETS
  // ==========================================

  Widget _buildSectionTitle({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: const Color(0xFF0D9488)),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
              ),
              Text(
                subtitle,
                style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Cover Photo Preview Card
  Widget _buildCoverPhotoPreview() {
    return Container(
      height: 165,
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF0D9488), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14.5),
              child: AppNetworkImage(
                imageUrl: _carouselImages.first,
                fit: BoxFit.cover,
              ),
            ),
          ),
          // Cover Badge
          Positioned(
            top: 10,
            left: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF0D9488),
                borderRadius: BorderRadius.circular(20),
                boxShadow: const [
                  BoxShadow(color: Colors.black26, blurRadius: 4),
                ],
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.star, size: 13, color: Colors.white),
                  SizedBox(width: 4),
                  Text(
                    'Cover Photo / প্রধান ছবি',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Remove button
          Positioned(
            top: 10,
            right: 10,
            child: InkWell(
              onTap: () => _removePhoto(0),
              child: Container(
                padding: const EdgeInsets.all(5),
                decoration: const BoxDecoration(
                  color: Colors.black54,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.close_rounded,
                  size: 16,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          // Re-upload / Replace Cover Photo button + upload status indicator
          Positioned(
            bottom: 10,
            right: 10,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_pendingUploads.containsKey(_carouselImages.first))
                  Container(
                    margin: const EdgeInsets.only(right: 6),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black87,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 11,
                          height: 11,
                          child: CircularProgressIndicator(
                            strokeWidth: 1.8,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(width: 5),
                        Text(
                          'Uploading...',
                          style: TextStyle(color: Colors.white, fontSize: 10),
                        ),
                      ],
                    ),
                  ),
                Material(
                  color: Colors.black.withOpacity(0.72),
                  borderRadius: BorderRadius.circular(20),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: _isProcessingImage
                        ? null
                        : () => _pickFromGallery(replaceCover: true),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.photo_camera_outlined,
                            size: 13,
                            color: Colors.white,
                          ),
                          SizedBox(width: 5),
                          Text(
                            'Replace Photo / বদলান',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Modern Drag & Drop Zone Card with Dashed Border
  Widget _buildDropZoneCard() {
    return CustomPaint(
      painter: _DashedBorderPainter(
        color: const Color(0xFF0D9488).withOpacity(0.5),
        dashWidth: 6,
        dashSpace: 4,
        radius: 14,
      ),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFFF0FDFA),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0D9488).withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.cloud_upload_outlined,
                    color: Color(0xFF0D9488),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'Drag & Drop photos or choose file',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F766E),
                        ),
                      ),
                      Text(
                        'ছবি এখানে ড্র্যাগ করুন অথবা নিচে গ্যালারি/ক্যামেরা থেকে নির্বাচন করুন',
                        style: TextStyle(
                          fontSize: 10.5,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Quick Source Action Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF0D9488),
                      side: const BorderSide(color: Color(0xFF0D9488)),
                      padding: const EdgeInsets.symmetric(vertical: 9),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      backgroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.photo_library_outlined, size: 16),
                    label: const Text(
                      'Gallery / গ্যালারি',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
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
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      backgroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.camera_alt_outlined, size: 16),
                    label: const Text(
                      'Camera / ক্যামেরা',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    onPressed: _isProcessingImage ? null : _takePhoto,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: 'Upload New Gallery / নতুন গ্যালারি',
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.white,
                    side: const BorderSide(color: Color(0xFF0D9488)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  icon: const Icon(
                    Icons.collections_outlined,
                    size: 18,
                    color: Color(0xFF0D9488),
                  ),
                  onPressed: _isProcessingImage ? null : _replaceWithNewGallery,
                ),
                const SizedBox(width: 6),
                IconButton(
                  tooltip: 'Add from Web URL',
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.white,
                    side: const BorderSide(color: Color(0xFFCBD5E1)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  icon: Icon(
                    _showUrlField ? Icons.link_off_rounded : Icons.link_rounded,
                    size: 18,
                    color: const Color(0xFF0D9488),
                  ),
                  onPressed: () =>
                      setState(() => _showUrlField = !_showUrlField),
                ),
              ],
            ),

            // Optional Web URL Field
            if (_showUrlField) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 38,
                      child: TextField(
                        controller: _urlController,
                        style: const TextStyle(fontSize: 12),
                        decoration: InputDecoration(
                          hintText: 'Paste image URL (https://...)...',
                          hintStyle: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF94A3B8),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 0,
                          ),
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0D9488),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 9,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: _addFromUrl,
                    child: const Text(
                      'Add URL',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ],

            const SizedBox(height: 10),
            // Quick Sample Preset Chips
            Row(
              children: [
                const Text(
                  'Presets: ',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F766E),
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: _samplePresets.map((preset) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: ActionChip(
                            avatar: const Icon(
                              Icons.add_photo_alternate,
                              size: 13,
                              color: Color(0xFF0D9488),
                            ),
                            label: Text(
                              preset['label']!,
                              style: const TextStyle(
                                fontSize: 10,
                                color: Color(0xFF0F766E),
                              ),
                            ),
                            backgroundColor: Colors.white,
                            side: const BorderSide(color: Color(0xFFCCFBF1)),
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            onPressed: () {
                              setState(() {
                                _carouselImages.insert(0, preset['url']!);
                              });
                            },
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Interactive Photo Preview Strip (Real thumbnail previews, Cover badge, tap to set cover, remove)
  Widget _buildPhotoPreviewStrip() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'All Gallery Photos (${_carouselImages.length}):',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Color(0xFF334155),
              ),
            ),
            if (_carouselImages.length > 1)
              const Text(
                'Tap thumbnail to set as Cover',
                style: TextStyle(
                  fontSize: 10.5,
                  color: Color(0xFF0D9488),
                  fontStyle: FontStyle.italic,
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),

        SizedBox(
          height: 88,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _carouselImages.length + 1,
            separatorBuilder: (c, i) => const SizedBox(width: 8),
            itemBuilder: (ctx, idx) {
              // Last item: "Add More" card
              if (idx == _carouselImages.length) {
                return InkWell(
                  onTap: _pickFromGallery,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: 80,
                    height: 88,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFFCBD5E1),
                        style: BorderStyle.solid,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(
                          Icons.add_a_photo_outlined,
                          size: 20,
                          color: Color(0xFF0D9488),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Add More',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0D9488),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              final img = _carouselImages[idx];
              final isCover = idx == 0;

              return Stack(
                clipBehavior: Clip.none,
                children: [
                  GestureDetector(
                    onTap: () => _setAsCover(idx),
                    child: Container(
                      width: 80,
                      height: 88,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isCover
                              ? const Color(0xFF0D9488)
                              : const Color(0xFFE2E8F0),
                          width: isCover ? 2.2 : 1.0,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: AppNetworkImage(
                          imageUrl: img,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ),

                  // Cover Badge
                  if (isCover)
                    Positioned(
                      bottom: 4,
                      left: 4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0D9488),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.star, size: 9, color: Colors.white),
                            SizedBox(width: 2),
                            Text(
                              'Cover',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 8.5,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // Delete Photo Button
                  Positioned(
                    top: 3,
                    right: 3,
                    child: InkWell(
                      onTap: () => _removePhoto(idx),
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: const BoxDecoration(
                          color: Colors.black54,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.close_rounded,
                          size: 12,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildCertificationChip(
    String label,
    bool isSelected,
    ValueChanged<bool> onChanged, {
    bool isUrgent = false,
  }) {
    return FilterChip(
      label: Text(label, style: const TextStyle(fontSize: 11)),
      selected: isSelected,
      selectedColor: isUrgent
          ? const Color(0xFFFFE4E6)
          : const Color(0xFFCCFBF1),
      checkmarkColor: isUrgent
          ? const Color(0xFFE11D48)
          : const Color(0xFF0D9488),
      labelStyle: TextStyle(
        fontSize: 11,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
        color: isUrgent && isSelected
            ? const Color(0xFFE11D48)
            : (isSelected ? const Color(0xFF0F766E) : const Color(0xFF475569)),
      ),
      side: BorderSide(
        color: isSelected
            ? (isUrgent ? const Color(0xFFFDA4AF) : const Color(0xFF0D9488))
            : const Color(0xFFE2E8F0),
      ),
      onSelected: onChanged,
    );
  }

  String _getSpeciesLabel(String s) {
    switch (s) {
      case 'Dog':
        return '🐶 Dog';
      case 'Cat':
        return '🐱 Cat';
      case 'Bird':
        return '🦜 Bird';
      case 'Small':
        return '🐰 Small';
      case 'Senior':
        return '🦮 Senior';
      default:
        return s;
    }
  }

  InputDecoration _inputDecoration({
    required String label,
    required String hint,
    required IconData prefixIcon,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(prefixIcon, size: 18, color: const Color(0xFF64748B)),
      labelStyle: const TextStyle(fontSize: 12, color: Color(0xFF475569)),
      hintStyle: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFF0D9488), width: 1.5),
      ),
      filled: true,
      fillColor: const Color(0xFFFAFAFA),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    );
  }
}

/// Custom painter for crisp dashed border
class _DashedBorderPainter extends CustomPainter {
  final Color color;
  final double dashWidth;
  final double dashSpace;
  final double radius;
  static const double strokeWidth = 1.5;

  _DashedBorderPainter({
    required this.color,
    this.dashWidth = 6.0,
    this.dashSpace = 4.0,
    this.radius = 14.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Radius.circular(radius),
    );
    final path = Path()..addRRect(rrect);

    final pathMetrics = path.computeMetrics();
    for (final metric in pathMetrics) {
      double distance = 0.0;
      while (distance < metric.length) {
        final length = math.min(dashWidth, metric.length - distance);
        final extractPath = metric.extractPath(distance, distance + length);
        canvas.drawPath(extractPath, paint);
        distance += dashWidth + dashSpace;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.dashWidth != dashWidth;
}
