enum AppointmentType {
  shelterVisit,
  meetAndGreet,
  homeTourInterview,
  fosterHandover,
}

extension AppointmentTypeExtension on AppointmentType {
  String get displayName {
    switch (this) {
      case AppointmentType.shelterVisit:
        return 'Shelter Facility Visit';
      case AppointmentType.meetAndGreet:
        return 'Pet Meet & Greet';
      case AppointmentType.homeTourInterview:
        return 'Virtual Home Tour Interview';
      case AppointmentType.fosterHandover:
        return 'Trial Foster Handover';
    }
  }
}

enum AppointmentStatus {
  pending,
  confirmed,
  completed,
  cancelled,
}

extension AppointmentStatusExtension on AppointmentStatus {
  String get displayName {
    switch (this) {
      case AppointmentStatus.pending:
        return 'Pending Shelter Approval';
      case AppointmentStatus.confirmed:
        return 'Confirmed';
      case AppointmentStatus.completed:
        return 'Completed';
      case AppointmentStatus.cancelled:
        return 'Cancelled';
    }
  }
}

class AdoptionAppointment {
  final String id;
  final String petId;
  final String petName;
  final String petImageUrl;
  final String shelterName;
  final String shelterPhone;
  final String shelterAddress;
  final String applicantName;
  final String applicantPhone;
  final DateTime date;
  final String timeSlot;
  final AppointmentType type;
  final AppointmentStatus status;
  final String notes;

  const AdoptionAppointment({
    required this.id,
    required this.petId,
    required this.petName,
    required this.petImageUrl,
    required this.shelterName,
    required this.shelterPhone,
    required this.shelterAddress,
    required this.applicantName,
    required this.applicantPhone,
    required this.date,
    required this.timeSlot,
    required this.type,
    required this.status,
    this.notes = '',
  });

  AdoptionAppointment copyWith({
    AppointmentStatus? status,
    String? notes,
    DateTime? date,
    String? timeSlot,
  }) {
    return AdoptionAppointment(
      id: id,
      petId: petId,
      petName: petName,
      petImageUrl: petImageUrl,
      shelterName: shelterName,
      shelterPhone: shelterPhone,
      shelterAddress: shelterAddress,
      applicantName: applicantName,
      applicantPhone: applicantPhone,
      date: date ?? this.date,
      timeSlot: timeSlot ?? this.timeSlot,
      type: type,
      status: status ?? this.status,
      notes: notes ?? this.notes,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'petId': petId,
    'petName': petName,
    'petImageUrl': petImageUrl,
    'shelterName': shelterName,
    'shelterPhone': shelterPhone,
    'shelterAddress': shelterAddress,
    'applicantName': applicantName,
    'applicantPhone': applicantPhone,
    'date': date.toIso8601String(),
    'timeSlot': timeSlot,
    'type': type.name,
    'status': status.name,
    'notes': notes,
  };

  factory AdoptionAppointment.fromJson(Map<String, dynamic> json) {
    return AdoptionAppointment(
      id: json['id'] as String,
      petId: json['petId'] as String,
      petName: json['petName'] as String,
      petImageUrl: json['petImageUrl'] as String,
      shelterName: json['shelterName'] as String,
      shelterPhone: json['shelterPhone'] as String,
      shelterAddress: json['shelterAddress'] as String,
      applicantName: json['applicantName'] as String,
      applicantPhone: json['applicantPhone'] as String,
      date: DateTime.parse(json['date'] as String),
      timeSlot: json['timeSlot'] as String,
      type: AppointmentType.values.firstWhere(
        (t) => t.name == json['type'],
        orElse: () => AppointmentType.meetAndGreet,
      ),
      status: AppointmentStatus.values.firstWhere(
        (s) => s.name == json['status'],
        orElse: () => AppointmentStatus.pending,
      ),
      notes: json['notes'] as String? ?? '',
    );
  }
}

