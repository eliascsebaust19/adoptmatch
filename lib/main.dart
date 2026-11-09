import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/theme/app_theme.dart';
import 'core/localization/app_locale.dart';
import 'core/navigation/app_router.dart';
import 'core/repositories/pet_repository.dart';
import 'core/services/local_storage_service.dart';
import 'core/storage/secure_storage_service.dart';
import 'features/auth/bloc/auth_bloc.dart';
import 'features/adoption_match/bloc/pet_match_bloc.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: const String.fromEnvironment(
      'SUPABASE_URL',
      defaultValue: 'https://haxrxmcggaspjhdltfvk.supabase.co',
    ),
    anonKey: const String.fromEnvironment(
      'SUPABASE_ANON_KEY',
      defaultValue: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImhheHJ4bWNnZ2FzcGpoZGx0ZnZrIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTIyNDc2MDAsImV4cCI6MjEwNzgyMzYwMH0.7tKIlhHcS6ZJQ_2H9VrRDn5dgE4YSMRfGeYt2SA7zYc',
    ),
  );
  await LocalStorageService.instance.init();
  // Drop plaintext session/profile copies written by older builds.
  await SecureStorageService.instance.purgeLegacyPlaintextCopies();
  final petRepository = PetRepository();

  runApp(AdoptMatchApp(petRepository: petRepository));
}

class AdoptMatchApp extends StatefulWidget {
  final PetRepository petRepository;

  const AdoptMatchApp({super.key, required this.petRepository});

  @override
  State<AdoptMatchApp> createState() => _AdoptMatchAppState();
}

class _AdoptMatchAppState extends State<AdoptMatchApp> {
  AppLanguage _currentLanguage = AppLanguage.en;

  void _onLanguageChanged(AppLanguage newLang) {
    setState(() {
      _currentLanguage = newLang;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [RepositoryProvider.value(value: widget.petRepository)],
      child: MultiBlocProvider(
        providers: [
          BlocProvider<AuthBloc>.value(value: AppRouter.defaultAuthBloc),
          BlocProvider<PetMatchBloc>(
            create: (context) =>
                PetMatchBloc(repository: widget.petRepository)
                  ..add(const LoadPetsEvent()),
          ),
        ],
        child: AppLocaleScope(
          language: _currentLanguage,
          onLanguageChanged: _onLanguageChanged,
          child: MaterialApp.router(
            title: 'AdoptMatch',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: ThemeMode.light,
            routerConfig: AppRouter.router,
          ),
        ),
      ),
    );
  }
}
