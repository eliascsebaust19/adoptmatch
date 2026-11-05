import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../adoption_match/bloc/pet_match_bloc.dart';
import '../../adoption_match/widgets/pet_card_grid_item.dart';

class FavoritesScreen extends StatelessWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const teal = Color(0xFF0D9488);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Saved & Favorite Pets'),
      ),
      body: BlocBuilder<PetMatchBloc, PetMatchState>(
        builder: (context, state) {
          if (state is PetMatchLoading) {
            return const Center(child: CircularProgressIndicator(color: teal));
          }

          if (state is PetMatchLoaded) {
            final favorites = state.pets.where((p) => p.isFavorite).toList();

            if (favorites.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.favorite_border, size: 64, color: Colors.grey),
                      const SizedBox(height: 16),
                      const Text(
                        'No favorites yet',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Tap the heart icon on any pet card to save them here for quick access.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              );
            }

            return GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 0.76,
              ),
              itemCount: favorites.length,
              itemBuilder: (context, index) {
                final pet = favorites[index];
                return PetCardGridItem(
                  pet: pet,
                  onTap: () => context.push('/pets/${pet.id}'),
                  onFavoriteToggle: () {
                    context.read<PetMatchBloc>().add(TogglePetFavoriteEvent(pet.id));
                  },
                );
              },
            );
          }

          return const SizedBox();
        },
      ),
    );
  }
}

