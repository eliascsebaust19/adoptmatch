import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../services/local_storage_service.dart';
import '../../features/splash/screens/splash_screen.dart';
import '../../features/onboarding/screens/onboarding_screen.dart';
import '../../features/auth/bloc/auth_bloc.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/screens/otp_screen.dart';
import '../../features/auth/screens/auth_callback_screen.dart';
import '../../features/auth/screens/reset_password_screen.dart';

// Consumer Screens
import '../../features/main_navigation/screens/main_nav_screen.dart';
import '../../features/adoption_match/screens/discover_screen.dart';
import '../../features/adoption_match/screens/swipe_match_screen.dart';
import '../../features/adoption_match/screens/quiz_screen.dart';
import '../../features/pet_profile/screens/pet_detail_screen.dart';
import '../../features/application/screens/adoption_application_screen.dart';
import '../../features/application/screens/application_tracker_screen.dart';
import '../../features/health_passport/screens/health_passport_screen.dart';
import '../../features/emergency_sos/screens/emergency_sos_screen.dart';
import '../../features/chat/screens/chat_inbox_screen.dart';
import '../../features/chat/screens/chat_conversation_screen.dart';
import '../../features/community/screens/happy_tails_feed_screen.dart';
import '../../features/profile/screens/profile_screen.dart';
import '../../features/profile/screens/edit_profile_screen.dart';
import '../../features/notifications/screens/notifications_screen.dart';
import '../../features/appointments/screens/appointments_screen.dart';
import '../../features/adoption_match/screens/pet_comparison_screen.dart';
import '../../features/clinics/screens/nearby_clinics_screen.dart';
import '../../features/ai_assistant/screens/ai_assistant_screen.dart';

// Admin Enterprise Screens
import '../../features/admin/layouts/admin_dashboard_layout.dart';
import '../../features/admin/screens/admin_login_screen.dart';
import '../../features/admin/screens/admin_dashboard_screen.dart';
import '../../features/admin/screens/shelter_approval_screen.dart';
import '../../features/admin/screens/pet_moderation_screen.dart';
import '../../features/admin/screens/adoption_tracking_screen.dart';
import '../../features/admin/screens/user_management_screen.dart';
import '../../features/admin/screens/audit_logs_screen.dart';
import '../../features/admin/screens/subscription_management_screen.dart';
import '../../features/subscription/screens/go_premium_screen.dart';
import '../../features/subscription/screens/my_subscription_screen.dart';

/// Helper to convert a Stream into a Listenable for GoRouter refresh
class GoRouterRefreshStream extends ChangeNotifier {
  late final StreamSubscription<dynamic> _subscription;

  GoRouterRefreshStream(Stream<dynamic> stream) {
    notifyListeners();
    _subscription = stream.asBroadcastStream().listen(
      (dynamic _) => notifyListeners(),
    );
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

class AppRouter {
  static final AuthBloc defaultAuthBloc = AuthBloc();

  /// Root navigator key for full-screen modals, dialogs, and nested sub-screens
  /// that should slide over the bottom navigation bar.
  static final GlobalKey<NavigatorState> rootNavigatorKey =
      GlobalKey<NavigatorState>(debugLabel: 'rootNavigator');

  /// Branch navigator keys for preserving independent tab history & scroll state.
  static final GlobalKey<NavigatorState> homeTabNavigatorKey =
      GlobalKey<NavigatorState>(debugLabel: 'homeTabNavigator');
  static final GlobalKey<NavigatorState> matchTabNavigatorKey =
      GlobalKey<NavigatorState>(debugLabel: 'matchTabNavigator');
  static final GlobalKey<NavigatorState> chatTabNavigatorKey =
      GlobalKey<NavigatorState>(debugLabel: 'chatTabNavigator');
  static final GlobalKey<NavigatorState> feedTabNavigatorKey =
      GlobalKey<NavigatorState>(debugLabel: 'feedTabNavigator');
  static final GlobalKey<NavigatorState> profileTabNavigatorKey =
      GlobalKey<NavigatorState>(debugLabel: 'profileTabNavigator');

  static GoRouter createRouter([AuthBloc? bloc]) {
    final authBloc = bloc ?? defaultAuthBloc;

    return GoRouter(
      navigatorKey: rootNavigatorKey,
      initialLocation: '/splash',
      refreshListenable: GoRouterRefreshStream(authBloc.stream),
      redirect: (context, state) {
        final authState = authBloc.state;
        final isAuthenticated = authState is Authenticated;
        // Read through the promoted local: `authState` is only widened by the
        // bool above, so `.user` / `.pendingRoute` need the explicit cast.
        final authenticated = authState is Authenticated ? authState : null;
        final user = authenticated?.user;
        final role = user?.role ?? UserRole.adopter;
        final hasAdminAccess = role.hasAdminAccess;

        final path = state.uri.path;
        final isAdminPath = path.startsWith('/admin') || path.startsWith('/shelter');
        final isAdminLogin = path == '/admin/login';
        final hasSeenOnboarding = LocalStorageService.instance.hasSeenOnboarding;
        final isOnboardingPath = path == '/onboarding';
        final isSplashPath = path == '/splash';
        final isAuthCallback = path == '/auth-callback' ||
            path == '/auth/callback' ||
            path == '/auth/reset-password';

        // 0. Splash screen has priority to verify session & route
        if (isSplashPath) {
          return null;
        }

        // 1. Authenticated users:
        if (isAuthenticated) {
          // The callback screen still has to hand the session to the bloc and
          // show its confirmation. Redirecting out from under it loses the
          // "new user" welcome and, on web, the URL cleanup.
          if (isAuthCallback) {
            return null;
          }
          // A recovery deep link asks for the password form, not the app.
          if (path == '/login') {
            return authenticated?.pendingRoute ??
                (hasAdminAccess ? '/admin/dashboard' : '/home');
          }
          // If on auth or onboarding screens, redirect to destination
          if (isOnboardingPath || path == '/register') {
            return hasAdminAccess ? '/admin/dashboard' : '/home';
          }
          // Guard admin vs consumer
          if (hasAdminAccess && !isAdminPath) {
            return '/admin/dashboard';
          }
          if (!hasAdminAccess && isAdminPath && !isAdminLogin) {
            return '/home';
          }
          if (isAdminLogin) {
            return hasAdminAccess ? '/admin/dashboard' : '/home';
          }
          return null;
        }

        // 2. Unauthenticated first-time visitors:
        if (!hasSeenOnboarding &&
            !isAdminPath &&
            !isAuthCallback &&
            path != '/login' &&
            path != '/register') {
          if (!isOnboardingPath) {
            return '/onboarding';
          }
          return null;
        }

        // 3. Returning visitors who have completed onboarding should skip /onboarding
        if (isOnboardingPath && hasSeenOnboarding) {
          return '/login';
        }

        // 4. Guarding Admin & Shelter Routes:
        if (isAdminPath && !isAdminLogin) {
          return '/admin/login';
        }

        // 5. Unauthenticated users attempting to access account-restricted screens
        if (!isAdminPath &&
            !isAuthCallback &&
            path != '/login' &&
            path != '/onboarding') {
          if (path.startsWith('/profile') || path.startsWith('/chat') || path.startsWith('/applications')) {
            return '/login';
          }
        }

        return null;
      },
      routes: [
        // ==========================================
        // 1. STATEFUL BOTTOM NAVIGATION SHELL ROUTE
        // ==========================================
        StatefulShellRoute.indexedStack(
          parentNavigatorKey: rootNavigatorKey,
          builder: (context, state, navigationShell) {
            return MainNavScreen(navigationShell: navigationShell);
          },
          branches: [
            // Branch 0: Discover / Home Feed
            StatefulShellBranch(
              navigatorKey: homeTabNavigatorKey,
              routes: [
                GoRoute(
                  path: '/home',
                  builder: (context, state) => const DiscoverScreen(),
                ),
              ],
            ),

            // Branch 1: Match / Swipe
            StatefulShellBranch(
              navigatorKey: matchTabNavigatorKey,
              routes: [
                GoRoute(
                  path: '/match',
                  builder: (context, state) => const SwipeMatchScreen(),
                ),
                GoRoute(
                  path: '/swipe',
                  builder: (context, state) => const SwipeMatchScreen(),
                ),
              ],
            ),

            // Branch 2: Chat Inbox
            StatefulShellBranch(
              navigatorKey: chatTabNavigatorKey,
              routes: [
                GoRoute(
                  path: '/chat',
                  builder: (context, state) => const ChatInboxScreen(),
                ),
              ],
            ),

            // Branch 3: Happy Tails Feed / Community
            StatefulShellBranch(
              navigatorKey: feedTabNavigatorKey,
              routes: [
                GoRoute(
                  path: '/community',
                  builder: (context, state) => const HappyTailsFeedScreen(),
                ),
              ],
            ),

            // Branch 4: User Profile & Account Settings
            StatefulShellBranch(
              navigatorKey: profileTabNavigatorKey,
              routes: [
                GoRoute(
                  path: '/profile',
                  builder: (context, state) => const ProfileScreen(),
                ),
              ],
            ),
          ],
        ),

        // ==========================================
        // 2. ADMIN ENTERPRISE PORTAL ROUTES
        // ==========================================
        GoRoute(
          parentNavigatorKey: rootNavigatorKey,
          path: '/admin/login',
          builder: (context, state) => const AdminLoginScreen(),
        ),

        // Top-level Shelter Management Admin Dashboard
        GoRoute(
          parentNavigatorKey: rootNavigatorKey,
          path: '/admin/dashboard',
          builder: (context, state) => const AdminDashboardScreen(),
        ),

        ShellRoute(
          parentNavigatorKey: rootNavigatorKey,
          builder: (context, state, child) {
            return AdminDashboardLayout(child: child);
          },
          routes: [
            GoRoute(
              path: '/admin/shelters',
              builder: (context, state) => const ShelterApprovalScreen(),
            ),
            GoRoute(
              path: '/admin/pets',
              builder: (context, state) => const PetModerationScreen(),
            ),
            GoRoute(
              path: '/admin/adoptions',
              builder: (context, state) => const AdoptionTrackingScreen(),
            ),
            GoRoute(
              path: '/admin/users',
              builder: (context, state) => const UserManagementScreen(),
            ),
            GoRoute(
              path: '/admin/audit-logs',
              builder: (context, state) => const AuditLogsScreen(),
            ),
            GoRoute(
              path: '/admin/subscriptions',
              builder: (context, state) => const SubscriptionManagementScreen(),
            ),
          ],
        ),

        // ==========================================
        // 0. SPLASH & ONBOARDING ROUTES
        // ==========================================
        GoRoute(
          parentNavigatorKey: rootNavigatorKey,
          path: '/splash',
          builder: (context, state) => const SplashScreen(),
        ),
        GoRoute(
          parentNavigatorKey: rootNavigatorKey,
          path: '/onboarding',
          builder: (context, state) => const OnboardingScreen(),
        ),

        // ==========================================
        // 3. AUTHENTICATION ROUTES
        // ==========================================
        GoRoute(
          parentNavigatorKey: rootNavigatorKey,
          path: '/login',
          builder: (context, state) => const LoginScreen(),
        ),
        GoRoute(
          parentNavigatorKey: rootNavigatorKey,
          path: '/auth/login',
          builder: (context, state) => const LoginScreen(),
        ),
        GoRoute(
          parentNavigatorKey: rootNavigatorKey,
          path: '/auth/callback',
          builder: (context, state) => _authRedirectTarget(state),
        ),
        GoRoute(
          parentNavigatorKey: rootNavigatorKey,
          path: '/auth-callback',
          builder: (context, state) => _authRedirectTarget(state),
        ),
        GoRoute(
          parentNavigatorKey: rootNavigatorKey,
          path: '/auth/reset-password',
          builder: (context, state) => const ResetPasswordScreen(),
        ),
        GoRoute(
          parentNavigatorKey: rootNavigatorKey,
          path: '/auth/otp',
          builder: (context, state) {
            final phone = state.extra as String? ?? '+880 1711 234567';
            return OtpVerificationScreen(phoneNumber: phone);
          },
        ),

        // ==========================================
        // 4. SUB-SCREENS (PUSHED OVER BOTTOM BAR)
        // ==========================================
        GoRoute(
          parentNavigatorKey: rootNavigatorKey,
          path: '/quiz',
          builder: (context, state) => const CompatibilityQuizScreen(),
        ),
        GoRoute(
          parentNavigatorKey: rootNavigatorKey,
          path: '/pets/:id',
          builder: (context, state) {
            final petId = state.pathParameters['id'] ?? 'p1';
            return PetDetailScreen(petId: petId);
          },
        ),
        GoRoute(
          parentNavigatorKey: rootNavigatorKey,
          path: '/pet/:id',
          builder: (context, state) {
            final petId = state.pathParameters['id'] ?? 'p1';
            return PetDetailScreen(petId: petId);
          },
        ),
        GoRoute(
          parentNavigatorKey: rootNavigatorKey,
          path: '/apply/:id',
          builder: (context, state) {
            final petId = state.pathParameters['id'] ?? 'p1';
            return AdoptionApplicationScreen(petId: petId);
          },
        ),
        GoRoute(
          parentNavigatorKey: rootNavigatorKey,
          path: '/find',
          builder: (context, state) => const SwipeMatchScreen(),
        ),
        GoRoute(
          parentNavigatorKey: rootNavigatorKey,
          path: '/applications',
          builder: (context, state) => const ApplicationTrackerScreen(),
        ),
        GoRoute(
          parentNavigatorKey: rootNavigatorKey,
          path: '/applications/tracker',
          builder: (context, state) => const ApplicationTrackerScreen(),
        ),
        GoRoute(
          parentNavigatorKey: rootNavigatorKey,
          path: '/applications-tracker',
          builder: (context, state) => const ApplicationTrackerScreen(),
        ),
        GoRoute(
          parentNavigatorKey: rootNavigatorKey,
          path: '/application-tracker',
          builder: (context, state) => const ApplicationTrackerScreen(),
        ),
        GoRoute(
          parentNavigatorKey: rootNavigatorKey,
          path: '/tracker',
          builder: (context, state) => const ApplicationTrackerScreen(),
        ),
        GoRoute(
          parentNavigatorKey: rootNavigatorKey,
          path: '/my-applications',
          builder: (context, state) => const ApplicationTrackerScreen(),
        ),
        GoRoute(
          parentNavigatorKey: rootNavigatorKey,
          path: '/health-passport',
          builder: (context, state) => const HealthPassportScreen(),
        ),
        GoRoute(
          parentNavigatorKey: rootNavigatorKey,
          path: '/health/:id',
          builder: (context, state) {
            final petId = state.pathParameters['id'] ?? 'p1';
            return HealthPassportScreen(petId: petId);
          },
        ),
        GoRoute(
          parentNavigatorKey: rootNavigatorKey,
          path: '/emergency',
          builder: (context, state) => const EmergencySosScreen(),
        ),
        GoRoute(
          parentNavigatorKey: rootNavigatorKey,
          path: '/chat/:chatId',
          builder: (context, state) {
            final chatId = state.pathParameters['chatId'] ?? 'c-001';
            return ChatConversationScreen(conversationId: chatId);
          },
        ),
        GoRoute(
          parentNavigatorKey: rootNavigatorKey,
          path: '/shelter/admin',
          builder: (context, state) => const AdminDashboardScreen(),
        ),
        GoRoute(
          parentNavigatorKey: rootNavigatorKey,
          path: '/profile/edit',
          builder: (context, state) => const EditProfileScreen(),
        ),
        GoRoute(
          parentNavigatorKey: rootNavigatorKey,
          path: '/notifications',
          builder: (context, state) => const NotificationsScreen(),
        ),
        GoRoute(
          parentNavigatorKey: rootNavigatorKey,
          path: '/appointments',
          builder: (context, state) => const AppointmentsScreen(),
        ),
        GoRoute(
          parentNavigatorKey: rootNavigatorKey,
          path: '/compare',
          builder: (context, state) => const PetComparisonScreen(),
        ),
        GoRoute(
          parentNavigatorKey: rootNavigatorKey,
          path: '/compare/:id',
          builder: (context, state) {
            final petId = state.pathParameters['id'];
            return PetComparisonScreen(initialPetId: petId);
          },
        ),
        GoRoute(
          parentNavigatorKey: rootNavigatorKey,
          path: '/clinics',
          builder: (context, state) => const NearbyClinicsScreen(),
        ),
        GoRoute(
          parentNavigatorKey: rootNavigatorKey,
          path: '/ai-assistant',
          builder: (context, state) => const AiAssistantScreen(),
        ),
        GoRoute(
          parentNavigatorKey: rootNavigatorKey,
          path: '/subscription/plans',
          builder: (context, state) => const GoPremiumScreen(),
        ),
        GoRoute(
          parentNavigatorKey: rootNavigatorKey,
          path: '/subscription/my',
          builder: (context, state) => const MySubscriptionScreen(),
        ),
      ],
      errorBuilder: (context, state) => Scaffold(
        appBar: AppBar(
          title: const Text('Page Not Found'),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.pets, size: 64, color: Color(0xFF0D9488)),
              const SizedBox(height: 16),
              const Text(
                'Page Not Found',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'We couldn\'t find the requested page.',
                style: const TextStyle(color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => context.go('/home'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0D9488),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Back to Home'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// A recovery link carries `?type=recovery`; everything else is a normal
  /// sign-in or confirmation callback.
  static Widget _authRedirectTarget(GoRouterState state) {
    if (state.uri.queryParameters['type'] == 'recovery') {
      return const ResetPasswordScreen();
    }
    return const AuthCallbackScreen();
  }

  static final GoRouter router = createRouter();
}
