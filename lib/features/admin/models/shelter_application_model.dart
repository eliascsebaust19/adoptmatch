import 'package:equatable/equatable.dart';

enum VerificationStatus {
  pending,
  approved,
  rejected;

  String get displayName {
    switch (this) {
      case VerificationStatus.pending:
        return 'Pending Review';
      case VerificationStatus.approved:
        return 'Approved';
      case VerificationStatus.rejected:
        return 'Rejected';
    }
  }
}

class ShelterApplication extends Equatable {
  final String id;
  final String shelterName;
  final String registrationNumber;
  final String contactPerson;
  final String email;
  final String phone;
  final String city;
  final String address;
  final String nidNumber;
  final String tradeLicenseNumber;
  final String vetAffiliation;
  final VerificationStatus status;
  final List<String> documentUrls;
  final DateTime submittedAt;
  final String? reviewerNotes;
  final int capacity;

  const ShelterApplication({
    required this.id,
    required this.shelterName,
    required this.registrationNumber,
    required this.contactPerson,
    required this.email,
    required this.phone,
    required this.city,
    required this.address,
    required this.nidNumber,
    required this.tradeLicenseNumber,
    required this.vetAffiliation,
    required this.status,
    required this.documentUrls,
    required this.submittedAt,
    this.reviewerNotes,
    this.capacity = 30,
  });

  ShelterApplication copyWith({
    String? id,
    String? shelterName,
    String? registrationNumber,
    String? contactPerson,
    String? email,
    String? phone,
    String? city,
    String? address,
    String? nidNumber,
    String? tradeLicenseNumber,
    String? vetAffiliation,
    VerificationStatus? status,
    List<String>? documentUrls,
    DateTime? submittedAt,
    String? reviewerNotes,
    int? capacity,
  }) {
    return ShelterApplication(
      id: id ?? this.id,
      shelterName: shelterName ?? this.shelterName,
      registrationNumber: registrationNumber ?? this.registrationNumber,
      contactPerson: contactPerson ?? this.contactPerson,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      city: city ?? this.city,
      address: address ?? this.address,
      nidNumber: nidNumber ?? this.nidNumber,
      tradeLicenseNumber: tradeLicenseNumber ?? this.tradeLicenseNumber,
      vetAffiliation: vetAffiliation ?? this.vetAffiliation,
      status: status ?? this.status,
      documentUrls: documentUrls ?? this.documentUrls,
      submittedAt: submittedAt ?? this.submittedAt,
      reviewerNotes: reviewerNotes ?? this.reviewerNotes,
      capacity: capacity ?? this.capacity,
    );
  }

  @override
  List<Object?> get props => [
        id,
        shelterName,
        registrationNumber,
        contactPerson,
        email,
        phone,
        city,
        address,
        nidNumber,
        tradeLicenseNumber,
        vetAffiliation,
        status,
        documentUrls,
        submittedAt,
        reviewerNotes,
        capacity,
      ];
}

