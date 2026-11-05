import 'package:flutter/material.dart';
import '../../../core/repositories/admin_repository.dart';
import '../models/shelter_application_model.dart';

class ShelterApprovalScreen extends StatefulWidget {
  const ShelterApprovalScreen({super.key});

  @override
  State<ShelterApprovalScreen> createState() => _ShelterApprovalScreenState();
}

class _ShelterApprovalScreenState extends State<ShelterApprovalScreen> {
  final _adminRepo = AdminRepository();
  String _selectedTab = 'ALL';
  String _searchQuery = '';

  void _showDocumentViewerDialog(ShelterApplication shelter) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.verified_user, color: Color(0xFF6366F1)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Dossier: ${shelter.shelterName}',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: 550, maxHeight: MediaQuery.of(ctx).size.height * 0.8),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildInfoRow('Registration ID:', shelter.registrationNumber),
                _buildInfoRow('Contact Person:', shelter.contactPerson),
                _buildInfoRow('Official Phone:', shelter.phone),
                _buildInfoRow('Email Address:', shelter.email),
                _buildInfoRow('Physical Location:', '${shelter.address}, ${shelter.city}'),
                _buildInfoRow('Verified NID Number:', shelter.nidNumber),
                _buildInfoRow('Trade License No:', shelter.tradeLicenseNumber),
                _buildInfoRow('Affiliated Vet Clinic:', shelter.vetAffiliation),
                _buildInfoRow('Capacity:', '${shelter.capacity} rescue animals'),
                const SizedBox(height: 14),
                const Text(
                  'Attached Compliance Proofs:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1E293B)),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    children: const [
                      Icon(Icons.description, color: Color(0xFF6366F1), size: 28),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Government Trade License & Veterinary Certificate (Verified via DNCC Database)',
                          style: TextStyle(fontSize: 12, color: Color(0xFF334155)),
                        ),
                      ),
                    ],
                  ),
                ),
                if (shelter.reviewerNotes != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      'Reviewer Notes: ${shelter.reviewerNotes}',
                      style: const TextStyle(fontSize: 12, color: Color(0xFF1E40AF)),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
          if (shelter.status == VerificationStatus.pending) ...[
            OutlinedButton(
              style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFFE11D48)),
              onPressed: () {
                Navigator.pop(ctx);
                _showRejectDialog(shelter);
              },
              child: const Text('Reject Application'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF059669),
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                Navigator.pop(ctx);
                _adminRepo.approveShelter(shelter.id);
                setState(() {});
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('${shelter.shelterName} has been approved!')),
                );
              },
              child: const Text('Approve Shelter'),
            ),
          ],
        ],
      ),
    );
  }

  void _showRejectDialog(ShelterApplication shelter) {
    final reasonCtrl = TextEditingController(text: 'Document discrepancies in trade license.');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Reject ${shelter.shelterName}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Please provide a formal rejection rationale for the applicant:',
              style: TextStyle(fontSize: 13, color: Color(0xFF475569)),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: reasonCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Reason for rejection...',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE11D48), foregroundColor: Colors.white),
            onPressed: () {
              Navigator.pop(ctx);
              _adminRepo.rejectShelter(shelter.id, reason: reasonCtrl.text.trim());
              setState(() {});
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('${shelter.shelterName} rejected.')),
              );
            },
            child: const Text('Confirm Rejection'),
          ),
        ],
      ),
    ).then((_) => reasonCtrl.dispose());
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 160,
            child: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 12, color: Color(0xFF0F172A), fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final allShelters = _adminRepo.getShelters();

    final filtered = allShelters.where((s) {
      if (_selectedTab == 'PENDING' && s.status != VerificationStatus.pending) return false;
      if (_selectedTab == 'APPROVED' && s.status != VerificationStatus.approved) return false;
      if (_selectedTab == 'REJECTED' && s.status != VerificationStatus.rejected) return false;

      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final match = s.shelterName.toLowerCase().contains(q) ||
            s.contactPerson.toLowerCase().contains(q) ||
            s.registrationNumber.toLowerCase().contains(q) ||
            s.city.toLowerCase().contains(q);
        if (!match) return false;
      }
      return true;
    }).toList();

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'Shelter & Organization Verification Queue',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Audit government licenses, NID identity, and veterinarian backing prior to listing rescues.',
                    style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFF59E0B), width: 0.5),
                ),
                child: Text(
                  '${allShelters.where((s) => s.status == VerificationStatus.pending).length} Pending Review',
                  style: const TextStyle(color: Color(0xFF92400E), fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Filters & Search Bar
          Row(
            children: [
              _buildFilterChip('ALL', 'All Registrations (${allShelters.length})'),
              const SizedBox(width: 8),
              _buildFilterChip('PENDING', 'Pending (${allShelters.where((s) => s.status == VerificationStatus.pending).length})'),
              const SizedBox(width: 8),
              _buildFilterChip('APPROVED', 'Approved (${allShelters.where((s) => s.status == VerificationStatus.approved).length})'),
              const SizedBox(width: 8),
              _buildFilterChip('REJECTED', 'Rejected'),
              const Spacer(),
              SizedBox(
                width: 260,
                height: 40,
                child: TextField(
                  onChanged: (val) => setState(() => _searchQuery = val.trim()),
                  style: const TextStyle(fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Search shelter, city, reg ID...',
                    hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                    prefixIcon: const Icon(Icons.search, size: 18, color: Color(0xFF94A3B8)),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Primary Data Table Card
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.02),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: SingleChildScrollView(
                  scrollDirection: Axis.vertical,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minWidth: 920),
                      child: DataTable(
                        headingRowColor: MaterialStateProperty.all(const Color(0xFFF8FAFC)),
                        horizontalMargin: 20,
                        columnSpacing: 24,
                        columns: const [
                          DataColumn(label: Text('SHELTER / ORG', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF475569)))),
                          DataColumn(label: Text('REGISTRATION ID', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF475569)))),
                          DataColumn(label: Text('CONTACT PERSON', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF475569)))),
                          DataColumn(label: Text('LOCATION', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF475569)))),
                          DataColumn(label: Text('DOCUMENTS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF475569)))),
                          DataColumn(label: Text('STATUS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF475569)))),
                          DataColumn(label: Text('ACTIONS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF475569)))),
                        ],
                        rows: filtered.map((shelter) {
                          return DataRow(
                            cells: [
                              DataCell(
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFEEF2FF),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Icon(Icons.pets, size: 16, color: Color(0xFF6366F1)),
                                    ),
                                    const SizedBox(width: 10),
                                    Text(
                                      shelter.shelterName,
                                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF0F172A)),
                                    ),
                                  ],
                                ),
                              ),
                              DataCell(Text(shelter.registrationNumber, style: const TextStyle(fontSize: 12, color: Color(0xFF475569), fontFamily: 'monospace'))),
                              DataCell(
                                Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(shelter.contactPerson, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                                    Text(shelter.phone, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                                  ],
                                ),
                              ),
                              DataCell(Text(shelter.city, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500))),
                              DataCell(
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(color: const Color(0xFFECFDF5), borderRadius: BorderRadius.circular(4)),
                                      child: const Text('NID ✓', style: TextStyle(color: Color(0xFF059669), fontSize: 10, fontWeight: FontWeight.bold)),
                                    ),
                                    const SizedBox(width: 4),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(4)),
                                      child: const Text('Trade Lic ✓', style: TextStyle(color: Color(0xFF2563EB), fontSize: 10, fontWeight: FontWeight.bold)),
                                    ),
                                  ],
                                ),
                              ),
                              DataCell(_buildStatusBadge(shelter.status)),
                              DataCell(
                                Row(
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.remove_red_eye_outlined, size: 18, color: Color(0xFF6366F1)),
                                      tooltip: 'View Documents',
                                      onPressed: () => _showDocumentViewerDialog(shelter),
                                    ),
                                    if (shelter.status == VerificationStatus.pending) ...[
                                      IconButton(
                                        icon: const Icon(Icons.check_circle_outline, size: 18, color: Color(0xFF059669)),
                                        tooltip: 'Approve',
                                        onPressed: () {
                                          _adminRepo.approveShelter(shelter.id);
                                          setState(() {});
                                        },
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.cancel_outlined, size: 18, color: Color(0xFFE11D48)),
                                        tooltip: 'Reject',
                                        onPressed: () => _showRejectDialog(shelter),
                                      ),
                                    ],
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
    final isSelected = _selectedTab == key;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => setState(() => _selectedTab = key),
      selectedColor: const Color(0xFF6366F1),
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : const Color(0xFF475569),
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
      ),
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      side: BorderSide(color: isSelected ? const Color(0xFF6366F1) : const Color(0xFFE2E8F0)),
    );
  }

  Widget _buildStatusBadge(VerificationStatus status) {
    Color bg;
    Color fg;
    String label;

    switch (status) {
      case VerificationStatus.approved:
        bg = const Color(0xFFECFDF5);
        fg = const Color(0xFF059669);
        label = 'Approved';
        break;
      case VerificationStatus.rejected:
        bg = const Color(0xFFFFF1F2);
        fg = const Color(0xFFE11D48);
        label = 'Rejected';
        break;
      case VerificationStatus.pending:
        bg = const Color(0xFFFFFBEB);
        fg = const Color(0xFFD97706);
        label = 'Pending Review';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(label, style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.w700)),
    );
  }
}

