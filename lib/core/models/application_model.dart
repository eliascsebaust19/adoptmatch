import 'package:equatable/equatable.dart';

enum ApplicationStatus {
  draft,
  submitted,
  underReview,
  homeVisitScheduled,
  fosterTrial,
  approved,
  rejected,
}

extension ApplicationStatusExtension on ApplicationStatus {
  String get displayName {
    switch (this) {
      case ApplicationStatus.draft:
        return 'Draft';
      case ApplicationStatus.submitted:
        return 'Submitted';
      case ApplicationStatus.underReview:
        return 'Under Review';
      case ApplicationStatus.homeVisitScheduled:
        return 'Home Visit Scheduled';
      case ApplicationStatus.fosterTrial:
        return 'Trial Foster (14-day)';
      case ApplicationStatus.approved:
        return 'Approved & Custody Ready';
      case ApplicationStatus.rejected:
        return 'Declined with Notes';
    }
  }

  int get stepIndex {
    switch (this) {
      case ApplicationStatus.draft:
        return 0;
      case ApplicationStatus.submitted:
        return 1;
      case ApplicationStatus.underReview:
        return 2;
      case ApplicationStatus.homeVisitScheduled:
        return 3;
      case ApplicationStatus.fosterTrial:
        return 4;
      case ApplicationStatus.approved:
      case ApplicationStatus.rejected:
        return 5;
    }
  }
}

class AdoptionApplication extends Equatable {
  final String id;
  final String? serverId;
  final String petId;
  final String petName;
  final String petBreed;
  final String petImageUrl;
  final String applicantName;
  final String applicantPhone;
  final String applicantEmail;
  final String nidNumber;
  final String emergencyContactName;
  final String emergencyContactPhone;
  final String address;
  final String housingType; // 'Apartment', 'Independent House', 'Duplex'
  final String ownershipStatus; // 'Owned', 'Rented'
  final bool landlordAllowsPets;
  final String? landlordContact;
  final String yardType; // 'Fenced Yard', 'Balcony', 'None'
  final String petLivingSpace; // 'Indoor Only', 'Indoor & Outdoor'
  final int totalAdults;
  final bool hasKids;
  final String? childrenAges;
  final bool hasAllergies;
  final bool hasOtherPets;
  final String? otherPetsDetails;
  final String dailyHoursAlone;
  final String primaryCaregiver;
  final String petExperience;
  final bool emergencyVetFund;
  final String monthlyBudget;
  final String whyAdopt;
  final ApplicationStatus status;
  final DateTime submittedAt;
  final String? reviewerNotes;
  final DateTime? homeVisitDate;
  final bool isESigned;
  final String? signatureData;

  const AdoptionApplication({
    required this.id,
    this.serverId,
    required this.petId,
    required this.petName,
    required this.petBreed,
    required this.petImageUrl,
    required this.applicantName,
    required this.applicantPhone,
    required this.applicantEmail,
    this.nidNumber = '',
    this.emergencyContactName = '',
    this.emergencyContactPhone = '',
    required this.address,
    required this.housingType,
    this.ownershipStatus = 'Owned',
    this.landlordAllowsPets = true,
    this.landlordContact,
    this.yardType = 'Private Fenced Yard',
    this.petLivingSpace = 'Indoor with Yard Access',
    this.totalAdults = 2,
    this.hasKids = false,
    this.childrenAges,
    this.hasAllergies = false,
    this.hasOtherPets = false,
    this.otherPetsDetails,
    required this.dailyHoursAlone,
    this.primaryCaregiver = 'Applicant & Family',
    required this.petExperience,
    this.emergencyVetFund = true,
    this.monthlyBudget = '5,000 - 10,000 BDT',
    required this.whyAdopt,
    this.status = ApplicationStatus.submitted,
    required this.submittedAt,
    this.reviewerNotes,
    this.homeVisitDate,
    this.isESigned = true,
    this.signatureData,
  });

  AdoptionApplication copyWith({
    String? id,
    String? serverId,
    String? petId,
    String? petName,
    String? petBreed,
    String? petImageUrl,
    String? applicantName,
    String? applicantPhone,
    String? applicantEmail,
    String? nidNumber,
    String? emergencyContactName,
    String? emergencyContactPhone,
    String? address,
    String? housingType,
    String? ownershipStatus,
    bool? landlordAllowsPets,
    String? landlordContact,
    String? yardType,
    String? petLivingSpace,
    int? totalAdults,
    bool? hasKids,
    String? childrenAges,
    bool? hasAllergies,
    bool? hasOtherPets,
    String? otherPetsDetails,
    String? dailyHoursAlone,
    String? primaryCaregiver,
    String? petExperience,
    bool? emergencyVetFund,
    String? monthlyBudget,
    String? whyAdopt,
    ApplicationStatus? status,
    DateTime? submittedAt,
    String? reviewerNotes,
    DateTime? homeVisitDate,
    bool? isESigned,
    String? signatureData,
  }) {
    return AdoptionApplication(
      id: id ?? this.id,
      serverId: serverId ?? this.serverId,
      petId: petId ?? this.petId,
      petName: petName ?? this.petName,
      petBreed: petBreed ?? this.petBreed,
      petImageUrl: petImageUrl ?? this.petImageUrl,
      applicantName: applicantName ?? this.applicantName,
      applicantPhone: applicantPhone ?? this.applicantPhone,
      applicantEmail: applicantEmail ?? this.applicantEmail,
      nidNumber: nidNumber ?? this.nidNumber,
      emergencyContactName: emergencyContactName ?? this.emergencyContactName,
      emergencyContactPhone: emergencyContactPhone ?? this.emergencyContactPhone,
      address: address ?? this.address,
      housingType: housingType ?? this.housingType,
      ownershipStatus: ownershipStatus ?? this.ownershipStatus,
      landlordAllowsPets: landlordAllowsPets ?? this.landlordAllowsPets,
      landlordContact: landlordContact ?? this.landlordContact,
      yardType: yardType ?? this.yardType,
      petLivingSpace: petLivingSpace ?? this.petLivingSpace,
      totalAdults: totalAdults ?? this.totalAdults,
      hasKids: hasKids ?? this.hasKids,
      childrenAges: childrenAges ?? this.childrenAges,
      hasAllergies: hasAllergies ?? this.hasAllergies,
      hasOtherPets: hasOtherPets ?? this.hasOtherPets,
      otherPetsDetails: otherPetsDetails ?? this.otherPetsDetails,
      dailyHoursAlone: dailyHoursAlone ?? this.dailyHoursAlone,
      primaryCaregiver: primaryCaregiver ?? this.primaryCaregiver,
      petExperience: petExperience ?? this.petExperience,
      emergencyVetFund: emergencyVetFund ?? this.emergencyVetFund,
      monthlyBudget: monthlyBudget ?? this.monthlyBudget,
      whyAdopt: whyAdopt ?? this.whyAdopt,
      status: status ?? this.status,
      submittedAt: submittedAt ?? this.submittedAt,
      reviewerNotes: reviewerNotes ?? this.reviewerNotes,
      homeVisitDate: homeVisitDate ?? this.homeVisitDate,
      isESigned: isESigned ?? this.isESigned,
      signatureData: signatureData ?? this.signatureData,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'serverId': serverId,
      'petId': petId,
      'petName': petName,
      'petBreed': petBreed,
      'petImageUrl': petImageUrl,
      'applicantName': applicantName,
      'applicantPhone': applicantPhone,
      'applicantEmail': applicantEmail,
      'nidNumber': nidNumber,
      'emergencyContactName': emergencyContactName,
      'emergencyContactPhone': emergencyContactPhone,
      'address': address,
      'housingType': housingType,
      'ownershipStatus': ownershipStatus,
      'landlordAllowsPets': landlordAllowsPets,
      'landlordContact': landlordContact,
      'yardType': yardType,
      'petLivingSpace': petLivingSpace,
      'totalAdults': totalAdults,
      'hasKids': hasKids,
      'childrenAges': childrenAges,
      'hasAllergies': hasAllergies,
      'hasOtherPets': hasOtherPets,
      'otherPetsDetails': otherPetsDetails,
      'dailyHoursAlone': dailyHoursAlone,
      'primaryCaregiver': primaryCaregiver,
      'petExperience': petExperience,
      'emergencyVetFund': emergencyVetFund,
      'monthlyBudget': monthlyBudget,
      'whyAdopt': whyAdopt,
      'status': status.name,
      'submittedAt': submittedAt.toIso8601String(),
      'reviewerNotes': reviewerNotes,
      'homeVisitDate': homeVisitDate?.toIso8601String(),
      'isESigned': isESigned,
      'signatureData': signatureData,
    };
  }

  factory AdoptionApplication.fromJson(Map<String, dynamic> json) {
    DateTime parseDate(dynamic val) {
      if (val is String) {
        final parsed = DateTime.tryParse(val);
        if (parsed != null) return parsed;
      }
      return DateTime.now();
    }

    DateTime? parseNullableDate(dynamic val) {
      if (val is String && val.isNotEmpty) {
        return DateTime.tryParse(val);
      }
      return null;
    }

    return AdoptionApplication(
      id: json['id'] as String? ?? 'AM-APP-${DateTime.now().millisecondsSinceEpoch}',
      serverId: json['serverId']?.toString(),
      petId: json['petId'] as String? ?? '',
      petName: json['petName'] as String? ?? 'Adoptable Pet',
      petBreed: json['petBreed'] as String? ?? 'Rescue',
      petImageUrl: json['petImageUrl'] as String? ?? '',
      applicantName: json['applicantName'] as String? ?? 'Applicant',
      applicantPhone: json['applicantPhone'] as String? ?? '',
      applicantEmail: json['applicantEmail'] as String? ?? '',
      nidNumber: json['nidNumber'] as String? ?? '',
      emergencyContactName: json['emergencyContactName'] as String? ?? '',
      emergencyContactPhone: json['emergencyContactPhone'] as String? ?? '',
      address: json['address'] as String? ?? '',
      housingType: json['housingType'] as String? ?? 'Apartment',
      ownershipStatus: json['ownershipStatus'] as String? ?? 'Owned',
      landlordAllowsPets: json['landlordAllowsPets'] as bool? ?? true,
      landlordContact: json['landlordContact'] as String?,
      yardType: json['yardType'] as String? ?? 'Private Fenced Yard',
      petLivingSpace: json['petLivingSpace'] as String? ?? 'Indoor with Yard Access',
      totalAdults: (json['totalAdults'] as num?)?.toInt() ?? 2,
      hasKids: json['hasKids'] as bool? ?? false,
      childrenAges: json['childrenAges'] as String?,
      hasAllergies: json['hasAllergies'] as bool? ?? false,
      hasOtherPets: json['hasOtherPets'] as bool? ?? false,
      otherPetsDetails: json['otherPetsDetails'] as String?,
      dailyHoursAlone: json['dailyHoursAlone'] as String? ?? '2-4 hours',
      primaryCaregiver: json['primaryCaregiver'] as String? ?? 'Applicant',
      petExperience: json['petExperience'] as String? ?? 'Experienced pet parent',
      emergencyVetFund: json['emergencyVetFund'] as bool? ?? true,
      monthlyBudget: json['monthlyBudget'] as String? ?? '5,000 - 10,000 BDT',
      whyAdopt: json['whyAdopt'] as String? ?? 'Committed to lifelong pet welfare',
      status: ApplicationStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => ApplicationStatus.submitted,
      ),
      submittedAt: parseDate(json['submittedAt']),
      reviewerNotes: json['reviewerNotes'] as String?,
      homeVisitDate: parseNullableDate(json['homeVisitDate']),
      isESigned: json['isESigned'] as bool? ?? true,
      signatureData: json['signatureData'] as String?,
    );
  }

  @override
  List<Object?> get props => [
        id,
        serverId,
        petId,
        petName,
        petBreed,
        petImageUrl,
        applicantName,
        applicantPhone,
        applicantEmail,
        nidNumber,
        emergencyContactName,
        emergencyContactPhone,
        address,
        housingType,
        ownershipStatus,
        landlordAllowsPets,
        landlordContact,
        yardType,
        petLivingSpace,
        totalAdults,
        hasKids,
        childrenAges,
        hasAllergies,
        hasOtherPets,
        otherPetsDetails,
        dailyHoursAlone,
        primaryCaregiver,
        petExperience,
        emergencyVetFund,
        monthlyBudget,
        whyAdopt,
        status,
        submittedAt,
        reviewerNotes,
        homeVisitDate,
        isESigned,
        signatureData,
      ];
}
