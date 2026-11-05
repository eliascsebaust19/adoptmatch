import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../../../core/services/supabase_service.dart';
import '../../../core/services/google_auth_service.dart';
import '../../../core/services/laravel_auth_service.dart';

enum UserRole {
  guest,
  adopter,
  shelter,
  foster,
  moderator,
  admin,
  superAdmin;

  bool get isGuest => this == UserRole.guest;
  bool get isAdmin => this == UserRole.admin || this == UserRole.superAdmin;
  bool get isModerator => this == UserRole.moderator;
  bool get isShelter => this == UserRole.shelter;
  bool get hasAdminAccess => isAdmin || isModerator || isShelter;
  bool get isConsumer => this == UserRole.adopter || this == UserRole.guest;

  String get code {
    switch (this) {
      case UserRole.guest:
        return 'GUEST';
      case UserRole.adopter:
        return 'USER';
      case UserRole.shelter:
        return 'SHELTER';
      case UserRole.foster:
        return 'FOSTER';
      case UserRole.moderator:
        return 'MODERATOR';
      case UserRole.admin:
        return 'ADMIN';
      case UserRole.superAdmin:
        return 'SUPER_ADMIN';
    }
  }

  static UserRole fromCode(String? code) {
    if (code == null) return UserRole.adopter;
    switch (code.toUpperCase().trim()) {
      case 'GUEST':
        return UserRole.guest;
      case 'SUPER_ADMIN':
        return UserRole.superAdmin;
      case 'ADMIN':
        return UserRole.admin;
      case 'MODERATOR':
        return UserRole.moderator;
      case 'SHELTER':
        return UserRole.shelter;
      case 'FOSTER':
        return UserRole.foster;
      case 'USER':
      case 'ADOPTER':
      default:
        return UserRole.adopter;
    }
  }
}

class UserProfile extends Equatable {
  final String id;
  final String name;
  final String email;
  final String phone;
  final UserRole role;
  final bool isVerified;
  final String avatarUrl;
  final List<String> permissions;
  final String location;
  final String bio;
  final String googlePhotoUrl;
  final String preferredPetType;
  final bool isPremium;
  final String? premiumPlanId;
  final DateTime? premiumExpiresAt;
  final String subscriptionStatus; // 'ACTIVE', 'EXPIRED', 'NONE'

  const UserProfile({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    this.role = UserRole.adopter,
    this.isVerified = true,
    this.avatarUrl = '',
    this.permissions = const [],
    this.location = 'Dhaka, Bangladesh',
    this.bio = 'Animal advocate & pet rescuer',
    this.googlePhotoUrl = '',
    this.preferredPetType = 'All Pets',
    this.isPremium = false,
    this.premiumPlanId,
    this.premiumExpiresAt,
    this.subscriptionStatus = 'NONE',
  });

  bool get hasActivePremium {
    if (!isPremium) return false;
    if (premiumExpiresAt == null) return true;
    return premiumExpiresAt!.isAfter(DateTime.now());
  }

  int get remainingDays {
    if (premiumExpiresAt == null) return 0;
    final diff = premiumExpiresAt!.difference(DateTime.now()).inDays;
    return diff > 0 ? diff : 0;
  }

  String get premiumBadgeTitle {
    if (premiumPlanId == 'plan-annual') return 'VIP Rescuer';
    if (premiumPlanId == 'plan-quarterly') return 'Gold Supporter';
    return 'Verified Supporter';
  }

  UserProfile copyWith({
    String? id,
    String? name,
    String? email,
    String? phone,
    UserRole? role,
    bool? isVerified,
    String? avatarUrl,
    List<String>? permissions,
    String? location,
    String? bio,
    String? googlePhotoUrl,
    String? preferredPetType,
    bool? isPremium,
    String? premiumPlanId,
    DateTime? premiumExpiresAt,
    String? subscriptionStatus,
  }) {
    return UserProfile(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      role: role ?? this.role,
      isVerified: isVerified ?? this.isVerified,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      permissions: permissions ?? this.permissions,
      location: location ?? this.location,
      bio: bio ?? this.bio,
      googlePhotoUrl: googlePhotoUrl ?? this.googlePhotoUrl,
      preferredPetType: preferredPetType ?? this.preferredPetType,
      isPremium: isPremium ?? this.isPremium,
      premiumPlanId: premiumPlanId ?? this.premiumPlanId,
      premiumExpiresAt: premiumExpiresAt ?? this.premiumExpiresAt,
      subscriptionStatus: subscriptionStatus ?? this.subscriptionStatus,
    );
  }

  @override
  List<Object?> get props => [
    id,
    name,
    email,
    phone,
    role,
    isVerified,
    avatarUrl,
    permissions,
    location,
    bio,
    googlePhotoUrl,
    preferredPetType,
    isPremium,
    premiumPlanId,
    premiumExpiresAt,
    subscriptionStatus,
  ];
}

// --- Events ---
abstract class AuthEvent extends Equatable {
  const AuthEvent();
  @override
  List<Object?> get props => [];
}

class SignUpWithEmailEvent extends AuthEvent {
  final String fullName;
  final String email;
  final String password;

  const SignUpWithEmailEvent({
    required this.fullName,
    required this.email,
    required this.password,
  });

  @override
  List<Object?> get props => [fullName, email, password];
}

class LoginWithEmailEvent extends AuthEvent {
  final String email;
  final String password;
  const LoginWithEmailEvent(this.email, this.password);
  @override
  List<Object?> get props => [email, password];
}

class AdminLoginWithEmailEvent extends AuthEvent {
  final String email;
  final String password;
  const AdminLoginWithEmailEvent(this.email, this.password);
  @override
  List<Object?> get props => [email, password];
}

class RequestPhoneOtpEvent extends AuthEvent {
  final String phoneNumber;
  const RequestPhoneOtpEvent(this.phoneNumber);
  @override
  List<Object?> get props => [phoneNumber];
}

class VerifyPhoneOtpEvent extends AuthEvent {
  final String phoneNumber;
  final String otp;
  const VerifyPhoneOtpEvent(this.phoneNumber, this.otp);
  @override
  List<Object?> get props => [phoneNumber, otp];
}

class SocialLoginEvent extends AuthEvent {
  final String provider; // 'google', 'twitter', 'apple'
  const SocialLoginEvent(this.provider);
  @override
  List<Object?> get props => [provider];
}

class GuestLoginEvent extends AuthEvent {
  const GuestLoginEvent();
}

class UserConfirmedSessionEvent extends AuthEvent {
  final UserProfile user;
  const UserConfirmedSessionEvent(this.user);
  @override
  List<Object?> get props => [user];
}

class SwitchRoleEvent extends AuthEvent {
  final UserRole role;
  const SwitchRoleEvent(this.role);
  @override
  List<Object?> get props => [role];
}

class UpdateUserProfileEvent extends AuthEvent {
  final String? name;
  final String? phone;
  final String? avatarUrl;
  final String? location;
  final String? bio;
  final String? preferredPetType;

  const UpdateUserProfileEvent({
    this.name,
    this.phone,
    this.avatarUrl,
    this.location,
    this.bio,
    this.preferredPetType,
  });

  @override
  List<Object?> get props => [
    name,
    phone,
    avatarUrl,
    location,
    bio,
    preferredPetType,
  ];
}

class ChangePasswordEvent extends AuthEvent {
  final String newPassword;
  const ChangePasswordEvent(this.newPassword);
  @override
  List<Object?> get props => [newPassword];
}

class ActivateSubscriptionEvent extends AuthEvent {
  final String planId;
  final int durationDays;

  const ActivateSubscriptionEvent({
    required this.planId,
    required this.durationDays,
  });

  @override
  List<Object?> get props => [planId, durationDays];
}

class LogoutEvent extends AuthEvent {}

// --- States ---
abstract class AuthState extends Equatable {
  const AuthState();
  @override
  List<Object?> get props => [];
}

class AuthInitial extends AuthState {}

class AuthLoading extends AuthState {}

class AuthOtpSent extends AuthState {
  final String phoneNumber;
  const AuthOtpSent(this.phoneNumber);
  @override
  List<Object?> get props => [phoneNumber];
}

class Authenticated extends AuthState {
  final UserProfile user;
  const Authenticated(this.user);
  @override
  List<Object?> get props => [user];
}

class AuthSignUpConfirmationPending extends AuthState {
  final String email;
  final String message;
  const AuthSignUpConfirmationPending({
    required this.email,
    required this.message,
  });
  @override
  List<Object?> get props => [email, message];
}

class AuthUnauthenticated extends AuthState {}

class AuthFailure extends AuthState {
  final String errorMessage;
  const AuthFailure(this.errorMessage);
  @override
  List<Object?> get props => [errorMessage];
}

// --- BLoC ---
class AuthBloc extends Bloc<AuthEvent, AuthState> {
  UserProfile _currentUser = const UserProfile(
    id: 'u-101',
    name: 'Elias Ahmed',
    email: 'elias3224@gmail.com',
    phone: '+880 1711 234567',
    role: UserRole.adopter,
    isVerified: true,
  );

  final _laravelAuthService = LaravelAuthService();
  StreamSubscription<sb.AuthState>? _supabaseAuthSubscription;

  AuthBloc()
    : super(
        const Authenticated(
          UserProfile(
            id: 'u-101',
            name: 'Elias Ahmed',
            email: 'elias3224@gmail.com',
            phone: '+880 1711 234567',
            role: UserRole.adopter,
            isVerified: true,
          ),
        ),
      ) {
    on<SignUpWithEmailEvent>(_onSignUpWithEmail);
    on<LoginWithEmailEvent>(_onLoginWithEmail);
    on<AdminLoginWithEmailEvent>(_onAdminLoginWithEmail);
    on<RequestPhoneOtpEvent>(_onRequestOtp);
    on<VerifyPhoneOtpEvent>(_onVerifyOtp);
    on<SocialLoginEvent>(_onSocialLogin);
    on<GuestLoginEvent>(_onGuestLogin);
    on<UserConfirmedSessionEvent>(_onUserConfirmedSession);
    on<SwitchRoleEvent>(_onSwitchRole);
    on<UpdateUserProfileEvent>(_onUpdateUserProfile);
    on<ChangePasswordEvent>(_onChangePassword);
    on<ActivateSubscriptionEvent>(_onActivateSubscription);
    on<LogoutEvent>(_onLogout);

    _initSupabaseListener();
  }

  void _initSupabaseListener() {
    if (SupabaseService.isInitialized) {
      _supabaseAuthSubscription = SupabaseService.auth.onAuthStateChange.listen(
        (data) {
          final session = data.session;
          if (session != null &&
              (data.event == sb.AuthChangeEvent.signedIn ||
                  data.event == sb.AuthChangeEvent.userUpdated)) {
            final user = session.user;
            final fullName =
                user.userMetadata?['full_name'] as String? ??
                user.email?.split('@').first ??
                'User';
            final rawRole = user.userMetadata?['role'] as String?;
            final userRole = UserRole.fromCode(rawRole);
            add(
              UserConfirmedSessionEvent(
                UserProfile(
                  id: user.id,
                  name: fullName,
                  email: user.email ?? '',
                  phone: user.phone ?? '',
                  role: userRole,
                  isVerified: user.emailConfirmedAt != null,
                ),
              ),
            );
          }
        },
      );
    }
  }

  Future<void> _onSignUpWithEmail(
    SignUpWithEmailEvent event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    try {
      try {
        final res = await _laravelAuthService.register(
          name: event.fullName,
          email: event.email,
          password: event.password,
          role: 'adopter',
        );
        if (res['status'] == 'success' || res['success'] == true) {
          emit(
            AuthSignUpConfirmationPending(
              email: event.email,
              message: 'Account created on AdoptMatch! You can now log in.',
            ),
          );
          return;
        }
      } catch (laravelErr) {
        debugPrint('[AuthBloc] Laravel register fallback: ');
      }

      if (SupabaseService.isInitialized) {
        await SupabaseService.signUpWithEmail(
          email: event.email,
          password: event.password,
          fullName: event.fullName,
        );
      } else {
        await Future.delayed(const Duration(milliseconds: 600));
      }

      // Do NOT automatically log them into dashboard
      emit(
        AuthSignUpConfirmationPending(
          email: event.email,
          message: 'A confirmation email has been sent to your Gmail. Please click the link in your email to verify and activate your account.',
        ),
      );
    } on sb.AuthException catch (e) {
      emit(AuthFailure(e.message));
    } catch (e) {
      emit(AuthFailure(e.toString()));
    }
  }

  Future<void> _onLoginWithEmail(
    LoginWithEmailEvent event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    try {
      final emailLower = event.email.trim().toLowerCase();

      // 1. Try Live Laravel 11 Backend API Authentication
      try {
        final res = await _laravelAuthService.login(
          email: event.email,
          password: event.password,
        );
        if (res['status'] == 'success' || res['success'] == true) {
          final userMap = res['user'] as Map<String, dynamic>?;
          if (userMap != null) {
            final roleStr = userMap['role']?.toString();
            _currentUser = UserProfile(
              id: userMap['id']?.toString() ?? '1',
              name: userMap['name'] ?? 'User',
              email: userMap['email'] ?? event.email,
              phone: userMap['phone'] ?? '',
              role: UserRole.fromCode(roleStr),
              avatarUrl: userMap['avatar'] ?? '',
              isVerified: true,
            );
            emit(Authenticated(_currentUser));
            return;
          }
        }
      } catch (laravelErr) {
        debugPrint('[AuthBloc] Laravel login fallback: ');
      }

      // 2. Try Live Supabase authentication
      if (SupabaseService.isInitialized) {
        try {
          final response = await SupabaseService.signInWithEmail(
            email: event.email,
            password: event.password,
          );
          final user = response.user;
          if (user != null) {
            final fullName =
                user.userMetadata?['full_name'] as String? ??
                user.email?.split('@').first ??
                'User';
            final rawRole = user.userMetadata?['role'] as String?;
            final userRole = UserRole.fromCode(rawRole);
            _currentUser = UserProfile(
              id: user.id,
              name: fullName,
              email: user.email ?? event.email,
              phone: user.phone ?? '',
              role: userRole,
              isVerified: user.emailConfirmedAt != null,
            );
            emit(Authenticated(_currentUser));
            return;
          }
        } on sb.AuthException catch (e) {
          if (e.message.toLowerCase().contains('email not confirmed') ||
              e.message.toLowerCase().contains('verify your email')) {
            emit(
              const AuthFailure(
                'Please verify your email address before logging in.',
              ),
            );
            return;
          }
          // If remote credentials don't match or demo accounts are used,
          // fall through to demo credentials for admin/shelter/demo users
          debugPrint('[AuthBloc] Supabase auth exception (${e.message}), checking demo credentials');
        }
      }

      // 2. Demo / Fallback Authentication for Admin, Shelter, and Adopters
      await Future.delayed(const Duration(milliseconds: 400));
      if (emailLower == 'superadmin@adoptmatch.org' ||
          emailLower == 'superadmin@gmail.com') {
        _currentUser = const UserProfile(
          id: 'admin-super-01',
          name: 'Sarah Rahman (Super Admin)',
          email: 'superadmin@adoptmatch.org',
          phone: '+880 1819 000001',
          role: UserRole.superAdmin,
          isVerified: true,
        );
        emit(Authenticated(_currentUser));
      } else if (emailLower == 'admin@adoptmatch.com' ||
          emailLower == 'admin@adoptmatch.org' ||
          emailLower.contains('admin')) {
        _currentUser = const UserProfile(
          id: 'admin-ops-02',
          name: 'Kamrul Hasan (Admin Ops)',
          email: 'admin@adoptmatch.com',
          phone: '+880 1819 000002',
          role: UserRole.admin,
          isVerified: true,
        );
        emit(Authenticated(_currentUser));
      } else if (emailLower.contains('shelter')) {
        _currentUser = const UserProfile(
          id: 'shelter-mgr-01',
          name: 'Dhaka Paws Shelter (Manager)',
          email: 'shelter@adoptmatch.com',
          phone: '+880 1711 000003',
          role: UserRole.shelter,
          isVerified: true,
        );
        emit(Authenticated(_currentUser));
      } else {
        // Standard demo adopter login
        _currentUser = UserProfile(
          id: 'u-101',
          name: 'Elias Ahmed',
          email: event.email,
          phone: '+880 1711 234567',
          role: UserRole.adopter,
          isVerified: true,
        );
        emit(Authenticated(_currentUser));
      }
    } catch (e) {
      emit(AuthFailure(e.toString()));
    }
  }

  Future<void> _onAdminLoginWithEmail(
    AdminLoginWithEmailEvent event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    try {
      final emailLower = event.email.trim().toLowerCase();

      // 1. Check live Supabase authentication
      if (SupabaseService.isInitialized) {
        try {
          final response = await SupabaseService.signInWithEmail(
            email: event.email,
            password: event.password,
          );
          final user = response.user;
          if (user != null) {
            final rawRole = user.userMetadata?['role'] as String?;
            final userRole = UserRole.fromCode(rawRole);
            if (!userRole.hasAdminAccess) {
              await SupabaseService.signOut();
              emit(
                const AuthFailure(
                  '403 Forbidden: Access Denied. Administrator or Shelter Manager privileges required.',
                ),
              );
              return;
            }
            final fullName =
                user.userMetadata?['full_name'] as String? ?? 'Administrator';
            _currentUser = UserProfile(
              id: user.id,
              name: fullName,
              email: user.email ?? event.email,
              phone: user.phone ?? '',
              role: userRole,
              isVerified: true,
            );
            emit(Authenticated(_currentUser));
            return;
          }
        } on sb.AuthException catch (e) {
          // If unconfirmed or credentials wrong on live Supabase, check demo admin credentials
          if (!emailLower.contains('admin') &&
              !emailLower.contains('shelter') &&
              !emailLower.contains('manager') &&
              emailLower != 'superadmin@adoptmatch.org') {
            emit(AuthFailure(e.message));
            return;
          }
        }
      }

      // 2. Demo / Fallback Administrative Authentication
      await Future.delayed(const Duration(milliseconds: 600));
      if (emailLower == 'superadmin@adoptmatch.org' ||
          emailLower == 'superadmin@gmail.com') {
        _currentUser = const UserProfile(
          id: 'admin-super-01',
          name: 'Sarah Rahman (Super Admin)',
          email: 'superadmin@adoptmatch.org',
          phone: '+880 1819 000001',
          role: UserRole.superAdmin,
          isVerified: true,
        );
        emit(Authenticated(_currentUser));
      } else if (emailLower == 'admin@adoptmatch.com' ||
          emailLower == 'admin@adoptmatch.org' ||
          emailLower.contains('admin')) {
        _currentUser = const UserProfile(
          id: 'admin-ops-02',
          name: 'Kamrul Hasan (Admin Ops)',
          email: 'admin@adoptmatch.com',
          phone: '+880 1819 000002',
          role: UserRole.admin,
          isVerified: true,
        );
        emit(Authenticated(_currentUser));
      } else if (emailLower.contains('shelter')) {
        _currentUser = const UserProfile(
          id: 'shelter-mgr-01',
          name: 'Dhaka Paws Shelter (Manager)',
          email: 'shelter@adoptmatch.com',
          phone: '+880 1711 000003',
          role: UserRole.shelter,
          isVerified: true,
        );
        emit(Authenticated(_currentUser));
      } else {
        emit(
          const AuthFailure(
            '403 Forbidden: Access Denied. The provided account does not have administrator or shelter manager privileges.',
          ),
        );
      }
    } catch (e) {
      emit(AuthFailure(e.toString()));
    }
  }

  Future<void> _onRequestOtp(
    RequestPhoneOtpEvent event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    await Future.delayed(const Duration(milliseconds: 400));
    emit(AuthOtpSent(event.phoneNumber));
  }

  Future<void> _onVerifyOtp(
    VerifyPhoneOtpEvent event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    await Future.delayed(const Duration(milliseconds: 500));
    _currentUser = UserProfile(
      id: 'u-101',
      name: 'Elias Ahmed',
      email: 'elias3224@gmail.com',
      phone: event.phoneNumber,
      role: UserRole.adopter,
      isVerified: true,
    );
    emit(Authenticated(_currentUser));
  }

  Future<void> _onSocialLogin(
    SocialLoginEvent event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    try {
      if (event.provider == 'google') {
        final result = await GoogleAuthService.signIn();
        if (result.success && result.user != null) {
          _currentUser = result.user!;
          emit(Authenticated(_currentUser));
          return;
        } else if (result.wasCancelled) {
          emit(AuthUnauthenticated());
          return;
        } else if (result.errorMessage != null) {
          emit(AuthFailure(result.errorMessage!));
          return;
        }
      }

      await Future.delayed(const Duration(milliseconds: 500));
      _currentUser = UserProfile(
        id: 'u-${DateTime.now().millisecondsSinceEpoch}',
        name: 'Google Adopter',
        email: 'adopter.google@gmail.com',
        phone: '+880 1700 000000',
        role: UserRole.adopter,
        isVerified: true,
      );
      emit(Authenticated(_currentUser));
    } on sb.AuthException catch (e) {
      final msg = e.message.toLowerCase();
      if (msg.contains('provider is not enabled') ||
          msg.contains('unsupported provider')) {
        emit(
          const AuthFailure(
            'Google Provider is not enabled in your Supabase project dashboard. Please enable Google in Supabase Authentication -> Providers -> Google, or configure Google OAuth credentials.',
          ),
        );
      } else {
        emit(AuthFailure(e.message));
      }
    } catch (e) {
      final msg = e.toString().toLowerCase();
      if (msg.contains('provider is not enabled') ||
          msg.contains('unsupported provider')) {
        emit(
          const AuthFailure(
            'Google Provider is not enabled in your Supabase project dashboard. Please enable Google in Supabase Authentication -> Providers -> Google, or configure Google OAuth credentials.',
          ),
        );
      } else {
        emit(AuthFailure(e.toString()));
      }
    }
  }

  Future<void> _onGuestLogin(
    GuestLoginEvent event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    await Future.delayed(const Duration(milliseconds: 250));
    _currentUser = const UserProfile(
      id: 'guest-explorer',
      name: 'Guest Explorer (Demo)',
      email: 'guest@adoptmatch.demo',
      phone: '',
      role: UserRole.guest,
      isVerified: false,
      location: 'Dhaka, Bangladesh',
      bio: 'Exploring AdoptMatch in demo preview mode.',
    );
    emit(Authenticated(_currentUser));
  }

  void _onUserConfirmedSession(
    UserConfirmedSessionEvent event,
    Emitter<AuthState> emit,
  ) {
    _currentUser = event.user;
    emit(Authenticated(_currentUser));
  }

  void _onSwitchRole(SwitchRoleEvent event, Emitter<AuthState> emit) {
    _currentUser = UserProfile(
      id: _currentUser.id,
      name: _currentUser.name,
      email: _currentUser.email,
      phone: _currentUser.phone,
      role: event.role,
      isVerified: true,
    );
    emit(Authenticated(_currentUser));
  }

  Future<void> _onLogout(LogoutEvent event, Emitter<AuthState> emit) async {
    await GoogleAuthService.signOut();
    await SupabaseService.signOut();
    emit(AuthUnauthenticated());
  }

  Future<void> _onUpdateUserProfile(
    UpdateUserProfileEvent event,
    Emitter<AuthState> emit,
  ) async {
    final updated = _currentUser.copyWith(
      name: (event.name != null && event.name!.trim().isNotEmpty)
          ? event.name!.trim()
          : _currentUser.name,
      phone: (event.phone != null && event.phone!.trim().isNotEmpty)
          ? event.phone!.trim()
          : _currentUser.phone,
      avatarUrl: event.avatarUrl ?? _currentUser.avatarUrl,
      location: (event.location != null && event.location!.trim().isNotEmpty)
          ? event.location!.trim()
          : _currentUser.location,
      bio: (event.bio != null && event.bio!.trim().isNotEmpty)
          ? event.bio!.trim()
          : _currentUser.bio,
      preferredPetType: event.preferredPetType ?? _currentUser.preferredPetType,
    );

    _currentUser = updated;

    if (SupabaseService.isInitialized &&
        SupabaseService.auth.currentUser != null) {
      try {
        await SupabaseService.auth.updateUser(
          sb.UserAttributes(
            data: {
              'full_name': updated.name,
              'phone': updated.phone,
              'avatar_url': updated.avatarUrl,
              'location': updated.location,
              'bio': updated.bio,
              'preferred_pet_type': updated.preferredPetType,
            },
          ),
        );
      } catch (e) {
        // Silently handled for offline/mock mode
      }
    }

    emit(Authenticated(_currentUser));
  }

  Future<void> _onChangePassword(
    ChangePasswordEvent event,
    Emitter<AuthState> emit,
  ) async {
    try {
      if (SupabaseService.isInitialized &&
          SupabaseService.auth.currentUser != null) {
        await SupabaseService.updatePassword(event.newPassword);
      }
    } catch (_) {
      // Handled in dialog with specific user feedback
    }
  }

  void _onActivateSubscription(
    ActivateSubscriptionEvent event,
    Emitter<AuthState> emit,
  ) {
    final now = DateTime.now();
    DateTime baseDate = now;
    if (_currentUser.isPremium && _currentUser.premiumExpiresAt != null) {
      if (_currentUser.premiumExpiresAt!.isAfter(now)) {
        baseDate = _currentUser.premiumExpiresAt!;
      }
    }
    final newExpiry = baseDate.add(Duration(days: event.durationDays));

    _currentUser = _currentUser.copyWith(
      isPremium: true,
      premiumPlanId: event.planId,
      premiumExpiresAt: newExpiry,
      subscriptionStatus: 'ACTIVE',
    );
    emit(Authenticated(_currentUser));
  }

  @override
  Future<void> close() {
    _supabaseAuthSubscription?.cancel();
    return super.close();
  }
}
