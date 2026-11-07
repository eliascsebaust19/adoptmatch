import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../auth/bloc/auth_bloc.dart';
import '../../../core/services/storage_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/shared_widgets.dart';
import '../widgets/change_password_dialog.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _phoneController;
  late TextEditingController _locationController;
  late TextEditingController _bioController;

  String _currentAvatarUrl = '';
  String _selectedPetType = 'All Pets';
  bool _isUploadingImage = false;
  bool _isSaving = false;
  String _uploadStatusMessage = '';
  String? _inlineError;

  @override
  void initState() {
    super.initState();
    final authState = context.read<AuthBloc>().state;
    final user = authState is Authenticated ? authState.user : null;

    _nameController = TextEditingController(text: user?.name ?? '');
    _emailController = TextEditingController(text: user?.email ?? '');
    _phoneController = TextEditingController(text: user?.phone ?? '');
    _locationController = TextEditingController(
      text: user?.location ?? 'Dhaka, Bangladesh',
    );
    _bioController = TextEditingController(
      text: user?.bio ?? 'Animal lover & passionate pet rescuer',
    );
    _currentAvatarUrl = user?.avatarUrl ?? '';
    _selectedPetType = user?.preferredPetType ?? 'All Pets';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _locationController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _handleDeviceImagePick({required bool fromCamera}) async {
    final authState = context.read<AuthBloc>().state;
    final userId = authState is Authenticated ? authState.user.id : 'anon';
    final messenger = ScaffoldMessenger.of(context);
    Navigator.pop(context); // close modal

    setState(() {
      _isUploadingImage = true;
      _inlineError = null;
      _uploadStatusMessage = fromCamera
          ? 'Capturing photo...'
          : 'Selecting photo...';
    });

    try {
      final pickedFile = fromCamera
          ? await StorageService.pickImageFromCamera()
          : await StorageService.pickImageFromGallery();

      if (pickedFile == null) {
        if (mounted) setState(() => _isUploadingImage = false);
        return;
      }

      if (mounted) setState(() => _uploadStatusMessage = 'Uploading photo...');

      final bytes = await pickedFile.readAsBytes();

      final publicUrl = await StorageService.uploadProfileImage(
        bytes: bytes,
        fileName: pickedFile.name,
        userId: userId,
      );

      if (!mounted) return;
      setState(() {
        _currentAvatarUrl = publicUrl;
        _isUploadingImage = false;
      });

      messenger.showSnackBar(
        const SnackBar(
          backgroundColor: Color(0xFF059669),
          content: Text('Profile image updated successfully!'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isUploadingImage = false;
        _inlineError = 'Upload notice: $e (saved locally)';
      });
      messenger.showSnackBar(
        SnackBar(
          backgroundColor: AppColors.error,
          content: Text('Upload failed: $e'),
        ),
      );
    }
  }

  void _handleUseGooglePhoto() {
    Navigator.pop(context);

    final directPhoto = StorageService.getDirectGooglePhotoUrl();
    final photoUrl = directPhoto ?? StorageService.googleAvatarPresets.first;

    setState(() {
      _currentAvatarUrl = photoUrl;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        backgroundColor: Color(0xFF4F46E5),
        content: Text('Linked Google Profile Photo directly!'),
      ),
    );
  }

  void _showAvatarPickerBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadius.modal),
        ),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xl,
              vertical: AppSpacing.lg,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                const Text(
                  'Change Profile Photo',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.slateDark,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Upload directly to cloud storage or link your Google avatar',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),

                // Option 1: Direct Google Photo
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEEF2FF),
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: const Icon(
                      Icons.account_circle,
                      color: Color(0xFF4F46E5),
                    ),
                  ),
                  title: const Text(
                    'Use Google Profile Photo',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  subtitle: const Text(
                    'Syncs picture from your Google Account',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  trailing: const Icon(Icons.chevron_right, size: 18),
                  onTap: _handleUseGooglePhoto,
                ),
                const Divider(height: 1),

                // Option 2: Upload from Device Gallery
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF7ED),
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: const Icon(
                      Icons.photo_library_outlined,
                      color: AppColors.primary,
                    ),
                  ),
                  title: const Text(
                    'Upload from Gallery',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  subtitle: const Text(
                    'Select a high quality photo from device',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  trailing: const Icon(Icons.chevron_right, size: 18),
                  onTap: () => _handleDeviceImagePick(fromCamera: false),
                ),
                const Divider(height: 1),

                // Option 3: Camera
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: const Color(0xFFECFDF5),
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: const Icon(
                      Icons.camera_alt_outlined,
                      color: Color(0xFF10B981),
                    ),
                  ),
                  title: const Text(
                    'Take Photo with Camera',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  subtitle: const Text(
                    'Capture new photo and update immediately',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  trailing: const Icon(Icons.chevron_right, size: 18),
                  onTap: () => _handleDeviceImagePick(fromCamera: true),
                ),
                const Divider(height: 1),

                // Option 4: Presets
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: const Icon(
                      Icons.face_retouching_natural,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  title: const Text(
                    'Select Avatar Preset',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  subtitle: const Text(
                    'Choose from community animal lover avatars',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  trailing: const Icon(Icons.chevron_right, size: 18),
                  onTap: () {
                    Navigator.pop(ctx);
                    _showPresetsDialog();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showPresetsDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
        ),
        title: const Text(
          'Select Profile Avatar',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        content: SizedBox(
          width: 320,
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            alignment: WrapAlignment.center,
            children: StorageService.googleAvatarPresets.map((url) {
              return InkWell(
                onTap: () {
                  setState(() => _currentAvatarUrl = url);
                  Navigator.pop(ctx);
                },
                borderRadius: BorderRadius.circular(35),
                child: CircleAvatar(
                  radius: 32,
                  backgroundImage: AppNetworkImage.provider(url),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  Future<void> _handleSaveProfile() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSaving = true;
      _inlineError = null;
    });

    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();
    final location = _locationController.text.trim();
    final bio = _bioController.text.trim();

    try {
      context.read<AuthBloc>().add(
        UpdateUserProfileEvent(
          name: name,
          phone: phone,
          avatarUrl: _currentAvatarUrl,
          location: location,
          bio: bio,
          preferredPetType: _selectedPetType,
        ),
      );

      await Future.delayed(const Duration(milliseconds: 300));

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Color(0xFF059669),
          content: Text('Profile updated successfully!'),
        ),
      );

      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.error,
          content: Text('Failed to save profile: $e'),
        ),
      );
    }
  }

  Widget _buildAvatarWidget() {
    final hasImage = _currentAvatarUrl.isNotEmpty;
    final isBase64 = _currentAvatarUrl.startsWith('data:image');

    Widget imageChild;
    if (_isUploadingImage) {
      imageChild = Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const AppLoadingIndicator(size: 26),
          const SizedBox(height: 6),
          Text(
            _uploadStatusMessage,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 10,
              color: AppColors.slateDark,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      );
    } else if (isBase64) {
      try {
        final bytes = base64Decode(_currentAvatarUrl.split(',').last);
        imageChild = Image.memory(bytes, fit: BoxFit.cover);
      } catch (_) {
        imageChild = const Icon(
          Icons.person,
          size: 54,
          color: Color(0xFF6366F1),
        );
      }
    } else if (hasImage) {
      imageChild = AppNetworkImage(
        imageUrl: _currentAvatarUrl,
        fit: BoxFit.cover,
      );
    } else {
      imageChild = const Icon(Icons.person, size: 54, color: Color(0xFF6366F1));
    }

    return Center(
      child: Stack(
        children: [
          Container(
            width: 110,
            height: 110,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFFEEF2FF),
              border: Border.all(color: AppColors.primary, width: 2.5),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.15),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipOval(child: imageChild),
          ),
          Positioned(
            bottom: 0,
            right: 0,
            child: InkWell(
              onTap: _showAvatarPickerBottomSheet,
              child: Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 4,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.camera_alt,
                  color: Colors.white,
                  size: 18,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceScaffold,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new,
            size: 18,
            color: AppColors.slateDark,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Edit Profile',
          style: TextStyle(
            color: AppColors.slateDark,
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Avatar Header
              _buildAvatarWidget(),
              const SizedBox(height: AppSpacing.sm),

              Center(
                child: TextButton.icon(
                  onPressed: _showAvatarPickerBottomSheet,
                  icon: const Icon(
                    Icons.photo_camera_back,
                    size: 16,
                    color: AppColors.primary,
                  ),
                  label: const Text(
                    'Change Photo or Link Google Photo',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),

              if (_inlineError != null) ...[
                AppErrorBanner(
                  message: _inlineError!,
                  onDismiss: () => setState(() => _inlineError = null),
                ),
                const SizedBox(height: AppSpacing.md),
              ],

              // Form Container Card
              AppCard(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Full Name
                    AppTextField(
                      controller: _nameController,
                      label: 'Full Name',
                      hint: 'Enter your full name',
                      prefixIconData: Icons.person_outline,
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return 'Please enter your full name';
                        }
                        if (val.trim().length < 2) {
                          return 'Name must be at least 2 characters';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: AppSpacing.lg),

                    // Email (Read-only)
                    AppTextField(
                      controller: _emailController,
                      label: 'Email Address',
                      hint: 'Email',
                      readOnly: true,
                      prefixIconData: Icons.email_outlined,
                      suffixIcon: const Padding(
                        padding: EdgeInsets.only(right: 12),
                        child: Icon(
                          Icons.verified,
                          color: Color(0xFF10B981),
                          size: 18,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),

                    // Phone
                    AppTextField(
                      controller: _phoneController,
                      label: 'Phone Number',
                      hint: 'e.g. +880 1711 234567',
                      keyboardType: TextInputType.phone,
                      prefixIconData: Icons.phone_outlined,
                      validator: (val) {
                        if (val != null && val.trim().isNotEmpty) {
                          if (val.trim().length < 8) {
                            return 'Please enter a valid phone number';
                          }
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: AppSpacing.lg),

                    // City / Location
                    AppTextField(
                      controller: _locationController,
                      label: 'Location / City',
                      hint: 'e.g. Banani, Dhaka',
                      prefixIconData: Icons.location_on_outlined,
                    ),
                    const SizedBox(height: AppSpacing.lg),

                    // Bio
                    AppTextField(
                      controller: _bioController,
                      label: 'Bio / About Me',
                      hint: 'Write a short bio or rescue experience...',
                      maxLines: 3,
                    ),
                    const SizedBox(height: AppSpacing.xl),

                    // Preferred Pet Type
                    const Text(
                      'Preferred Companion Type',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Wrap(
                      spacing: 8,
                      children:
                          [
                            'All Pets',
                            'Dogs',
                            'Cats',
                            'Birds',
                            'Small Pets',
                          ].map((type) {
                            final isSelected = _selectedPetType == type;
                            return ChoiceChip(
                              label: Text(
                                type,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                  color: isSelected
                                      ? Colors.white
                                      : const Color(0xFF334155),
                                ),
                              ),
                              selected: isSelected,
                              selectedColor: AppColors.primary,
                              backgroundColor: const Color(0xFFF1F5F9),
                              onSelected: (val) {
                                  if (val) {
                                    setState(() => _selectedPetType = type);
                                  }
                              },
                            );
                          }).toList(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),

              // Security & Password Tile
              AppCard(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.md,
                ),
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: const Icon(
                      Icons.lock_reset_rounded,
                      color: AppColors.primary,
                      size: 20,
                    ),
                  ),
                  title: const Text(
                    'Change Password',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: AppColors.slateDark,
                    ),
                  ),
                  subtitle: const Text(
                    'Update your account password safely',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  trailing: const Icon(
                    Icons.arrow_forward_ios,
                    size: 14,
                    color: Color(0xFF94A3B8),
                  ),
                  onTap: () => ChangePasswordDialog.show(context),
                ),
              ),
              const SizedBox(height: AppSpacing.xxl),

              // Save Button
              AppPrimaryButton(
                text: 'Save Profile Changes',
                isLoading: _isSaving,
                icon: const Icon(Icons.check, size: 20, color: Colors.white),
                onPressed: _handleSaveProfile,
              ),
              const SizedBox(height: AppSpacing.xxl),
            ],
          ),
        ),
      ),
    );
  }
}
