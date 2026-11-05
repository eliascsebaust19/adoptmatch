import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../../core/models/pet_model.dart';
import '../../../core/repositories/pet_repository.dart';

// --- Events ---
abstract class PetMatchEvent extends Equatable {
  const PetMatchEvent();
  @override
  List<Object?> get props => [];
}

class LoadPetsEvent extends PetMatchEvent {
  final String? category;
  final String? searchQuery;
  final double? maxDistanceKm;
  final bool? kidSafeOnly;
  final bool? apartmentOnly;
  final bool? vaccinatedOnly;

  const LoadPetsEvent({
    this.category,
    this.searchQuery,
    this.maxDistanceKm,
    this.kidSafeOnly,
    this.apartmentOnly,
    this.vaccinatedOnly,
  });

  @override
  List<Object?> get props => [
        category,
        searchQuery,
        maxDistanceKm,
        kidSafeOnly,
        apartmentOnly,
        vaccinatedOnly,
      ];
}

// Alias for Report 2 consistency
class LoadPetsForMatching extends LoadPetsEvent {
  const LoadPetsForMatching({
    super.category,
    super.searchQuery,
    super.maxDistanceKm,
    super.kidSafeOnly,
    super.apartmentOnly,
    super.vaccinatedOnly,
  });
}

class SwipePetLeft extends PetMatchEvent {
  final String petId;
  const SwipePetLeft(this.petId);
  @override
  List<Object?> get props => [petId];
}

class SwipePetRight extends PetMatchEvent {
  final String petId;
  const SwipePetRight(this.petId);
  @override
  List<Object?> get props => [petId];
}

class SwipePetUp extends PetMatchEvent {
  final String petId;
  const SwipePetUp(this.petId);
  @override
  List<Object?> get props => [petId];
}

class TogglePetFavoriteEvent extends PetMatchEvent {
  final String petId;
  const TogglePetFavoriteEvent(this.petId);
  @override
  List<Object?> get props => [petId];
}

class ApplyQuizFilterEvent extends PetMatchEvent {
  final String housing;
  final bool hasKids;
  final bool hasPets;
  final int hoursAlone;
  final String experience;

  const ApplyQuizFilterEvent({
    required this.housing,
    required this.hasKids,
    required this.hasPets,
    required this.hoursAlone,
    required this.experience,
  });

  @override
  List<Object?> get props => [housing, hasKids, hasPets, hoursAlone, experience];
}

class ResetQuizFilterEvent extends PetMatchEvent {
  const ResetQuizFilterEvent();
}

// --- States ---
abstract class PetMatchState extends Equatable {
  const PetMatchState();
  @override
  List<Object?> get props => [];
}

class PetMatchLoading extends PetMatchState {}

class PetMatchLoaded extends PetMatchState {
  final List<Pet> pets;
  final String selectedCategory;
  final String searchQuery;
  final Pet? lastMatchedPet;
  final int currentSwipeIndex;
  final bool hasCompletedQuiz;

  const PetMatchLoaded({
    required this.pets,
    this.selectedCategory = 'All Pets',
    this.searchQuery = '',
    this.lastMatchedPet,
    this.currentSwipeIndex = 0,
    this.hasCompletedQuiz = false,
  });

  PetMatchLoaded copyWith({
    List<Pet>? pets,
    String? selectedCategory,
    String? searchQuery,
    Pet? lastMatchedPet,
    int? currentSwipeIndex,
    bool? hasCompletedQuiz,
  }) {
    return PetMatchLoaded(
      pets: pets ?? this.pets,
      selectedCategory: selectedCategory ?? this.selectedCategory,
      searchQuery: searchQuery ?? this.searchQuery,
      lastMatchedPet: lastMatchedPet,
      currentSwipeIndex: currentSwipeIndex ?? this.currentSwipeIndex,
      hasCompletedQuiz: hasCompletedQuiz ?? this.hasCompletedQuiz,
    );
  }

  @override
  List<Object?> get props => [
        pets,
        selectedCategory,
        searchQuery,
        lastMatchedPet,
        currentSwipeIndex,
        hasCompletedQuiz,
      ];
}

class PetMatchSuccessDialog extends PetMatchState {
  final Pet matchedPet;
  const PetMatchSuccessDialog(this.matchedPet);
  @override
  List<Object?> get props => [matchedPet];
}

class PetMatchError extends PetMatchState {
  final String message;
  const PetMatchError(this.message);
  @override
  List<Object?> get props => [message];
}

// --- BLoC ---
class PetMatchBloc extends Bloc<PetMatchEvent, PetMatchState> {
  final PetRepository repository;

  PetMatchBloc({required this.repository}) : super(PetMatchLoading()) {
    on<LoadPetsEvent>(_onLoadPets);
    on<SwipePetLeft>(_onSwipeLeft);
    on<SwipePetRight>(_onSwipeRight);
    on<SwipePetUp>(_onSwipeUp);
    on<TogglePetFavoriteEvent>(_onToggleFavorite);
    on<ApplyQuizFilterEvent>(_onApplyQuiz);
    on<ResetQuizFilterEvent>(_onResetQuiz);
  }

  Future<void> _onLoadPets(LoadPetsEvent event, Emitter<PetMatchState> emit) async {
    emit(PetMatchLoading());
    try {
      final pets = await repository.fetchAvailablePets(
        category: event.category,
        searchQuery: event.searchQuery,
        maxDistanceKm: event.maxDistanceKm,
        kidSafeOnly: event.kidSafeOnly,
        apartmentOnly: event.apartmentOnly,
        vaccinatedOnly: event.vaccinatedOnly,
      );
      bool quizDone = false;
      try {
        quizDone = repository.hasCompletedQuiz;
      } catch (_) {
        quizDone = false;
      }
      emit(PetMatchLoaded(
        pets: pets,
        selectedCategory: event.category ?? 'All Pets',
        searchQuery: event.searchQuery ?? '',
        hasCompletedQuiz: quizDone,
      ));
    } catch (e) {
      emit(PetMatchError('Failed to load pets: ${e.toString()}'));
    }
  }

  Future<void> _onSwipeLeft(SwipePetLeft event, Emitter<PetMatchState> emit) async {
    if (state is PetMatchLoaded) {
      final currentState = state as PetMatchLoaded;
      final nextIndex = currentState.currentSwipeIndex + 1;
      emit(currentState.copyWith(currentSwipeIndex: nextIndex));
    }
  }

  Future<void> _onSwipeRight(SwipePetRight event, Emitter<PetMatchState> emit) async {
    if (state is PetMatchLoaded) {
      final currentState = state as PetMatchLoaded;
      final pet = currentState.pets.firstWhere((p) => p.id == event.petId, orElse: () => currentState.pets.first);
      await repository.toggleFavorite(event.petId);
      final nextIndex = currentState.currentSwipeIndex + 1;
      emit(currentState.copyWith(
        lastMatchedPet: pet,
        currentSwipeIndex: nextIndex,
      ));
    }
  }

  Future<void> _onSwipeUp(SwipePetUp event, Emitter<PetMatchState> emit) async {
    if (state is PetMatchLoaded) {
      final currentState = state as PetMatchLoaded;
      final pet = currentState.pets.firstWhere((p) => p.id == event.petId, orElse: () => currentState.pets.first);
      final nextIndex = currentState.currentSwipeIndex + 1;
      emit(currentState.copyWith(
        lastMatchedPet: pet,
        currentSwipeIndex: nextIndex,
      ));
    }
  }

  Future<void> _onToggleFavorite(TogglePetFavoriteEvent event, Emitter<PetMatchState> emit) async {
    if (state is PetMatchLoaded) {
      final currentState = state as PetMatchLoaded;
      await repository.toggleFavorite(event.petId);
      final updatedPets = currentState.pets.map((p) {
        if (p.id == event.petId) {
          return p.copyWith(isFavorite: !p.isFavorite);
        }
        return p;
      }).toList();
      emit(currentState.copyWith(pets: updatedPets));
    }
  }

  Future<void> _onApplyQuiz(ApplyQuizFilterEvent event, Emitter<PetMatchState> emit) async {
    emit(PetMatchLoading());
    repository.updateCompatibilityScoreFromQuiz(
      housing: event.housing,
      hasKids: event.hasKids,
      hasPets: event.hasPets,
      hoursAlone: event.hoursAlone,
      experience: event.experience,
    );
    final pets = await repository.fetchAvailablePets();
    emit(PetMatchLoaded(
      pets: pets,
      hasCompletedQuiz: true,
    ));
  }

  Future<void> _onResetQuiz(ResetQuizFilterEvent event, Emitter<PetMatchState> emit) async {
    emit(PetMatchLoading());
    await repository.resetQuiz();
    final pets = await repository.fetchAvailablePets();
    emit(PetMatchLoaded(
      pets: pets,
      hasCompletedQuiz: false,
    ));
  }
}

