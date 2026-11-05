import 'package:flutter/material.dart';
import '../../../core/repositories/admin_repository.dart';

class AdoptionTrackingScreen extends StatefulWidget {
  const AdoptionTrackingScreen({super.key});

  @override
  State<AdoptionTrackingScreen> createState() => _AdoptionTrackingScreenState();
}

class _AdoptionTrackingScreenState extends State<AdoptionTrackingScreen> {
  final _adminRepo = AdminRepository();

  void _showDisputeResolutionDialog(AdoptionDisputeRecord dispute) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Mediation: ${dispute.petName} Adoption'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Adopter: ${dispute.adopterName}', style: const TextStyle(fontWeight: FontWeight.bold)),
            Text('Shelter: ${dispute.shelterName}'),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(8)),
              child: Text(dispute.issueSummary, style: const TextStyle(fontSize: 12, color: Color(0xFF334155))),
            ),
            const SizedBox(height: 12),
            const Text('Action:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 6),
            const Text('Platform administrators can mediate digital contract obligations and verify foster trial conditions.'),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF059669), foregroundColor: Colors.white),
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Mediation note logged and parties notified.')),
              );
            },
            child: const Text('Mark Resolved'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final disputes = _adminRepo.getDisputes();

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'Adoption Lifecycle, Contracts & Dispute Tracking',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Supervise digital adoption e-contracts, 14-day foster trial milestones, and dispute mediation.',
                    style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFEEF2FF),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF6366F1), width: 0.5),
                ),
                child: const Text(
                  '100% Legally Binding E-Contracts',
                  style: TextStyle(color: Color(0xFF4338CA), fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

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
                      constraints: const BoxConstraints(minWidth: 920),
                      child: DataTable(
                        headingRowColor: MaterialStateProperty.all(const Color(0xFFF8FAFC)),
                        horizontalMargin: 20,
                        columnSpacing: 24,
                        columns: const [
                          DataColumn(label: Text('CASE ID', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF475569)))),
                          DataColumn(label: Text('ADOPTER & SHELTER', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF475569)))),
                          DataColumn(label: Text('PET MATCHED', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF475569)))),
                          DataColumn(label: Text('E-CONTRACT', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF475569)))),
                          DataColumn(label: Text('FOSTER TRIAL', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF475569)))),
                          DataColumn(label: Text('STATUS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF475569)))),
                          DataColumn(label: Text('ACTION', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF475569)))),
                        ],
                        rows: disputes.map((record) {
                          return DataRow(
                            cells: [
                              DataCell(Text(record.id, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, fontFamily: 'monospace'))),
                              DataCell(
                                Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(record.adopterName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A))),
                                    Text('via ${record.shelterName}', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                                  ],
                                ),
                              ),
                              DataCell(Text(record.petName, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
                              DataCell(
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: record.contractStatus == 'Signed' ? const Color(0xFFECFDF5) : const Color(0xFFFFFBEB),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    record.contractStatus == 'Signed' ? 'Digitally Signed ✓' : record.contractStatus,
                                    style: TextStyle(
                                      color: record.contractStatus == 'Signed' ? const Color(0xFF059669) : const Color(0xFFD97706),
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                              DataCell(Text(record.trialPeriod, style: const TextStyle(fontSize: 12, color: Color(0xFF334155), fontWeight: FontWeight.w500))),
                              DataCell(
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: record.disputeStatus == 'Resolved' ? const Color(0xFFF1F5F9) : const Color(0xFFFEF3C7),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    record.disputeStatus,
                                    style: TextStyle(
                                      color: record.disputeStatus == 'Resolved' ? const Color(0xFF475569) : const Color(0xFFB45309),
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                              DataCell(
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF6366F1),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                  onPressed: () => _showDisputeResolutionDialog(record),
                                  child: const Text('Inspect Case', style: TextStyle(fontSize: 11)),
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
}

