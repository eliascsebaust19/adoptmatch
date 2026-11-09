import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;
import '../../../core/models/user_subscription_model.dart';
import '../../../core/repositories/subscription_repository.dart';
import '../../../core/services/google_auth_service.dart';
import '../../../core/services/laravel_auth_service.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/storage/secure_storage_service.dart';
import '../repositories/auth_repository.dart';

// --- Roles & Profile Models ---
enum UserRole {
  adopter,
  shelter,
  foster,
  moderator,
  admin,
  superAdmin,
  guest;

  String get displayName {
    switch (this) {
      case UserRole.superAdmin:
        return 'Super Administrator';
      case UserRole.admin:
        return 'Operations Admin';
      case UserRole.moderator:
        return 'Community Moderator';
      case UserRole.shelter:
        return 'Shelter Manager';
      case UserRole.foster:
        return 'Foster Caregiver';
      case UserRole.guest:
        return 'Guest Explorer';
      case UserRole.adopter:
        return 'Pet Adopter';
    }
  }

  bool get hasAdminAccess =>
      this == UserRole.admin ||
      this == UserRole.superAdmin ||
      this == UserRole.moderator ||
      this == UserRole.shelter;

  bool get isAdmin => this == UserRole.admin || this == UserRole.superAdmin;
  bool get isModerator => this == UserRole.moderator;
  bool get isShelter => this == UserRole.shelter;
  bool get isGuest => this == UserRole.guest;
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
    switch (code.toUpperCase()) {
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

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    DateTime? expiry;
    if (json['premiumExpiresAt'] != null) {
      try {
        expiry = DateTime.parse(json['premiumExpiresAt'].toString());
      } catch (_) {}
    } else if (json['premium_expires_at'] != null) {
      try {
        expiry = DateTime.parse(json['premium_expires_at'].toString());
      } catch (_) {}
    }

    final rawRole = json['role']?.toString();

    return UserProfile(
      id: json['id']?.toString() ?? 'usr_${DateTime.now().millisecondsSinceEpoch}',
      name: json['name']?.toString() ?? 'Pet Lover',
      email: json['email']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
      role: UserRole.fromCode(rawRole),
      isVerified: json['isVerified'] == true || json['is_verified'] == true || json['email_verified_at'] != null || json['phone_verified_at'] != null,
      avatarUrl: json['avatarUrl']?.toString() ?? json['avatar']?.toString() ?? '',
      permissions: (json['permissions'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? const [],
      location: json['location']?.toString() ?? json['location_city']?.toString() ?? 'Dhaka, Bangladesh',
      bio: json['bio']?.toString() ?? 'Animal advocate & pet rescuer',
      googlePhotoUrl: json['googlePhotoUrl']?.toString() ?? '',
      preferredPetType: json['preferredPetType']?.toString() ?? 'All Pets',
      isPremium: json['isPremium'] == true || json['is_premium'] == true,
      premiumPlanId: json['premiumPlanId']?.toString() ?? json['premium_plan_id']?.toString(),
      premiumExpiresAt: expiry,
      subscriptionStatus: json['subscriptionStatus']?.toString() ?? json['subscription_status']?.toString() ?? 'NONE',
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'email': email,
    'phone': phone,
    'role': role.name,
    'isVerified': isVerified,
    'avatarUrl': avatarUrl,
    'permissions': permissions,
    'location': location,
    'bio': bio,
    'googlePhotoUrl': googlePhotoUrl,
    'preferredPetType': preferredPetType,
    'isPremium': isPremium,
    'premiumPlanId': premiumPlanId,
    'premiumExpiresAt': premiumExpiresAt?.toIso8601String(),
    'subscriptionStatus': subscriptionStatus,
  };

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

class CheckSessionEvent extends AuthEvent {}

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
  final String? accessToken;
  const UserConfirmedSessionEvent(this.user, {this.accessToken});
  @override
  List<Object?> get props => [user, accessToken];
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
  final String currentPassword;
  final String newPassword;
  const ChangePasswordEvent({required this.currentPassword, required this.newPassword});
  @override
  List<Object?> get props => [currentPassword, newPassword];
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
  final bool isNewUser;
  const Authenticated(this.user, {this.isNewUser = false});
  @override
  List<Object?> get props => [user, isNewUser];
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

class AuthPasswordChanged extends AuthState {}

class AuthUnauthenticated extends AuthState {}

class AuthFailure extends AuthState {
  final String errorMessage;
  const AuthFailure(this.errorMessage);
  @override
  List<Object?> get props => [errorMessage];
}

// --- BLoC ---
class AuthBloc extends Bloc<AuthEvent, AuthState> {
  UserProfile? _currentUser;
  final AuthRepository _authRepository;
  final LaravelAuthService _laravelAuthService;

  AuthBloc({UserProfile? initialUser, AuthRepository? authRepository,
      LaravelAuthService? laravelAuthService})
      : _currentUser = initialUser,
        _authRepository = authRepository ?? AuthRepository(),
        _laravelAuthService = laravelAuthService ?? LaravelAuthService(),
        super(initialUser != null ? Authenticated(initialUser) : AuthInitial()) {
    on<CheckSessionEvent>(_onCheckSession);
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

  }

  // Sessions are issued only by the AdoptMatch API. Supabase auth events must
  // not mint app sessions: its JWT is not accepted by the Laravel/Node APIs.

  Future<void> _onCheckSession(
    CheckSessionEvent event,
    Emitter<AuthState> emit,
  ) async {
    final user = await _authRepository.verifyCurrentSession();
    if (user != null) {
      _currentUser = user;
      emit(Authenticated(user));
    } else {
      _currentUser = null;
      emit(AuthUnauthenticated());
    }
  }

  Future<void> _onSignUpWithEmail(
    SignUpWithEmailEvent event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    try {
      final emailLower = event.email.trim().toLowerCase();

      try {
        final res = await _laravelAuthService.register(
          name: event.fullName.trim(),
          email: emailLower,
          password: event.password,
          role: 'adopter',
        );
        if (res['status'] == 'success' || res['success'] == true) {
          final token = (res['access_token'] ?? res['token'])?.toString();
          final userMap = res['user'] as Map<String, dynamic>?;
          if (token != null && userMap != null) {
            final user = UserProfile.fromJson(userMap);
            await SecureStorageService.instance.saveAuthToken(token);
            await SecureStorageService.instance.saveUserProfile(user);
            _currentUser = user;
            emit(Authenticated(user, isNewUser: true));
            return;
          }
        }
      } catch (laravelErr) {
        debugPrint('[AuthBloc] Laravel register notice: $laravelErr');
        String errMsg = 'Could not create your account. Please try again.';
        if (laravelErr is DioException) {
          if (laravelErr.type == DioExceptionType.connectionTimeout ||
              laravelErr.type == DioExceptionType.receiveTimeout) {
            errMsg =
                'The authentication server is waking up from sleep. Please try again in a few moments.';
          } else if (laravelErr.response?.data is Map) {
            final data = laravelErr.response!.data as Map;
            if (data['errors'] is Map) {
              final errorsMap = data['errors'] as Map;
              final firstField = errorsMap.values.firstOrNull;
              if (firstField is List && firstField.isNotEmpty) {
                errMsg = firstField.first.toString();
              }
            } else if (data['message'] != null) {
              errMsg = data['message'].toString();
            }
          }
        } else if (laravelErr is Exception) {
          final clean =
              laravelErr.toString().replaceFirst('Exception: ', '').trim();
          if (clean.isNotEmpty) {
            errMsg = clean;
          }
        }
        emit(AuthFailure(errMsg));
        return;
      }

      // Fail closed: an account only exists once a server has created it.
      emit(const AuthFailure(
        'Could not create your account. The authentication server is unreachable — please try again.',
      ));
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

      // 1. Primary: Live Laravel 11 Backend API Authentication
      try {
        final user = await _authRepository.loginWithEmail(
          email: emailLower,
          password: event.password,
        );
        _currentUser = user;
        emit(Authenticated(user));
        return;
      } catch (laravelErr) {
        debugPrint('[AuthBloc] Laravel login failed: $laravelErr');
        String errMsg =
            'Invalid credentials or authentication server is currently unreachable.';
        if (laravelErr is DioException) {
          if (laravelErr.type == DioExceptionType.connectionTimeout ||
              laravelErr.type == DioExceptionType.receiveTimeout) {
            errMsg =
                'The authentication server is waking up from sleep. Please try again in a few moments.';
          } else if (laravelErr.response?.data is Map &&
              laravelErr.response!.data['message'] != null) {
            errMsg = laravelErr.response!.data['message'].toString();
          }
        } else if (laravelErr is Exception) {
          final clean =
              laravelErr.toString().replaceFirst('Exception: ', '').trim();
          if (clean.isNotEmpty) {
            errMsg = clean;
          }
        }
        emit(AuthFailure(errMsg));
        return;
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

      // 1. Primary: Authenticate via Laravel API
      try {
        final user = await _authRepository.loginWithEmail(
          email: emailLower,
          password: event.password,
        );
        if (!user.role.hasAdminAccess) {
          await _authRepository.logout();
          emit(
            const AuthFailure(
              '403 Forbidden: Access Denied. Administrator or Shelter Manager privileges required.',
            ),
          );
          return;
        }
        _currentUser = user;
        emit(Authenticated(user));
        return;
      } catch (laravelErr) {
        debugPrint('[AuthBloc] Admin Laravel login: $laravelErr');
        String errMsg =
            '403 Forbidden: Access Denied. Invalid administrative credentials or server unreachable.';
        if (laravelErr is Exception) {
          final clean =
              laravelErr.toString().replaceFirst('Exception: ', '').trim();
          if (clean.isNotEmpty && clean.contains('Access Denied')) {
            errMsg = clean;
          }
        }
        emit(AuthFailure(errMsg));
        return;
      }
    } catch (e) {
      emit(AuthFailure(e.toString()));
    }
  }

  Future<void> _onRequestOtp(RequestPhoneOtpEvent event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    try {
      final phone = LaravelAuthService.normalizePhone(event.phoneNumber);
      await _laravelAuthService.requestPhoneOtp(phone);
      emit(AuthOtpSent(phone));
    } catch (e) {
      emit(AuthFailure('OTP request failed: $e'));
    }
  }

  Future<void> _onVerifyOtp(VerifyPhoneOtpEvent event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    final otp = event.otp.trim();
    if (otp.length != 6 || int.tryParse(otp) == null) {
      emit(const AuthFailure('Invalid OTP. Please enter the 6-digit verification code.'));
      return;
    }
    try {
      final data = await _laravelAuthService.verifyPhoneOtp(event.phoneNumber, otp);
      final token = data['access_token']?.toString();
      if (token == null || token.isEmpty) throw Exception('The server did not issue a session token.');
      final user = UserProfile.fromJson(Map<String, dynamic>.from(data['user'] as Map));
      await SecureStorageService.instance.saveAuthToken(token);
      await SecureStorageService.instance.saveUserProfile(user);
      _currentUser = user;
      emit(Authenticated(user));
    } catch (e) {
      emit(AuthFailure('OTP verification failed: $e'));
    }
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
          await SecureStorageService.instance.saveUserProfile(_currentUser!);
          emit(Authenticated(_currentUser!, isNewUser: result.isNewUser));
          return;
        } else if (result.wasCancelled) {
          emit(AuthUnauthenticated());
          return;
        } else if (result.errorMessage != null) {
          emit(AuthFailure(result.errorMessage!));
          return;
        }
      }
      emit(const AuthFailure('Authentication provider unavailable.'));
    } catch (e) {
      emit(AuthFailure(e.toString()));
    }
  }

  Future<void> _onGuestLogin(
    GuestLoginEvent event,
    Emitter<AuthState> emit,
  ) async {
    emit(
      const AuthFailure(
        'Guest access is disabled. Please create an account or sign in.',
      ),
    );
  }

  Future<void> _onUserConfirmedSession(
    UserConfirmedSessionEvent event,
    Emitter<AuthState> emit,
  ) async {
    if (event.accessToken != null && event.accessToken!.isNotEmpty) {
      await SecureStorageService.instance.saveAuthToken(event.accessToken!);
    }
    await SecureStorageService.instance.saveUserProfile(event.user);
    _currentUser = event.user;
    emit(Authenticated(_currentUser!));
  }

  void _onSwitchRole(SwitchRoleEvent event, Emitter<AuthState> emit) {
    emit(const AuthFailure('Role changes must be granted by the server. Local role elevation is disabled.'));
  }

  Future<void> _onLogout(LogoutEvent event, Emitter<AuthState> emit) async {
    await _authRepository.logout();
    await GoogleAuthService.signOut();
    await SupabaseService.signOut();
    _currentUser = null;
    emit(AuthUnauthenticated());
  }

  Future<void> _onUpdateUserProfile(
    UpdateUserProfileEvent event,
    Emitter<AuthState> emit,
  ) async {
    if (_currentUser == null) {
      emit(const AuthFailure('Sign in before updating your profile.'));
      return;
    }
    final base = _currentUser!;
    final updated = base.copyWith(
      name: (event.name != null && event.name!.trim().isNotEmpty)
          ? event.name!.trim()
          : base.name,
      phone: (event.phone != null && event.phone!.trim().isNotEmpty)
          ? event.phone!.trim()
          : base.phone,
      avatarUrl: event.avatarUrl ?? base.avatarUrl,
      location: (event.location != null && event.location!.trim().isNotEmpty)
          ? event.location!.trim()
          : base.location,
      bio: (event.bio != null && event.bio!.trim().isNotEmpty)
          ? event.bio!.trim()
          : base.bio,
      preferredPetType: event.preferredPetType ?? base.preferredPetType,
    );

    _currentUser = updated;
    await SecureStorageService.instance.saveUserProfile(updated);

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
      } catch (_) {}
    }

    emit(Authenticated(_currentUser!));
  }

  Future<void> _onChangePassword(
    ChangePasswordEvent event,
    Emitter<AuthState> emit,
  ) async {
    if (_currentUser == null) {
      emit(const AuthFailure('Sign in before changing your password.'));
      return;
    }
    emit(AuthLoading());
    try {
      await _laravelAuthService.changePassword(
        currentPassword: event.currentPassword,
        newPassword: event.newPassword,
      );
      emit(AuthPasswordChanged());
      emit(Authenticated(_currentUser!));
    } catch (e) {
      emit(AuthFailure('Password was not changed: $e'));
      emit(Authenticated(_currentUser!));
    }
  }

  /// Refreshes the premium entitlement from the server. The requested plan and
  /// duration are only a hint: the backend decides what was actually paid for.
  Future<void> _onActivateSubscription(
    ActivateSubscriptionEvent event,
    Emitter<AuthState> emit,
  ) async {
    if (_currentUser == null) return;
    emit(AuthLoading());
    try {
      final result = await SubscriptionRepository()
          .fetchMySubscription(_currentUser!.id);
      final subscription = result['subscription'] as UserSubscription?;
      if (subscription == null) {
        emit(Authenticated(_currentUser!));
        emit(const AuthFailure('Could not read your subscription status. Please try again.'));
        return;
      }

      _currentUser = _currentUser!.copyWith(
        isPremium: subscription.isPremium,
        premiumPlanId: subscription.planId,
        premiumExpiresAt: subscription.expiresAt,
        subscriptionStatus: subscription.status,
      );
      await SecureStorageService.instance.saveUserProfile(_currentUser!);
      emit(Authenticated(_currentUser!));
      if (!subscription.isPremium) {
        emit(const AuthFailure(
          'No verified payment found yet. Premium activates once your transaction is confirmed.',
        ));
      }
    } catch (e) {
      emit(Authenticated(_currentUser!));
      emit(AuthFailure('Could not verify your payment: $e'));
    }
  }

  @override
  Future<void> close() {
    return super.close();
  }
}
