import 'package:equatable/equatable.dart';

class VaccineRecord extends Equatable {
  final String id;
  final String title;
  final String dateAdministered;
  final String nextDueDate;
  final String clinicName;
  final String veterinarian;
  final String batchNumber;
  final bool isCompleted;

  const VaccineRecord({
    required this.id,
    required this.title,
    required this.dateAdministered,
    required this.nextDueDate,
    required this.clinicName,
    required this.veterinarian,
    required this.batchNumber,
    this.isCompleted = true,
  });

  @override
  List<Object?> get props => [
        id,
        title,
        dateAdministered,
        nextDueDate,
        clinicName,
        veterinarian,
        batchNumber,
        isCompleted,
      ];
}

class HealthPassport extends Equatable {
  final String petId;
  final String petName;
  final String species;
  final String breed;
  final String microchipId;
  final String emergencyPhone;
  final String emergencyClinic;
  final String allergies;
  final String bloodType;
  final bool isRemindersActive;
  final List<VaccineRecord> vaccineRecords;
  final String qrHash;

  const HealthPassport({
    required this.petId,
    required this.petName,
    required this.species,
    required this.breed,
    required this.microchipId,
    required this.emergencyPhone,
    required this.emergencyClinic,
    required this.allergies,
    required this.bloodType,
    this.isRemindersActive = true,
    required this.vaccineRecords,
    required this.qrHash,
  });

  HealthPassport copyWith({
    String? petId,
    String? petName,
    String? species,
    String? breed,
    String? microchipId,
    String? emergencyPhone,
    String? emergencyClinic,
    String? allergies,
    String? bloodType,
    bool? isRemindersActive,
    List<VaccineRecord>? vaccineRecords,
    String? qrHash,
  }) {
    return HealthPassport(
      petId: petId ?? this.petId,
      petName: petName ?? this.petName,
      species: species ?? this.species,
      breed: breed ?? this.breed,
      microchipId: microchipId ?? this.microchipId,
      emergencyPhone: emergencyPhone ?? this.emergencyPhone,
      emergencyClinic: emergencyClinic ?? this.emergencyClinic,
      allergies: allergies ?? this.allergies,
      bloodType: bloodType ?? this.bloodType,
      isRemindersActive: isRemindersActive ?? this.isRemindersActive,
      vaccineRecords: vaccineRecords ?? this.vaccineRecords,
      qrHash: qrHash ?? this.qrHash,
    );
  }

  @override
  List<Object?> get props => [
        petId,
        petName,
        species,
        breed,
        microchipId,
        emergencyPhone,
        emergencyClinic,
        allergies,
        bloodType,
        isRemindersActive,
        vaccineRecords,
        qrHash,
      ];
}

