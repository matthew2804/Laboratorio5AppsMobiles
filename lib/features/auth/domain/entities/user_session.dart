import 'package:moviles_auth/features/auth/domain/entities/auth_user.dart';
import 'package:moviles_auth/features/auth/domain/entities/profile.dart';

/// Signed in account together with its profile.
class UserSession {
  final AuthUser user;
  final Profile profile;

  const UserSession({required this.user, required this.profile});

  @override
  bool operator ==(Object other) =>
      other is UserSession && other.user == user && other.profile == profile;

  @override
  int get hashCode => Object.hash(user, profile);

  @override
  String toString() => 'UserSession(user: $user, profile: $profile)';
}
