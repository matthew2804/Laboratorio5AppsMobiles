import 'package:moviles_auth/features/auth/domain/entities/auth_user.dart';

/// Account operations. Implementations throw an `AuthFailure` when they fail.
abstract class AuthRepository {
  /// Creates the account and returns it with an active session.
  Future<AuthUser> signUp({required String email, required String password});

  Future<AuthUser> signIn({required String email, required String password});

  Future<void> signOut();
}
