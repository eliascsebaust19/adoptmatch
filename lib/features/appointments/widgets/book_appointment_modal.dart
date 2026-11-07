import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/models/appointment_model.dart';
import '../../../core/models/pet_model.dart';
import '../../../core/repositories/appointment_repository.dart';
import '../../auth/bloc/auth_bloc.dart';

class BookAppointmentModal extends StatefulWidget {
  final Pet pet;

  const BookAppointmentModal({super.key, required this.pet});

  @override
  State<BookAppointmentModal> createState() => _BookAppointmentModalState();
}

class _BookAppointmentModalState extends State<BookAppointmentModal> {
  final _aptRepo = AppointmentRepository();
  final _notesController = TextEditingController();

  DateTime _selectedDate = DateTime.now().add(const Duration(days: 1));
  String _selectedSlot = '10:00 AM - 11:00 AM';
  AppointmentType _selectedType = AppointmentType.meetAndGreet;
  bool _isBooking = false;
  String? _errorMessage;

  final List<String> _timeSlots = [
    '10:00 AM - 11:00 AM',
    '11:30 AM - 12:30 PM',
    '02:30 PM - 03:30 PM',
    '04:00 PM - 05:00 PM',
    '05:30 PM - 06:30 PM',
  ];

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().add(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );
    if (picked != null) {
      if (!mounted) return;
      setState(() {
        _selectedDate = picked;
        _errorMessage = null;
      });
    }
  }

  Future<void> _submitBooking() async {
    setState(() {
      _isBooking = true;
      _errorMessage = null;
    });

    final authState = context.read<AuthBloc>().state;
    final userName = authState is Authenticated ? authState.user.name : 'Adopter';
    final userPhone = authState is Authenticated ? authState.user.phone : '';

    try {
      await _aptRepo.bookAppointment(
        petId: widget.pet.id,
        petName: widget.pet.name,
        petImageUrl: widget.pet.imageUrl,
        shelterName: widget.pet.shelterName,
        shelterPhone: widget.pet.shelterPhone,
        shelterAddress: widget.pet.shelterAddress,
        applicantName: userName,
        applicantPhone: userPhone,
        date: _selectedDate,
        timeSlot: _selectedSlot,
        type: _selectedType,
        notes: _notesController.text.trim(),
      );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('🎉 Appointment requested with ${widget.pet.shelterName}!'),
            backgroundColor: const Color(0xFF0D9488),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isBooking = false;
          _errorMessage = e.toString().replaceAll('Exception: ', '');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const teal = Color(0xFF0D9488);
    const slateDark = Color(0xFF0F172A);

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: teal.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.event_available_rounded, color: teal, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Schedule Meet & Greet',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: slateDark),
                      ),
                      Text(
                        'With ${widget.pet.name} at ${widget.pet.shelterName}',
                        style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            if (_errorMessage != null)
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFE4E6),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFDA4AF)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: Color(0xFFE11D48), size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(color: Color(0xFF9F1239), fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),

            // Appointment Type Selection
            const Text('Meeting Type', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: slateDark)),
            const SizedBox(height: 8),
            DropdownButtonFormField<AppointmentType>(
              value: _selectedType,
              decoration: InputDecoration(
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              items: AppointmentType.values.map((t) {
                return DropdownMenuItem(value: t, child: Text(t.displayName, style: const TextStyle(fontSize: 13)));
              }).toList(),
              onChanged: (val) => setState(() => _selectedType = val!),
            ),
            const SizedBox(height: 16),

            // Date Picker Card
            const Text('Select Date', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: slateDark)),
            const SizedBox(height: 8),
            InkWell(
              onTap: _pickDate,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFFCBD5E1)),
                  borderRadius: BorderRadius.circular(12),
                  color: Colors.white,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.calendar_month_rounded, color: teal, size: 20),
                        const SizedBox(width: 10),
                        Text(
                          '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: slateDark),
                        ),
                      ],
                    ),
                    const Text('Change', style: TextStyle(color: teal, fontWeight: FontWeight.bold, fontSize: 13)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Available Time Slots
            const Text('Available Time Slot', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: slateDark)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _timeSlots.map((slot) {
                final isSelected = _selectedSlot == slot;
                return ChoiceChip(
                  label: Text(slot),
                  selected: isSelected,
                  selectedColor: const Color(0xFFCCFBF1),
                  labelStyle: TextStyle(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    color: isSelected ? teal : const Color(0xFF475569),
                  ),
                  onSelected: (val) {
                    if (val) setState(() => _selectedSlot = slot);
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            // Optional note
            TextField(
              controller: _notesController,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: 'Special Requests / Notes (Optional)',
                hintText: 'e.g. Bringing children, transportation queries...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 24),

            // Submit Button
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: teal,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: _isBooking ? null : _submitBooking,
                child: _isBooking
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text(
                        'Confirm Appointment Request',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

