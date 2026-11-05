import '../models/pet_model.dart';
import '../repositories/pet_repository.dart';

class AiAssistantMessage {
  final String id;
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final List<Pet>? recommendedPets;

  const AiAssistantMessage({
    required this.id,
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.recommendedPets,
  });
}

class AiAssistantService {
  static final AiAssistantService _instance = AiAssistantService._internal();
  factory AiAssistantService() => _instance;
  AiAssistantService._internal();

  final PetRepository _petRepo = PetRepository();

  // If the user configures GEMINI_API_KEY via env, it will be picked up here
  static const String _geminiApiKey = String.fromEnvironment('GEMINI_API_KEY', defaultValue: '');
  bool get hasCustomApiKey => _geminiApiKey.isNotEmpty;

  Future<AiAssistantMessage> getResponse(String userPrompt) async {
    // Artificial conversational pause for realistic UX
    await Future.delayed(const Duration(milliseconds: 600));

    final normalized = userPrompt.toLowerCase().trim();

    // 0. Out-of-Scope Protection (Non-Pet Topics)
    final outOfScopeKeywords = [
      'politics', 'election', 'minister', 'government',
      'coding', 'python', 'flutter', 'dart', 'javascript', 'program',
      'football', 'cricket', 'messi', 'ronaldo', 'sports',
      'calculus', 'algebra', 'solve equation', 'stock market', 'crypto'
    ];
    final isOutOfScope = outOfScopeKeywords.any((kw) => normalized.contains(kw));
    if (isOutOfScope) {
      final isBangla = RegExp(r'[\u0980-\u09FF]').hasMatch(userPrompt);
      return AiAssistantMessage(
        id: 'ai-${DateTime.now().millisecondsSinceEpoch}',
        text: isBangla
            ? 'আমি শুধু পোষা প্রাণী ও অ্যাডপশন সংক্রান্ত বিষয়ে সাহায্য করতে পারি! 🐾 কুকুর-বিড়ালের যত্ন, মাছ বা কচ্ছপ পালন, অথবা AdoptMatch-এ অ্যাডপশন নিয়ে যেকোনো প্রশ্ন করতে পারেন!'
            : "I'd love to chat, but my expertise is focused purely on pets and adoption! 🐾 Feel free to ask me anything about pet care, breeds, vaccines, or adopting on AdoptMatch!",
        isUser: false,
        timestamp: DateTime.now(),
      );
    }

    // 0.1 Friendly conversational greetings & small talk
    final isGreeting = normalized == 'hi' ||
        normalized == 'hello' ||
        normalized == 'hey' ||
        normalized.contains('kmn acho') ||
        normalized.contains('kemon acho') ||
        normalized.contains('bhalo acho') ||
        normalized.contains('how are you') ||
        normalized.contains('salaam') ||
        normalized.contains('namaste');

    if (isGreeting) {
      final isBangla = RegExp(r'[\u0980-\u09FF]').hasMatch(userPrompt) ||
          normalized.contains('kmn') ||
          normalized.contains('acho') ||
          normalized.contains('bhalo');
      return AiAssistantMessage(
        id: 'ai-${DateTime.now().millisecondsSinceEpoch}',
        text: isBangla
            ? 'আমি আলহামদুলিল্লাহ খুব ভালো আছি! 🐾 আপনি কেমন আছেন? আপনার পোষা প্রাণীর যত্ন, খাবার, ভ্যাকসিন বা নতুন কোনো পেট অ্যাডপশন সংক্রান্ত বিষয়ে কীভাবে সাহায্য করতে পারি বলুন?'
            : "Hello! I'm doing wonderfully, thank you! 🐾 How can I help you today with pet care, breeds, nutrition, or adopting a furry friend on AdoptMatch?",
        isUser: false,
        timestamp: DateTime.now(),
      );
    }

    // 0.2 Daily hours / alone time questions
    if (normalized.contains('hour') ||
        normalized.contains('ghonta') ||
        normalized.contains('ঘণ্টা') ||
        normalized.contains('alone') ||
        normalized.contains('schedule')) {
      final isBangla = RegExp(r'[\u0980-\u09FF]').hasMatch(userPrompt) ||
          normalized.contains('ghonta') ||
          normalized.contains('koto') ||
          normalized.contains('thakte');
      return AiAssistantMessage(
        id: 'ai-${DateTime.now().millisecondsSinceEpoch}',
        text: isBangla
            ? 'সাধারণত প্রাপ্তবয়স্ক বিড়াল ও শান্ত স্বভাবের কুকুর ৩-৫ ঘণ্টা একা থাকতে বেশ স্বাচ্ছন্দ্য বোধ করে। 🐾 তবে ছোট ছানা (puppy বা kitten)-দের বেশি সময় একা রাখা ঠিক নয়।\n\nআপনি কি কোনো নির্দিষ্ট জাতের পোষ্যের একা থাকার অভ্যাস বা ডে-কেয়ার রুটিন জানতে চান?'
            : "Adult cats and calm, well-trained dogs can comfortably stay home for 3–5 hours alone! 🐾 However, young puppies and kittens shouldn't be left unattended for extended periods.\n\nAre you planning your daily schedule around a pet, or looking for a companion that matches your routine?",
        isUser: false,
        timestamp: DateTime.now(),
      );
    }

    final availablePets = await _petRepo.getAllPets();

    List<Pet> matchedPets = [];
    String replyText = '';

    // 1. Apartment or Flat living queries
    if (normalized.contains('apartment') || normalized.contains('flat') || normalized.contains('indoor')) {
      matchedPets = availablePets.where((p) => p.isApartmentFriendly).take(2).toList();
      replyText = 'For apartment or flat living, we look for calm, adaptable companions with low barking or litter-trained habits.\n\n'
          'Here are verified apartment-friendly rescues currently waiting in Dhaka:';
    }
    // 2. Kids or Family safety queries
    else if (normalized.contains('kid') || normalized.contains('child') || normalized.contains('family') || normalized.contains('baby')) {
      matchedPets = availablePets.where((p) => p.isKidSafe).take(2).toList();
      replyText = 'Adopting with children requires gentle, highly socialized pets that have passed shelter temperament assessments.\n\n'
          'These loving rescues have been certified child-friendly by our partner shelters:';
    }
    // 3. Cat queries
    else if (normalized.contains('cat') || normalized.contains('kitten') || normalized.contains('feline')) {
      matchedPets = availablePets.where((p) => p.species == 'Cat').take(2).toList();
      replyText = 'Cats make wonderful, low-maintenance companions that thrive indoors. Most are already litter-trained and spayed/neutered.\n\n'
          'Meet some of our adorable feline friends:';
    }
    // 4. Dog queries
    else if (normalized.contains('dog') || normalized.contains('puppy') || normalized.contains('canine')) {
      matchedPets = availablePets.where((p) => p.species == 'Dog').take(2).toList();
      replyText = 'Dogs provide unconditional companionship, loyal loyalty, and healthy daily exercise routines.\n\n'
          'Here are loving dogs ready for a forever home:';
    }
    // 5. Aquatic & Exotic pet queries (Goldfish, Turtles, Geckos, Rabbits)
    else if (normalized.contains('fish') ||
        normalized.contains('goldfish') ||
        normalized.contains('betta') ||
        normalized.contains('turtle') ||
        normalized.contains('gecko') ||
        normalized.contains('dragon') ||
        normalized.contains('rabbit') ||
        normalized.contains('bunny')) {
      matchedPets = availablePets
          .where((p) =>
              p.species == 'Fish' ||
              p.species == 'Turtle' ||
              p.species == 'Gecko' ||
              p.species == 'Rabbit' ||
              p.species == 'Small')
          .take(2)
          .toList();
      replyText = 'Aquatic and exotic companions bring serene joy to your home! 🐠🐢🦎\n\n'
          'Here are wonderful exotic companions currently looking for a loving home:';
    }
    // 5. Adoption process & requirements
    else if (normalized.contains('process') || normalized.contains('how to adopt') || normalized.contains('cost') || normalized.contains('fee') || normalized.contains('requirement')) {
      replyText = '📋 **AdoptMatch 5-Step Adoption Protocol**:\n\n'
          '1. **Browse & Match**: Explore vetted rescue pets and check lifestyle compatibility.\n'
          '2. **Apply Online**: Complete the 5-step application (housing, landlord verification, vet readiness, e-signature).\n'
          '3. **Shelter Screening**: Shelter coordinators review your housing and pet history within 24-48 hours.\n'
          '4. **Meet & Greet / Home Tour**: Schedule a shelter visit or virtual home inspection to meet the pet.\n'
          '5. **14-Day Foster Trial**: Bring the pet home on a guided trial foster to ensure a seamless bond before legal adoption!\n\n'
          '💡 *AdoptMatch charges ZERO breeding or commercial fees. Only standard nominal shelter vetting fees apply.*';
    }
    // 6. Medical & Vet disclaimer
    else if (normalized.contains('sick') || normalized.contains('vomit') || normalized.contains('medicine') || normalized.contains('vet') || normalized.contains('pain') || normalized.contains('doctor')) {
      replyText = '⚠️ **Veterinary Notice**:\n\n'
          'I am an AI adoption guide and cannot diagnose or prescribe treatments for medical conditions. If your pet is showing acute symptoms, lethargy, vomiting, or breathing distress, please immediately contact an emergency 24/7 clinic via the **Emergency SOS** section in the app.';
    }
    // 7. General fallback response
    else {
      final isBangla = RegExp(r'[\u0980-\u09FF]').hasMatch(userPrompt) ||
          normalized.contains('kmn') ||
          normalized.contains('beral') ||
          normalized.contains('kukur') ||
          normalized.contains('chai') ||
          normalized.contains('lagbe');
      matchedPets = availablePets.take(2).toList();
      replyText = isBangla
          ? 'পোষা প্রাণীর যত্ন, খাবার, ব্রিড, ভ্যাকসিন কিংবা AdoptMatch-এ অ্যাডপশন নিয়ে যেকোনো বিষয়ে আপনি প্রশ্ন করতে পারেন! 🐾\n\nবর্তমানে আমাদের শেল্টারে দত্তকের জন্য প্রস্তুত কিছু কিউট বন্ধু নিচে দেখতে পারেন:'
          : 'I\'m right here to help you with pet care, nutrition, breeds, vaccines, or finding a rescue companion on AdoptMatch! 🐾\n\nHere are some lovable pets ready for adoption today:';
    }

    return AiAssistantMessage(
      id: 'ai-${DateTime.now().millisecondsSinceEpoch}',
      text: replyText,
      isUser: false,
      timestamp: DateTime.now(),
      recommendedPets: matchedPets.isNotEmpty ? matchedPets : null,
    );
  }
}
