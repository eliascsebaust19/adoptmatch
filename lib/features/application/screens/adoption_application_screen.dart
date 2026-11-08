import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../shared/widgets/app_network_image.dart';

import '../../../core/models/pet_model.dart';
import '../../../core/models/application_model.dart';
import '../../../core/repositories/pet_repository.dart';
import '../../../core/repositories/application_repository.dart';
import '../../../core/widgets/adoptmatch_back_button.dart';
import '../widgets/signature_canvas.dart';

class AdoptionApplicationScreen extends StatefulWidget {
  final String petId;

  const AdoptionApplicationScreen({super.key, required this.petId});

  @override
  State<AdoptionApplicationScreen> createState() =>
      _AdoptionApplicationScreenState();
}

class _AdoptionApplicationScreenState extends State<AdoptionApplicationScreen> {
  final _petRepo = PetRepository();
  final _appRepo = ApplicationRepository();
  final _formKey = GlobalKey<FormState>();

  int _currentStep = 0;
  Pet? _pet;
  bool _isLoadingPet = true;
  bool _isSubmitting = false;
  bool _hasActiveApp = false;
  String? _activeAppId;
  bool _hasDraft = false;

  // Step 1: Applicant & Contact
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _nidController = TextEditingController();
  final _emergencyNameController = TextEditingController();
  final _emergencyPhoneController = TextEditingController();
  final _addressController = TextEditingController();

  // Step 2: Living Environment
  String _housingType = 'Apartment';
  String _ownershipStatus = 'Owned';
  bool _landlordAllowsPets = true;
  final _landlordContactController = TextEditingController();
  String _yardType = 'Balcony with Safety Netting';
  String _petLivingSpace = 'Indoor Only';
  String? _step2ValidationError;

  // Step 3: Household & Existing Pets
  int _totalAdults = 1;
  bool _hasKids = false;
  final _childrenAgesController = TextEditingController();
  bool _hasAllergies = false;
  bool _hasOtherPets = false;
  final _otherPetsDetailsController = TextEditingController();
  String _petExperience = 'Experienced pet parent';

  // Step 4: Daily Care & Financial Readiness
  String _dailyHoursAlone = '2-4 hours';
  final _primaryCaregiverController = TextEditingController();
  bool _emergencyVetFund = true;
  String _monthlyBudget = '5,000 - 10,000 BDT';
  final _whyAdoptController = TextEditingController();

  // Step 5: Consent & Signature
  bool _declarationAgreed = false;
  bool _hasSignature = false;
  String? _signatureData;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    try {
      final pet = await _petRepo.getPetById(widget.petId);
      final hasActive = await _appRepo.hasActiveApplicationForPet(widget.petId);
      final apps = await _appRepo.getApplications();
      final existingApp = apps
          .where(
            (a) =>
                a.petId == widget.petId && a.status != ApplicationStatus.rejected,
          )
          .firstOrNull;

      final draft = await _appRepo.getDraft(widget.petId);

      if (!mounted) return;
      setState(() {
        _pet = pet;
        _isLoadingPet = false;
        _hasActiveApp = hasActive;
        _activeAppId = existingApp?.id;
        _hasDraft = draft != null;
      });

      if (draft != null) {
        _restoreDraft(draft);
      } else if (existingApp != null) {
        _restoreFromSubmittedApplication(existingApp);
      }
    } catch (e, stack) {
      debugPrint('ERROR in _loadInitialData: $e\n$stack');
      if (mounted) setState(() => _isLoadingPet = false);
    }
  }

  Map<String, dynamic> _buildDraftMap() {
    return {
      'name': _nameController.text,
      'phone': _phoneController.text,
      'email': _emailController.text,
      'nid': _nidController.text,
      'emergencyName': _emergencyNameController.text,
      'emergencyPhone': _emergencyPhoneController.text,
      'address': _addressController.text,
      'housingType': _housingType,
      'ownershipStatus': _ownershipStatus,
      'landlordAllowsPets': _landlordAllowsPets,
      'landlordContact': _landlordContactController.text,
      'yardType': _yardType,
      'petLivingSpace': _petLivingSpace,
      'totalAdults': _totalAdults,
      'hasKids': _hasKids,
      'childrenAges': _childrenAgesController.text,
      'hasAllergies': _hasAllergies,
      'hasOtherPets': _hasOtherPets,
      'otherPetsDetails': _otherPetsDetailsController.text,
      'dailyHoursAlone': _dailyHoursAlone,
      'primaryCaregiver': _primaryCaregiverController.text,
      'petExperience': _petExperience,
      'emergencyVetFund': _emergencyVetFund,
      'monthlyBudget': _monthlyBudget,
      'whyAdopt': _whyAdoptController.text,
      'currentStep': _currentStep,
      'declarationAgreed': _declarationAgreed,
      'hasSignature': _hasSignature,
      'signatureData': _signatureData,
      'savedAt': DateTime.now().toIso8601String(),
    };
  }

  void _restoreDraft(Map<String, dynamic> draft) {
    setState(() {
      _nameController.text = draft['name'] as String? ?? _nameController.text;
      _phoneController.text = draft['phone'] as String? ?? _phoneController.text;
      _emailController.text = draft['email'] as String? ?? _emailController.text;
      _nidController.text = draft['nid'] as String? ?? _nidController.text;
      _emergencyNameController.text =
          draft['emergencyName'] as String? ?? _emergencyNameController.text;
      _emergencyPhoneController.text =
          draft['emergencyPhone'] as String? ?? _emergencyPhoneController.text;
      _addressController.text =
          draft['address'] as String? ?? _addressController.text;
      _housingType = draft['housingType'] as String? ?? _housingType;
      _ownershipStatus = draft['ownershipStatus'] as String? ?? _ownershipStatus;
      _landlordAllowsPets =
          draft['landlordAllowsPets'] as bool? ?? _landlordAllowsPets;
      _landlordContactController.text = draft['landlordContact'] as String? ??
          _landlordContactController.text;
      _yardType = draft['yardType'] as String? ?? _yardType;
      _petLivingSpace = draft['petLivingSpace'] as String? ?? _petLivingSpace;
      _totalAdults = (draft['totalAdults'] as num?)?.toInt() ?? _totalAdults;
      _hasKids = draft['hasKids'] as bool? ?? _hasKids;
      _childrenAgesController.text =
          draft['childrenAges'] as String? ?? _childrenAgesController.text;
      _hasAllergies = draft['hasAllergies'] as bool? ?? _hasAllergies;
      _hasOtherPets = draft['hasOtherPets'] as bool? ?? _hasOtherPets;
      _otherPetsDetailsController.text = draft['otherPetsDetails'] as String? ??
          _otherPetsDetailsController.text;
      _dailyHoursAlone =
          draft['dailyHoursAlone'] as String? ?? _dailyHoursAlone;
      _primaryCaregiverController.text = draft['primaryCaregiver'] as String? ??
          _primaryCaregiverController.text;
      _petExperience = draft['petExperience'] as String? ?? _petExperience;
      _emergencyVetFund =
          draft['emergencyVetFund'] as bool? ?? _emergencyVetFund;
      _monthlyBudget = draft['monthlyBudget'] as String? ?? _monthlyBudget;
      _whyAdoptController.text =
          draft['whyAdopt'] as String? ?? _whyAdoptController.text;
      if (draft['currentStep'] != null) {
        _currentStep = (draft['currentStep'] as num).toInt().clamp(0, 4);
      }
      _declarationAgreed =
          draft['declarationAgreed'] as bool? ?? _declarationAgreed;
      _signatureData = draft['signatureData'] as String? ?? _signatureData;
      _hasSignature = _signatureData != null && _signatureData!.isNotEmpty;
    });
  }

  void _restoreFromSubmittedApplication(AdoptionApplication app) {
    setState(() {
      _nameController.text = app.applicantName;
      _phoneController.text = app.applicantPhone;
      _emailController.text = app.applicantEmail;
      _nidController.text = app.nidNumber;
      _emergencyNameController.text = app.emergencyContactName;
      _emergencyPhoneController.text = app.emergencyContactPhone;
      _addressController.text = app.address;
      _housingType = app.housingType;
      _ownershipStatus = app.ownershipStatus;
      _landlordAllowsPets = app.landlordAllowsPets;
      _landlordContactController.text = app.landlordContact ?? '';
      _yardType = app.yardType;
      _petLivingSpace = app.petLivingSpace;
      _totalAdults = app.totalAdults;
      _hasKids = app.hasKids;
      _childrenAgesController.text = app.childrenAges ?? '';
      _hasAllergies = app.hasAllergies;
      _hasOtherPets = app.hasOtherPets;
      _otherPetsDetailsController.text = app.otherPetsDetails ?? '';
      _dailyHoursAlone = app.dailyHoursAlone;
      _primaryCaregiverController.text = app.primaryCaregiver;
      _petExperience = app.petExperience;
      _emergencyVetFund = app.emergencyVetFund;
      _monthlyBudget = app.monthlyBudget;
      _whyAdoptController.text = app.whyAdopt;
      _declarationAgreed = app.isESigned;
      _hasSignature = app.isESigned;
      _signatureData = app.signatureData;
    });
  }

  void _saveDraftQuietly() {
    final draft = _buildDraftMap();
    _appRepo.saveDraft(widget.petId, draft);
  }

  Future<void> _saveDraft() async {
    final draft = _buildDraftMap();
    await _appRepo.saveDraft(widget.petId, draft);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Application draft saved successfully! You can resume anytime.',
          ),
          backgroundColor: Color(0xFF0D9488),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _nidController.dispose();
    _emergencyNameController.dispose();
    _emergencyPhoneController.dispose();
    _addressController.dispose();
    _landlordContactController.dispose();
    _childrenAgesController.dispose();
    _otherPetsDetailsController.dispose();
    _primaryCaregiverController.dispose();
    _whyAdoptController.dispose();
    super.dispose();
  }

  bool _validateCurrentStep() {
    if (_currentStep == 0) {
      if (_nameController.text.trim().isEmpty) {
        _showError('Please provide your full legal name.');
        return false;
      }
      if (_phoneController.text.trim().length < 10) {
        _showError('Please provide a valid contact mobile number.');
        return false;
      }
      if (_emailController.text.trim().isEmpty || !_emailController.text.contains('@')) {
        _showError('Please provide a valid email address.'); return false;
      }
      if (_nidController.text.trim().isEmpty ||
          _emergencyNameController.text.trim().isEmpty ||
          _emergencyPhoneController.text.trim().length < 10) {
        _showError('NID/passport and a complete emergency contact are required.'); return false;
      }
      if (_addressController.text.trim().isEmpty) {
        _showError('Please provide your current residential address.');
        return false;
      }
    } else if (_currentStep == 1) {
      if (_housingType.trim().isEmpty ||
          _ownershipStatus.trim().isEmpty ||
          _yardType.trim().isEmpty ||
          _petLivingSpace.trim().isEmpty) {
        const errorMsg = 'Please select your housing conditions to proceed';
        setState(() => _step2ValidationError = errorMsg);
        _showError(errorMsg);
        return false;
      }
      if (_ownershipStatus == 'Rented' && !_landlordAllowsPets) {
        const errorMsg = 'Adoption requires written or verbal landlord pet approval.';
        setState(() => _step2ValidationError = errorMsg);
        _showError(errorMsg);
        return false;
      }
      setState(() => _step2ValidationError = null);
    } else if (_currentStep == 2) {
      if (_hasKids && _childrenAgesController.text.trim().isEmpty) {
        _showError('Please specify the ages of children in your home.');
        return false;
      }
      if (_hasOtherPets && _otherPetsDetailsController.text.trim().isEmpty) {
        _showError(
          'Please specify your current pets (species, age, vaccination status).',
        );
        return false;
      }
    } else if (_currentStep == 3) {
      if (_whyAdoptController.text.trim().length < 20) {
        _showError(
          'Please write at least a brief sentence explaining why you want to adopt.',
        );
        return false;
      }
    } else if (_currentStep == 4) {
      if (!_declarationAgreed) {
        _showError('Please check and confirm the legal adoption declaration.');
        return false;
      }
      if (!_hasSignature || _signatureData == null || _signatureData!.isEmpty) {
        _showError(
          'Please sign on the digital signature pad before submitting.',
        );
        return false;
      }
    }
    return true;
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFFE11D48),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _submitApplication() async {
    if (!_validateCurrentStep()) return;

    setState(() => _isSubmitting = true);

    final pet = _pet;
    final petName = pet?.name ?? 'Adoptable Pet';
    final petBreed = pet?.breed ?? 'Rescue';
    final petImg = pet?.imageUrl ?? '';

    final AdoptionApplication newApp;
    try {
      newApp = await _appRepo.submitApplication(
        petId: widget.petId,
        petName: petName,
        petBreed: petBreed,
        petImageUrl: petImg,
        applicantName: _nameController.text.trim(),
        applicantPhone: _phoneController.text.trim(),
        applicantEmail: _emailController.text.trim(),
        nidNumber: _nidController.text.trim(),
        emergencyContactName: _emergencyNameController.text.trim(),
        emergencyContactPhone: _emergencyPhoneController.text.trim(),
        address: _addressController.text.trim(),
        housingType: _housingType,
        ownershipStatus: _ownershipStatus,
        landlordAllowsPets: _landlordAllowsPets,
        landlordContact: _landlordContactController.text.trim(),
        yardType: _yardType,
        petLivingSpace: _petLivingSpace,
        totalAdults: _totalAdults,
        hasKids: _hasKids,
        childrenAges: _childrenAgesController.text.trim(),
        hasAllergies: _hasAllergies,
        hasOtherPets: _hasOtherPets,
        otherPetsDetails: _otherPetsDetailsController.text.trim(),
        dailyHoursAlone: _dailyHoursAlone,
        primaryCaregiver: _primaryCaregiverController.text.trim(),
        petExperience: _petExperience,
        emergencyVetFund: _emergencyVetFund,
        monthlyBudget: _monthlyBudget,
        whyAdopt: _whyAdoptController.text.trim(),
        signatureData: _signatureData,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Application not submitted: $e'),
          backgroundColor: const Color(0xFFE11D48),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = false);

    if (!mounted) return;

    // Show Confirmation Dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        contentPadding: const EdgeInsets.all(24),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: const BoxDecoration(
                color: Color(0xFFDCFCE7),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle_rounded,
                color: Color(0xFF16A34A),
                size: 48,
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Application Submitted!',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Your application for $petName has been officially recorded under Reference ${newApp.id}.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF64748B),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Row(
                    children: const [
                      Icon(
                        Icons.schedule_rounded,
                        size: 16,
                        color: Color(0xFF0D9488),
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Review Time: 24 to 48 Hours',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: const [
                      Icon(
                        Icons.mark_chat_unread_rounded,
                        size: 16,
                        color: Color(0xFF0D9488),
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Direct updates will appear in your Application Tracker & In-App Chat.',
                          style: TextStyle(
                            fontSize: 11,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  context.push('/applications');
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0D9488),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text(
                  'Track Application',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                context.go('/home');
              },
              child: const Text(
                'Back to Discover',
                style: TextStyle(color: Color(0xFF64748B)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const teal = Color(0xFF0D9488);
    const slateDark = Color(0xFF0F172A);

    if (_isLoadingPet) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: teal)),
      );
    }

    final pet = _pet;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        leading: AdoptMatchBackButton(
          fallbackPath: widget.petId.isNotEmpty ? '/pets/${widget.petId}' : '/home',
        ),
        title: Text(
          pet != null ? 'Adopt ${pet.name}' : 'Adoption Application',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        actions: [
          TextButton.icon(
            onPressed: _saveDraft,
            icon: const Icon(
              Icons.bookmark_border_rounded,
              size: 18,
              color: teal,
            ),
            label: const Text(
              'Save Draft',
              style: TextStyle(color: teal, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
            // Active Application Warning Banner if already applied
            if (_hasActiveApp)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                color: const Color(0xFFFEF3C7),
                child: Row(
                  children: [
                    const Icon(
                      Icons.info_outline,
                      color: Color(0xFFD97706),
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'You already have an active application (${_activeAppId ?? 'Pending'}) for ${pet?.name ?? 'this pet'}.',
                        style: const TextStyle(
                          color: Color(0xFF92400E),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () => context.push('/applications'),
                      child: const Text(
                        'View Status',
                        style: TextStyle(
                          color: Color(0xFFD97706),
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // Draft Restored Banner
            if (_hasDraft)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 6,
                ),
                color: const Color(0xFFCCFBF1),
                child: Row(
                  children: [
                    const Icon(
                      Icons.restore,
                      color: Color(0xFF0F766E),
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Restored your previously saved draft.',
                        style: TextStyle(
                          color: Color(0xFF0F766E),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.close,
                        size: 16,
                        color: Color(0xFF0F766E),
                      ),
                      onPressed: () => setState(() => _hasDraft = false),
                    ),
                  ],
                ),
              ),

            // Top Pet Summary Card
            if (pet != null)
              Container(
                margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: SizedBox(
                        width: 54,
                        height: 54,
                        child: AppNetworkImage(
                          imageUrl: pet.imageUrl,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                pet.name,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: slateDark,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFDCFCE7),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  '${pet.matchScore}% Match',
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF16A34A),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${pet.breed} • ${pet.ageDisplay} • ${pet.shelterName}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

            // Step Progress Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                children: List.generate(5, (index) {
                  final isDone = index < _currentStep;
                  final isCurrent = index == _currentStep;
                  return Expanded(
                    child: Container(
                      height: 4,
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      decoration: BoxDecoration(
                        color: isDone || isCurrent
                            ? teal
                            : const Color(0xFFE2E8F0),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  );
                }),
              ),
            ),

            // Stepper Step Title Banner
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      _getStepTitle(_currentStep),
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: slateDark,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Step ${_currentStep + 1} of 5',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: teal,
                    ),
                  ),
                ],
              ),
            ),

            const Divider(height: 1, color: Color(0xFFE2E8F0)),

            // Active Step Content
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              child: _buildStepContent(_currentStep),
            ),
          ],
        ),
      ),
    ),
    bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: const Border(
            top: BorderSide(color: Color(0xFFE2E8F0), width: 1),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 10,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
        child: SafeArea(
          top: false,
          child: _buildStepNavigationButtons(teal, slateDark),
        ),
      ),
    );
  }

  Widget _buildStepNavigationButtons(Color teal, Color slateDark) {
    return Row(
      children: [
        if (_currentStep > 0) ...[
          Expanded(
            flex: 1,
            child: OutlinedButton.icon(
              onPressed: () {
                setState(() {
                  _currentStep--;
                  _step2ValidationError = null;
                });
                _saveDraftQuietly();
              },
              icon: const Icon(Icons.arrow_back_rounded, size: 18),
              label: const Text(
                'Back',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: slateDark,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                side: const BorderSide(color: Color(0xFFCBD5E1), width: 1.5),
              ),
            ),
          ),
          const SizedBox(width: 12),
        ],
        Expanded(
          flex: _currentStep > 0 ? 2 : 1,
          child: ElevatedButton.icon(
            onPressed: _isSubmitting
                ? null
                : () {
                    if (!_validateCurrentStep()) return;
                    if (_currentStep < 4) {
                      setState(() {
                        _currentStep++;
                        _step2ValidationError = null;
                      });
                      _saveDraftQuietly();
                    } else {
                      _submitApplication();
                    }
                  },
            icon: _isSubmitting
                ? const SizedBox.shrink()
                : const Icon(
                    Icons.arrow_forward_rounded,
                    size: 18,
                    color: Colors.white,
                  ),
            label: _isSubmitting
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2.5,
                    ),
                  )
                : Text(
                    _currentStep == 4
                        ? 'Submit Adoption Dossier'
                        : 'Continue to Step ${_currentStep + 2}',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
            style: ElevatedButton.styleFrom(
              backgroundColor: teal,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              elevation: 0,
            ),
          ),
        ),
      ],
    );
  }

  String _getStepTitle(int step) {
    switch (step) {
      case 0:
        return '1. Applicant & Identification';
      case 1:
        return '2. Housing & Environment';
      case 2:
        return '3. Household & Existing Pets';
      case 3:
        return '4. Daily Care & Vet Readiness';
      case 4:
        return '5. Legal Agreement & Signature';
      default:
        return '';
    }
  }

  Widget _buildStepContent(int step) {
    switch (step) {
      case 0:
        return _buildStep1ApplicantInfo();
      case 1:
        return _buildStep2HousingEnvironment();
      case 2:
        return _buildStep3HouseholdAndPets();
      case 3:
        return _buildStep4CareAndFinancialReadiness();
      case 4:
        return _buildStep5ConsentAndSignature();
      default:
        return const SizedBox.shrink();
    }
  }

  // --- Step 1: Applicant & Contact ---
  Widget _buildStep1ApplicantInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          'Primary Contact Information',
          'This information will be verified by the shelter adoption committee.',
        ),
        const SizedBox(height: 16),
        _buildTextField(
          controller: _nameController,
          label: 'Full Legal Name *',
          icon: Icons.person_outline,
          hint: 'e.g. Tanvir Ahmed',
        ),
        const SizedBox(height: 14),
        _buildTextField(
          controller: _phoneController,
          label: 'Mobile Contact Number *',
          icon: Icons.phone_outlined,
          hint: '+880 1711 234567',
          keyboardType: TextInputType.phone,
        ),
        const SizedBox(height: 14),
        _buildTextField(
          controller: _emailController,
          label: 'Email Address *',
          icon: Icons.email_outlined,
          hint: 'user@example.com',
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: 14),
        _buildTextField(
          controller: _nidController,
          label: 'National ID (NID) / Passport Number *',
          icon: Icons.badge_outlined,
          hint: '10, 13, or 17 digit NID',
        ),
        const SizedBox(height: 20),
        _buildSectionHeader(
          'Emergency Contact Person',
          'A secondary contact in case of emergency.',
        ),
        const SizedBox(height: 14),
        _buildTextField(
          controller: _emergencyNameController,
          label: 'Emergency Contact Name & Relation',
          icon: Icons.contact_emergency_outlined,
          hint: 'e.g. Farhana Ahmed (Spouse)',
        ),
        const SizedBox(height: 14),
        _buildTextField(
          controller: _emergencyPhoneController,
          label: 'Emergency Contact Phone',
          icon: Icons.phone_callback_outlined,
          hint: '+880 1812 345678',
          keyboardType: TextInputType.phone,
        ),
        const SizedBox(height: 20),
        _buildSectionHeader(
          'Current Residential Address',
          'Full physical address where the pet will permanently live.',
        ),
        const SizedBox(height: 14),
        _buildTextField(
          controller: _addressController,
          label: 'Present Living Address *',
          icon: Icons.home_outlined,
          hint: 'Flat, House, Road, Area, Dhaka',
          maxLines: 2,
        ),
      ],
    );
  }

  // --- Step 2: Housing & Environment ---
  Widget _buildStep2HousingEnvironment() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Inline Validation Error Feedback
        if (_step2ValidationError != null) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF2F2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFFECACA)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.error_outline_rounded,
                  color: Color(0xFFDC2626),
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _step2ValidationError!,
                    style: const TextStyle(
                      color: Color(0xFFB91C1C),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],

        _buildSectionHeader(
          'Type of Residence',
          'Select the dwelling where the pet will be sheltered.',
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: ['Apartment', 'Independent House', 'Duplex', 'Villa'].map((
            type,
          ) {
            final isSelected = _housingType == type;
            return ChoiceChip(
              label: Text(type),
              selected: isSelected,
              selectedColor: const Color(0xFFCCFBF1),
              backgroundColor: Colors.white,
              labelStyle: TextStyle(
                color: isSelected
                    ? const Color(0xFF0F766E)
                    : const Color(0xFF334155),
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              ),
              side: BorderSide(
                color: isSelected
                    ? const Color(0xFF0D9488)
                    : const Color(0xFFCBD5E1),
              ),
              onSelected: (selected) => setState(() {
                _housingType = selected ? type : '';
                _step2ValidationError = null;
              }),
            );
          }).toList(),
        ),
        const SizedBox(height: 24),
        _buildSectionHeader(
          'Home Ownership Status',
          'Rented residences require landlord animal clearance.',
        ),
        const SizedBox(height: 12),
        Row(
          children: ['Owned', 'Rented'].map((status) {
            final isSelected = _ownershipStatus == status;
            return Expanded(
              child: GestureDetector(
                onTap: () => setState(() {
                  _ownershipStatus = status;
                  _step2ValidationError = null;
                }),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFFF0FDFA) : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected
                          ? const Color(0xFF0D9488)
                          : const Color(0xFFCBD5E1),
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    status,
                    style: TextStyle(
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.w600,
                      color: isSelected
                          ? const Color(0xFF0F766E)
                          : const Color(0xFF475569),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),

        // Conditional Landlord Section
        if (_ownershipStatus == 'Rented') ...[
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF2F2),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFFECACA)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text(
                    'Landlord Permitted Pets in Lease',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF991B1B),
                    ),
                  ),
                  subtitle: const Text(
                    'Does your tenancy agreement permit dogs or cats on premises?',
                    style: TextStyle(fontSize: 12, color: Color(0xFF7F1D1D)),
                  ),
                  value: _landlordAllowsPets,
                  activeColor: const Color(0xFFE11D48),
                  onChanged: (val) => setState(() {
                    _landlordAllowsPets = val;
                    _step2ValidationError = null;
                  }),
                ),
                if (_landlordAllowsPets) ...[
                  const SizedBox(height: 8),
                  _buildTextField(
                    controller: _landlordContactController,
                    label: 'Landlord / Building Manager Contact (Optional)',
                    icon: Icons.phone_android_outlined,
                    hint: '+880 1... (for verbal confirmation)',
                  ),
                ],
              ],
            ),
          ),
        ],

        const SizedBox(height: 24),
        _buildSectionHeader(
          'Outdoor Space & Yard Security',
          'Security of perimeter boundaries for the pet.',
        ),
        const SizedBox(height: 12),
        ...[
          'Private Fenced Yard',
          'Balcony with Safety Netting',
          'Communal Garden Area',
          'No Outdoor Yard',
        ].map((yard) {
          final isSelected = _yardType == yard;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: InkWell(
              onTap: () {
                setState(() {
                  _yardType = yard;
                  _step2ValidationError = null;
                });
              },
              borderRadius: BorderRadius.circular(12),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFFF0FDFA) : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected
                        ? const Color(0xFF0D9488)
                        : const Color(0xFFCBD5E1),
                    width: isSelected ? 1.8 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected
                              ? const Color(0xFF0D9488)
                              : const Color(0xFF94A3B8),
                          width: 2,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: isSelected
                          ? Container(
                              width: 10,
                              height: 10,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Color(0xFF0D9488),
                              ),
                            )
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        yard,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight:
                              isSelected ? FontWeight.w700 : FontWeight.w500,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),

        const SizedBox(height: 16),
        _buildSectionHeader(
          'Pet Primary Living Arrangement',
          'Where will the pet spend the majority of its day?',
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children:
              [
                'Indoor Only',
                'Indoor with Yard Access',
                'Outdoor Protected',
              ].map((space) {
                final isSelected = _petLivingSpace == space;
                return ChoiceChip(
                  label: Text(space),
                  selected: isSelected,
                  selectedColor: const Color(0xFFCCFBF1),
                  backgroundColor: Colors.white,
                  labelStyle: TextStyle(
                    color: isSelected
                        ? const Color(0xFF0F766E)
                        : const Color(0xFF334155),
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  ),
                  side: BorderSide(
                    color: isSelected
                        ? const Color(0xFF0D9488)
                        : const Color(0xFFCBD5E1),
                  ),
                  onSelected: (selected) => setState(() {
                    _petLivingSpace = selected ? space : '';
                    _step2ValidationError = null;
                  }),
                );
              }).toList(),
        ),
      ],
    );
  }

  // --- Step 3: Household & Existing Pets ---
  Widget _buildStep3HouseholdAndPets() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          'Household Members',
          'Who shares your residence on a daily basis?',
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Total Adults in Household:',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline),
                    onPressed: _totalAdults > 1
                        ? () => setState(() => _totalAdults--)
                        : null,
                  ),
                  Text(
                    '$_totalAdults',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline),
                    onPressed: () => setState(() => _totalAdults++),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text(
                  'Are there children in the home?',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
                value: _hasKids,
                activeColor: const Color(0xFF0D9488),
                onChanged: (val) => setState(() => _hasKids = val),
              ),
              if (_hasKids) ...[
                const SizedBox(height: 10),
                _buildTextField(
                  controller: _childrenAgesController,
                  label: 'Ages of Children *',
                  icon: Icons.child_care_outlined,
                  hint: 'e.g. 4 and 7 years old',
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text(
              'Does anyone in the family have pet allergies?',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
            value: _hasAllergies,
            activeColor: const Color(0xFF0D9488),
            onChanged: (val) => setState(() => _hasAllergies = val),
          ),
        ),
        const SizedBox(height: 20),
        _buildSectionHeader(
          'Current Pets in Home',
          'Ensure cross-compatibility and vaccine safety.',
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text(
                  'Do you currently own other pets?',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
                value: _hasOtherPets,
                activeColor: const Color(0xFF0D9488),
                onChanged: (val) => setState(() => _hasOtherPets = val),
              ),
              if (_hasOtherPets) ...[
                const SizedBox(height: 10),
                _buildTextField(
                  controller: _otherPetsDetailsController,
                  label: 'Details of Current Pets *',
                  icon: Icons.pets_outlined,
                  hint: 'e.g. 1 vaccinated indoor cat (3 yrs, spayed)',
                  maxLines: 2,
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 20),
        _buildSectionHeader(
          'Previous Pet Ownership Experience',
          'Your familiarity with animal behaviour and routine care.',
        ),
        const SizedBox(height: 12),
        ...[
          'First-time pet parent',
          'Experienced pet parent',
          'Experienced foster parent / rescuer',
        ].map((exp) {
          final isSelected = _petExperience == exp;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: InkWell(
              onTap: () => setState(() => _petExperience = exp),
              borderRadius: BorderRadius.circular(12),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFFF0FDFA) : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected
                        ? const Color(0xFF0D9488)
                        : const Color(0xFFCBD5E1),
                    width: isSelected ? 1.8 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected
                              ? const Color(0xFF0D9488)
                              : const Color(0xFF94A3B8),
                          width: 2,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: isSelected
                          ? Container(
                              width: 10,
                              height: 10,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Color(0xFF0D9488),
                              ),
                            )
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        exp,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight:
                              isSelected ? FontWeight.w700 : FontWeight.w500,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  // --- Step 4: Care & Financial Readiness ---
  Widget _buildStep4CareAndFinancialReadiness() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          'Daily Schedule & Alone Time',
          'Dogs and puppies require companionship and routine walks.',
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          children: ['Less than 2 hours', '2-4 hours', '4-6 hours', '6+ hours']
              .map((hours) {
                final isSelected = _dailyHoursAlone == hours;
                return ChoiceChip(
                  label: Text(hours),
                  selected: isSelected,
                  selectedColor: const Color(0xFFCCFBF1),
                  labelStyle: TextStyle(
                    color: isSelected
                        ? const Color(0xFF0F766E)
                        : const Color(0xFF334155),
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  ),
                  onSelected: (_) => setState(() => _dailyHoursAlone = hours),
                );
              })
              .toList(),
        ),
        const SizedBox(height: 20),
        _buildTextField(
          controller: _primaryCaregiverController,
          label: 'Primary Caregiver During Work / Travel',
          icon: Icons.family_restroom_outlined,
          hint: 'e.g. Self, spouse, live-in assistant, pet boarder',
        ),
        const SizedBox(height: 20),
        _buildSectionHeader(
          'Financial Commitment & Vet Emergencies',
          'Ethical adoption requires willingness to fund medical treatments.',
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text(
              'Emergency Veterinary Fund Ready?',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
            subtitle: const Text(
              'Are you prepared for unexpected medical emergencies (15,000+ BDT)?',
              style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
            value: _emergencyVetFund,
            activeColor: const Color(0xFF0D9488),
            onChanged: (val) => setState(() => _emergencyVetFund = val),
          ),
        ),
        const SizedBox(height: 16),
        _buildSectionHeader(
          'Estimated Monthly Pet Budget',
          'Includes food, grooming, litter/treats, and regular supplements.',
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          children: ['3,000 - 5,000 BDT', '5,000 - 10,000 BDT', '10,000+ BDT']
              .map((budget) {
                final isSelected = _monthlyBudget == budget;
                return ChoiceChip(
                  label: Text(budget),
                  selected: isSelected,
                  selectedColor: const Color(0xFFCCFBF1),
                  labelStyle: TextStyle(
                    color: isSelected
                        ? const Color(0xFF0F766E)
                        : const Color(0xFF334155),
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  ),
                  onSelected: (_) => setState(() => _monthlyBudget = budget),
                );
              })
              .toList(),
        ),
        const SizedBox(height: 24),
        _buildSectionHeader(
          'Why do you want to adopt ${_pet?.name ?? 'this pet'}? *',
          'Share your motivation and vision for this pet in your home.',
        ),
        const SizedBox(height: 12),
        _buildTextField(
          controller: _whyAdoptController,
          label: 'Your Adoption Motivation *',
          icon: Icons.volunteer_activism_outlined,
          hint: 'Describe your daily life, family environment, and commitment to this pet...',
          maxLines: 4,
        ),
      ],
    );
  }

  // --- Step 5: Legal Agreement & Digital Signature ---
  Widget _buildStep5ConsentAndSignature() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          'Review Application Details',
          'Verify your submitted information before signing and submitting.',
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildReviewRow(Icons.person_outline, 'Applicant', _nameController.text.isNotEmpty ? _nameController.text : 'Not provided'),
              const SizedBox(height: 8),
              _buildReviewRow(Icons.phone_outlined, 'Contact', '${_phoneController.text.isNotEmpty ? _phoneController.text : 'N/A'} • ${_emailController.text.isNotEmpty ? _emailController.text : ''}'),
              const SizedBox(height: 8),
              _buildReviewRow(Icons.home_outlined, 'Housing', '$_housingType ($_ownershipStatus)'),
              const SizedBox(height: 8),
              _buildReviewRow(Icons.family_restroom_outlined, 'Household', '$_totalAdults adults (${_hasKids ? 'Has young children' : 'No young children'})'),
              const SizedBox(height: 8),
              _buildReviewRow(Icons.pets_outlined, 'Other Pets', _hasOtherPets ? 'Has existing pets' : 'No other pets'),
              const SizedBox(height: 8),
              _buildReviewRow(Icons.health_and_safety_outlined, 'Emergency Fund', _emergencyVetFund ? 'Confirmed ৳15,000+ Ready' : 'Pending confirmation'),
              if (_whyAdoptController.text.isNotEmpty) ...[
                const SizedBox(height: 8),
                _buildReviewRow(Icons.favorite_outline, 'Motivation', _whyAdoptController.text),
              ],
            ],
          ),
        ),
        const SizedBox(height: 20),
        _buildSectionHeader(
          'Legal Adoption Declaration & Pledge',
          'Please review the mandatory commitments to safeguard animal welfare.',
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFCBD5E1)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              _DeclarationItem(
                number: '1',
                text: 'Lifelong Care: I commit to providing loving, permanent care throughout this pet\'s natural lifespan.',
              ),
              SizedBox(height: 10),
              _DeclarationItem(
                number: '2',
                text: 'No Abandonment: I pledge never to abandon, sell, or transfer this pet to an unauthorized third party without written shelter notice.',
              ),
              SizedBox(height: 10),
              _DeclarationItem(
                number: '3',
                text: 'Mandatory Healthcare: I will administer annual rabies, core vaccinations, and prompt treatment if ill.',
              ),
              SizedBox(height: 10),
              _DeclarationItem(
                number: '4',
                text: 'Welfare Inspection: I consent to a virtual or scheduled home check by the shelter committee during the 14-day trial period.',
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text(
            'I understand and legally agree to all adoption terms and conditions stated above.',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0F172A),
            ),
          ),
          value: _declarationAgreed,
          activeColor: const Color(0xFF0D9488),
          onChanged: (val) => setState(() => _declarationAgreed = val ?? false),
        ),
        const SizedBox(height: 20),
        _buildSectionHeader(
          'Applicant Touch E-Signature *',
          'Draw your legal signature inside the touch pad below.',
        ),
        const SizedBox(height: 12),
        SignatureCanvas(
          onSignatureChanged: (hasSig) => setState(() => _hasSignature = hasSig),
          onSignatureDataChanged: (data) => setState(() => _signatureData = data),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFF0FDF4),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFBBF7D0)),
          ),
          child: Row(
            children: const [
              Icon(
                Icons.verified_user_rounded,
                color: Color(0xFF16A34A),
                size: 18,
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Your digital signature is legally bound and encrypted with timestamp.',
                  style: TextStyle(
                    color: Color(0xFF15803D),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
        ),
      ],
    );
  }

  Widget _buildReviewRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: const Color(0xFF0D9488)),
        const SizedBox(width: 8),
        SizedBox(
          width: 90,
          child: Text(
            label,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF64748B)),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required String hint,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      style: const TextStyle(
        fontSize: 14,
        color: Color(0xFF0F172A),
        fontWeight: FontWeight.w500,
      ),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
        prefixIcon: Icon(icon, size: 20, color: const Color(0xFF0D9488)),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF0D9488), width: 1.5),
        ),
      ),
    );
  }
}

class _DeclarationItem extends StatelessWidget {
  final String number;
  final String text;

  const _DeclarationItem({required this.number, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 20,
          height: 20,
          decoration: const BoxDecoration(
            color: Color(0xFFCCFBF1),
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Text(
            number,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0F766E),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF334155),
              height: 1.3,
            ),
          ),
        ),
      ],
    );
  }
}
