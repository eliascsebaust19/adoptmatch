import '../models/emergency_alert_model.dart';

class EmergencyRepository {
  final List<EmergencyAlert> _alerts = [
    EmergencyAlert(
      id: 'sos-001',
      petId: 'p3',
      petName: 'Rocky',
      petBreed: 'Golden Retriever Pup',
      imageUrl: 'https://3kht7mdtcvdag9ff.private.blob.vercel-storage.com/pets/pet_6.jpg',
      lastSeenLocation: 'Gulshan 1 Circle near Lake Park, Dhaka',
      lat: 23.7781,
      lng: 90.4182,
      radiusKm: 5,
      rewardBdt: 10000,
      reportedTime: DateTime.now().subtract(const Duration(hours: 2)),
      description: 'Wearing a blue nylon collar with silver bell. Very friendly, responds to name Rocky. Slipped leash at 6:30 PM.',
      contactPhone: '+880 18•• ••••21',
      isActive: true,
    ),
    EmergencyAlert(
      id: 'sos-002',
      petId: 'p2',
      petName: 'Bella',
      petBreed: 'White & Grey Domestic Short-hair',
      imageUrl: 'https://3kht7mdtcvdag9ff.private.blob.vercel-storage.com/pets/pet_4.jpg',
      lastSeenLocation: 'Dhanmondi Road 8/A, Dhaka',
      lat: 23.7461,
      lng: 90.3742,
      radiusKm: 5,
      rewardBdt: 5000,
      reportedTime: DateTime.now().subtract(const Duration(hours: 5)),
      description: 'Microchipped cat, very shy. Please do not chase, call emergency number immediately with sightings.',
      contactPhone: '+880 17•• ••••88',
      isActive: true,
    ),
  ];

  final List<VetClinic> _clinics = const [
    VetClinic(
      id: 'vet-01',
      name: 'Central Veterinary Hospital (Govt)',
      address: '48 Kazi Nazrul Islam Ave, Farmgate, Dhaka',
      phone: '+880 2-9110373',
      is24Hours: true,
      distanceKm: 2.1,
      rating: 4.8,
      services: '24/7 Trauma, ICU, Blood Transfusion, Orthopedics',
    ),
    VetClinic(
      id: 'vet-02',
      name: 'Care For Paws Emergency Vet Centre',
      address: 'House 14, Road 113/A, Gulshan 2, Dhaka',
      phone: '+880 1711-002233',
      is24Hours: true,
      distanceKm: 3.5,
      rating: 4.9,
      services: '24/7 Critical Care, Poison Control, Surgery, Lab',
    ),
    VetClinic(
      id: 'vet-03',
      name: 'Dhaka Pet Hospital & Surgery Center',
      address: 'House 5, Road 2, Block B, Banani, Dhaka',
      phone: '+880 1912-334455',
      is24Hours: true,
      distanceKm: 4.2,
      rating: 4.7,
      services: '24/7 Emergency triage, Ultrasound, Digital X-Ray',
    ),
    VetClinic(
      id: 'vet-04',
      name: 'Animal Care Clinic & Hospital',
      address: 'Sector 3, Jashimuddin Ave, Uttara, Dhaka',
      phone: '+880 1822-778899',
      is24Hours: true,
      distanceKm: 9.8,
      rating: 4.6,
      services: 'Emergency Rescue Intake, Isolation Ward, Diagnostics',
    ),
  ];

  Future<List<EmergencyAlert>> getActiveAlerts() async {
    return List.unmodifiable(_alerts.where((a) => a.isActive));
  }

  Future<List<VetClinic>> getEmergencyClinics() async {
    return _clinics;
  }

  Future<EmergencyAlert> broadcastAlert({
    required String petName,
    required String petBreed,
    required String imageUrl,
    required String lastSeenLocation,
    required double lat,
    required double lng,
    required int radiusKm,
    required int rewardBdt,
    required String description,
    required String contactPhone,
  }) async {
    await Future.delayed(const Duration(milliseconds: 400));
    final alert = EmergencyAlert(
      id: 'sos-${DateTime.now().millisecondsSinceEpoch}',
      petId: 'custom-${DateTime.now().millisecondsSinceEpoch}',
      petName: petName,
      petBreed: petBreed,
      imageUrl: imageUrl,
      lastSeenLocation: lastSeenLocation,
      lat: lat,
      lng: lng,
      radiusKm: radiusKm,
      rewardBdt: rewardBdt,
      reportedTime: DateTime.now(),
      description: description,
      contactPhone: contactPhone,
      isActive: true,
    );
    _alerts.insert(0, alert);
    return alert;
  }
}

