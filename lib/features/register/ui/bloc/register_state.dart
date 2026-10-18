import 'package:moviles_auth/features/auth/domain/entities/auth_user.dart';
import 'package:moviles_auth/features/auth/domain/entities/profile.dart';
import 'package:moviles_auth/features/auth/domain/entities/user_session.dart';

enum RegisterStatus { initial, loading, success, failure }

class RegisterState {
  final RegisterStatus status;
  final Profile? profile;
  final AuthUser? user;
  final String? errorMessage;

  const RegisterState({
    this.status = RegisterStatus.initial,
    this.profile,
    this.user,
    this.errorMessage,
  });

  /// Session to open `/home` with, available once the status is success.
  UserSession? get session {
    final profile = this.profile;
    final user = this.user;
    if (profile == null || user == null) return null;
    return UserSession(user: user, profile: profile);
  }

  /// Pass `clearError: true` to remove the previous [errorMessage].
  RegisterState copyWith({
    RegisterStatus? status,
    Profile? profile,
    AuthUser? user,
    String? errorMessage,
    bool clearError = false,
  }) {
    return RegisterState(
      status: status ?? this.status,
      profile: profile ?? this.profile,
      user: user ?? this.user,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is RegisterState &&
      other.status == status &&
      other.profile == profile &&
      other.user == user &&
      other.errorMessage == errorMessage;

  @override
  int get hashCode => Object.hash(status, profile, user, errorMessage);

  @override
  String toString() =>
      'RegisterState(status: $status, profile: $profile, '
      'errorMessage: $errorMessage)';
}
