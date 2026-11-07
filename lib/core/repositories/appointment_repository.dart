import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/appointment_model.dart';
import 'notification_repository.dart';

class AppointmentRepository {
  static final AppointmentRepository _instance = AppointmentRepository._internal();
  factory AppointmentRepository() => _instance;
  AppointmentRepository._internal();

  static const String _storageKey = 'adoptmatch_appointments';
  final _streamController = StreamController<List<AdoptionAppointment>>.broadcast();
  Stream<List<AdoptionAppointment>> get appointmentsStream => _streamController.stream;

  List<AdoptionAppointment> _appointments = [];
  bool _initialized = false;

  final List<AdoptionAppointment> _defaultAppointments = [
    AdoptionAppointment(
      id: 'apt-001',
      petId: 'p1',
      petName: 'Luna',
      petImageUrl: 'https://3kht7mdtcvdag9ff.private.blob.vercel-storage.com/pets/pet_1.jpg',
      shelterName: 'Dhaka Animal Rescue',
      shelterPhone: '+880 17•• ••••12',
      shelterAddress: 'Dhanmondi 27, Dhaka',
      applicantName: 'Elias Ahmed',
      applicantPhone: '+880 1711 234567',
      date: DateTime.now().add(const Duration(days: 2)),
      timeSlot: '4:00 PM - 5:00 PM',
      type: AppointmentType.homeTourInterview,
      status: AppointmentStatus.confirmed,
      notes: 'Virtual video call via Zoom or Google Meet. Shelter officer Tanvir will lead.',
    ),
  ];

  Future<void> _init() async {
    if (_initialized) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storageKey);
      if (raw != null) {
        final List<dynamic> list = jsonDecode(raw);
        _appointments = list.map((item) => AdoptionAppointment.fromJson(item as Map<String, dynamic>)).toList();
      } else {
        _appointments = List.from(_defaultAppointments);
        await _save();
      }
    } catch (_) {
      _appointments = List.from(_defaultAppointments);
    }
    _initialized = true;
    _streamController.add(List.unmodifiable(_appointments));
  }

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded = jsonEncode(_appointments.map((a) => a.toJson()).toList());
      await prefs.setString(_storageKey, encoded);
    } catch (_) {}
  }

  Future<List<AdoptionAppointment>> getAppointments() async {
    if (!_initialized) await _init();
    return List.unmodifiable(_appointments);
  }

  /// Validates whether a time slot conflicts with an existing confirmed appointment
  Future<bool> hasConflict({
    required String shelterName,
    required DateTime date,
    required String timeSlot,
  }) async {
    if (!_initialized) await _init();
    return _appointments.any((a) =>
      a.shelterName.toLowerCase() == shelterName.toLowerCase() &&
      a.date.year == date.year &&
      a.date.month == date.month &&
      a.date.day == date.day &&
      a.timeSlot == timeSlot &&
      a.status != AppointmentStatus.cancelled
    );
  }

  Future<AdoptionAppointment> bookAppointment({
    required String petId,
    required String petName,
    required String petImageUrl,
    required String shelterName,
    required String shelterPhone,
    required String shelterAddress,
    required String applicantName,
    required String applicantPhone,
    required DateTime date,
    required String timeSlot,
    required AppointmentType type,
    String notes = '',
  }) async {
    if (!_initialized) await _init();

    final isConflict = await hasConflict(shelterName: shelterName, date: date, timeSlot: timeSlot);
    if (isConflict) {
      throw Exception('This time slot is already booked for $shelterName. Please select an alternate slot.');
    }

    final newApt = AdoptionAppointment(
      id: 'apt-${DateTime.now().millisecondsSinceEpoch}',
      petId: petId,
      petName: petName,
      petImageUrl: petImageUrl,
      shelterName: shelterName,
      shelterPhone: shelterPhone,
      shelterAddress: shelterAddress,
      applicantName: applicantName,
      applicantPhone: applicantPhone,
      date: date,
      timeSlot: timeSlot,
      type: type,
      status: AppointmentStatus.pending,
      notes: notes,
    );

    _appointments.insert(0, newApt);
    await _save();
    _streamController.add(List.unmodifiable(_appointments));

    // Send automatic notification
    NotificationRepository().addNotification(
      title: 'Appointment Requested 📅',
      body: 'Your ${type.displayName} request for $petName with $shelterName is submitted for confirmation.',
      category: NotificationCategory.application,
      targetRoute: '/appointments',
    );

    return newApt;
  }

  Future<void> updateAppointmentStatus(String id, AppointmentStatus status, {String? notes}) async {
    if (!_initialized) await _init();
    final index = _appointments.indexWhere((a) => a.id == id);
    if (index != -1) {
      _appointments[index] = _appointments[index].copyWith(
        status: status,
        notes: notes ?? _appointments[index].notes,
      );
      await _save();
      _streamController.add(List.unmodifiable(_appointments));

      // Push notification on status change
      NotificationRepository().addNotification(
        title: 'Appointment ${status.displayName} 🗓️',
        body: 'Your session with ${_appointments[index].shelterName} regarding ${_appointments[index].petName} is now ${status.displayName}.',
        category: NotificationCategory.application,
        targetRoute: '/appointments',
      );
    }
  }
}

