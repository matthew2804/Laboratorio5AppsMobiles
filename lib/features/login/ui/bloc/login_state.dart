import 'package:moviles_auth/features/auth/domain/entities/auth_user.dart';
import 'package:moviles_auth/features/auth/domain/entities/profile.dart';
import 'package:moviles_auth/features/auth/domain/entities/user_session.dart';

enum LoginStatus { initial, loading, success, failure }

class LoginState {
  final LoginStatus status;
  final Profile? profile;
  final AuthUser? user;
  final String? errorMessage;

  const LoginState({
    this.status = LoginStatus.initial,
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
  LoginState copyWith({
    LoginStatus? status,
    Profile? profile,
    AuthUser? user,
    String? errorMessage,
    bool clearError = false,
  }) {
    return LoginState(
      status: status ?? this.status,
      profile: profile ?? this.profile,
      user: user ?? this.user,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is LoginState &&
      other.status == status &&
      other.profile == profile &&
      other.user == user &&
      other.errorMessage == errorMessage;

  @override
  int get hashCode => Object.hash(status, profile, user, errorMessage);

  @override
  String toString() =>
      'LoginState(status: $status, profile: $profile, '
      'errorMessage: $errorMessage)';
}
