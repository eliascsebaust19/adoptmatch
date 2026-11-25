import 'package:flutter/material.dart';

import '../../../core/models/application_model.dart';
import '../../../shared/widgets/app_network_image.dart';

// ── Admin Filled Adoption Application Form Dialog ────────────────────────────

/// Opens a modal displaying all 5 sections of an applicant's filled adoption
/// form alongside status review and approval controls.
Future<void> showFilledApplicationDialog(
  BuildContext context,
  AdoptionApplication app, {
  required Future<void> Function(ApplicationStatus status, String notes)
      onUpdateStatus,
}) {
  return showDialog<void>(
    context: context,
    builder: (ctx) => _FilledApplicationDialog(
      app: app,
      onUpdateStatus: onUpdateStatus,
    ),
  );
}

class _FilledApplicationDialog extends StatefulWidget {
  final AdoptionApplication app;
  final Future<void> Function(ApplicationStatus status, String notes)
      onUpdateStatus;

  const _FilledApplicationDialog({
    required this.app,
    required this.onUpdateStatus,
  });

  @override
  State<_FilledApplicationDialog> createState() =>
      _FilledApplicationDialogState();
}

class _FilledApplicationDialogState extends State<_FilledApplicationDialog> {
  late ApplicationStatus _selectedStatus;
  late final TextEditingController _notesController;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _selectedStatus = widget.app.status == ApplicationStatus.draft
        ? ApplicationStatus.submitted
        : widget.app.status;
    _notesController = TextEditingController(
      text: widget.app.reviewerNotes ?? '',
    );
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _submitDecision(ApplicationStatus status) async {
    setState(() => _isSaving = true);
    try {
      await widget.onUpdateStatus(status, _notesController.text.trim());
      if (mounted) {
        Navigator.of(context).pop();
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = widget.app;
    const teal = Color(0xFF0D9488);
    const slate = Color(0xFF0F172A);

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620, maxHeight: 760),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 16),
              decoration: const BoxDecoration(
                color: Color(0xFFF8FAFC),
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
              ),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: SizedBox(
                      width: 48,
                      height: 48,
                      child: AppNetworkImage(
                        imageUrl: app.petImageUrl,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Application Form • ${app.id}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: slate,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${app.petName} (${app.petBreed}) • ${app.status.displayName}',
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
                  ),
                ],
              ),
            ),

            // Scrollable Filled Application Sections
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SectionBlock(
                      title: '1. Applicant & Contact Information',
                      icon: Icons.person_outline_rounded,
                      rows: [
                        _FormFieldRow('Full Name', app.applicantName),
                        _FormFieldRow('Mobile Number', app.applicantPhone),
                        _FormFieldRow('Email Address', app.applicantEmail),
                        _FormFieldRow(
                          'NID / Passport',
                          app.nidNumber.isEmpty ? 'Not provided' : app.nidNumber,
                        ),
                        _FormFieldRow(
                          'Emergency Contact',
                          app.emergencyContactName.isEmpty
                              ? 'Not provided'
                              : '${app.emergencyContactName} (${app.emergencyContactPhone})',
                        ),
                        _FormFieldRow('Residential Address', app.address),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _SectionBlock(
                      title: '2. Housing & Living Environment',
                      icon: Icons.home_work_outlined,
                      rows: [
                        _FormFieldRow('Housing Type', app.housingType),
                        _FormFieldRow('Ownership Status', app.ownershipStatus),
                        _FormFieldRow(
                          'Landlord Allows Pets',
                          app.landlordAllowsPets ? 'Yes' : 'No',
                        ),
                        if (app.landlordContact != null &&
                            app.landlordContact!.trim().isNotEmpty)
                          _FormFieldRow('Landlord Contact', app.landlordContact!),
                        _FormFieldRow('Yard / Balcony', app.yardType),
                        _FormFieldRow('Pet Living Space', app.petLivingSpace),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _SectionBlock(
                      title: '3. Household & Experience',
                      icon: Icons.family_restroom_outlined,
                      rows: [
                        _FormFieldRow('Adults in Home', '${app.totalAdults}'),
                        _FormFieldRow(
                          'Children in Home',
                          app.hasKids
                              ? 'Yes (${app.childrenAges ?? 'unspecified'})'
                              : 'No',
                        ),
                        _FormFieldRow(
                          'Pet Allergies',
                          app.hasAllergies ? 'Yes' : 'None',
                        ),
                        _FormFieldRow(
                          'Other Pets',
                          app.hasOtherPets
                              ? (app.otherPetsDetails ?? 'Yes')
                              : 'None',
                        ),
                        _FormFieldRow('Pet Experience', app.petExperience),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _SectionBlock(
                      title: '4. Daily Care & Financial Readiness',
                      icon: Icons.volunteer_activism_outlined,
                      rows: [
                        _FormFieldRow('Daily Hours Alone', app.dailyHoursAlone),
                        _FormFieldRow('Primary Caregiver', app.primaryCaregiver),
                        _FormFieldRow(
                          'Emergency Vet Fund',
                          app.emergencyVetFund ? 'Available' : 'Not confirmed',
                        ),
                        _FormFieldRow('Monthly Pet Budget', '৳${app.monthlyBudget}'),
                        _FormFieldRow('Why Adopt', app.whyAdopt),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _SectionBlock(
                      title: '5. Declaration & Admin Review',
                      icon: Icons.verified_user_outlined,
                      rows: [
                        _FormFieldRow(
                          'Digital Signature',
                          app.isESigned
                              ? 'Signed electronically on ${app.submittedAt.toLocal().toString().split('.').first}'
                              : 'Pending signature',
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<ApplicationStatus>(
                      initialValue: _selectedStatus,
                      decoration: InputDecoration(
                        labelText: 'Application Status',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        isDense: true,
                      ),
                      items: ApplicationStatus.values
                          .where((s) => s != ApplicationStatus.draft)
                          .map(
                            (s) => DropdownMenuItem(
                              value: s,
                              child: Text(s.displayName),
                            ),
                          )
                          .toList(),
                      onChanged: _isSaving
                          ? null
                          : (val) {
                              if (val != null) {
                                setState(() => _selectedStatus = val);
                              }
                            },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _notesController,
                      maxLines: 3,
                      enabled: !_isSaving,
                      decoration: InputDecoration(
                        labelText: 'Reviewer Notes',
                        hintText: 'Add verification notes or home-visit feedback...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Footer Decision Bar
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              decoration: const BoxDecoration(
                color: Color(0xFFF8FAFC),
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
                border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
              ),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.end,
                children: [
                  TextButton(
                    onPressed:
                        _isSaving ? null : () => Navigator.of(context).pop(),
                    child: const Text('Close'),
                  ),
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFE11D48),
                      side: const BorderSide(color: Color(0xFFE11D48)),
                    ),
                    onPressed: _isSaving
                        ? null
                        : () => _submitDecision(ApplicationStatus.rejected),
                    child: const Text('Reject'),
                  ),
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: teal,
                      side: const BorderSide(color: teal),
                    ),
                    onPressed:
                        _isSaving ? null : () => _submitDecision(_selectedStatus),
                    child: const Text('Save Status'),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: teal,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: _isSaving
                        ? null
                        : () => _submitDecision(ApplicationStatus.approved),
                    child: _isSaving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Approve'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionBlock extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> rows;

  const _SectionBlock({
    required this.title,
    required this.icon,
    required this.rows,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 17, color: const Color(0xFF0D9488)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...rows,
        ],
      ),
    );
  }
}

class _FormFieldRow extends StatelessWidget {
  final String label;
  final String value;

  const _FormFieldRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 145,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF64748B),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 12.5,
                color: Color(0xFF0F172A),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
