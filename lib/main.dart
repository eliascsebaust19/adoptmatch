import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'core/theme/app_theme.dart';
import 'core/localization/app_locale.dart';
import 'core/navigation/app_router.dart';
import 'core/repositories/pet_repository.dart';
import 'core/services/supabase_service.dart';
import 'core/services/local_storage_service.dart';
import 'features/auth/bloc/auth_bloc.dart';
import 'features/adoption_match/bloc/pet_match_bloc.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SupabaseService.initialize();
  await LocalStorageService.instance.init();
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
      providers: [
        RepositoryProvider.value(value: widget.petRepository),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider<AuthBloc>.value(
            value: AppRouter.defaultAuthBloc,
          ),
          BlocProvider<PetMatchBloc>(
            create: (context) => PetMatchBloc(repository: widget.petRepository)
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
