import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/theme/app_theme.dart';
import 'core/localization/app_locale.dart';
import 'core/navigation/app_router.dart';
import 'core/platform/url_strategy.dart';
import 'core/repositories/pet_repository.dart';
import 'core/services/local_storage_service.dart';
import 'core/storage/secure_storage_service.dart';
import 'features/auth/bloc/auth_bloc.dart';
import 'features/adoption_match/bloc/pet_match_bloc.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Web must use path URLs (`/auth-callback?code=...`) so the Supabase OAuth
  // and email links keep their query string. This has to run before the
  // binding reads the route name, i.e. before runApp.
  configureUrlStrategyForBrowser();
  await Supabase.initialize(
    url: const String.fromEnvironment(
      'SUPABASE_URL',
      defaultValue: 'https://wgztdhabgedhkaippkpd.supabase.co',
    ),
    anonKey: const String.fromEnvironment(
      'SUPABASE_ANON_KEY',
      defaultValue: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6IndnenRkaGFiZ2VkaGthaXBwa3BkIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTI3ODAzMTksImV4cCI6MjEwODM1NjMxOX0.KolY1dw6NuDxZAt14bCcJz0NLLmMa05HHixz4TFtZMM',
    ),
    // PKCE is required for the web OAuth redirect: the code returned on
    // /auth-callback is exchanged by SupabaseService.completeWebRedirect().
    authOptions: const FlutterAuthClientOptions(
      authFlowType: AuthFlowType.pkce,
    ),
    debug: kDebugMode,
  );
  _bridgeSupabaseSession();
  await LocalStorageService.instance.init();
  // Drop plaintext session/profile copies written by older builds.
  await SecureStorageService.instance.purgeLegacyPlaintextCopies();
  final petRepository = PetRepository();

  runApp(AdoptMatchApp(petRepository: petRepository));
}

/// Keeps the app session in sync with Supabase Auth.
///
/// A mobile OAuth / confirmation deep link (`adoptmatch://auth-callback`) is
/// redeemed by the plugin in the background, so the signed-in user would only
/// appear after a restart. Watching the auth stream covers that, and also
/// covers token refreshes.
void _bridgeSupabaseSession() {
  Supabase.instance.client.auth.onAuthStateChange.listen((data) {
    // A recovery deep link signs the user in with a short-lived session. Send
    // them to the password form instead of letting them wander the app on a
    // session that expires in minutes.
    if (data.event == AuthChangeEvent.passwordRecovery) {
      AppRouter.router.go('/auth/reset-password');
      return;
    }

    final signedIn = data.event == AuthChangeEvent.signedIn ||
        data.event == AuthChangeEvent.tokenRefreshed ||
        data.event == AuthChangeEvent.userUpdated;
    if (!signedIn || data.session == null) return;
    final bloc = AppRouter.defaultAuthBloc;
    final state = bloc.state;
    // Only fill a genuinely empty session. While a sign-in is in flight the
    // bloc is already resolving the profile, and a second concurrent check
    // could report a failure over a session that just succeeded.
    if (state is Authenticated || state is AuthLoading) return;
    bloc.add(const CheckSessionEvent());
  });
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
