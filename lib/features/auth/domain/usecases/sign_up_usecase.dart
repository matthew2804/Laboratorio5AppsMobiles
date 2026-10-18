import 'package:moviles_auth/features/auth/domain/entities/auth_user.dart';
import 'package:moviles_auth/features/auth/domain/entities/user_session.dart';
import 'package:moviles_auth/features/auth/domain/failures/auth_failure.dart';
import 'package:moviles_auth/features/auth/domain/repository/auth_repository.dart';
import 'package:moviles_auth/features/auth/domain/repository/profile_repository.dart';

/// Creates the account in Auth and then its profile with the same id.
///
/// The two steps are not atomic. If the profile cannot be saved the session
/// is closed and a [ProfileCreationFailure] is thrown. Submitting the same
/// email and password again finishes the registration: Auth reports the email
/// as taken, the account is signed in and, only if it has no profile yet, the
/// profile is created. No second account is ever created.
class SignUpUseCase {
  final AuthRepository authRepository;
  final ProfileRepository profileRepository;

  const SignUpUseCase({
    required this.authRepository,
    required this.profileRepository,
  });

  Future<UserSession> call({
    required String username,
    required String fullName,
    required String email,
    required String password,
  }) async {
    AuthUser user;
    try {
      user = await authRepository.signUp(email: email, password: password);
    } on EmailAlreadyRegisteredFailure {
      final recovered = await _recoverIncompleteSignUp(email, password);
      if (recovered == null) rethrow;
      user = recovered;
    }

    try {
      final profile = await profileRepository.createProfile(
        id: user.id,
        username: username,
        fullName: fullName,
        email: user.email,
      );
      return UserSession(user: user, profile: profile);
    } on AuthFailure catch (failure) {
      await _signOutQuietly();
      throw ProfileCreationFailure(cause: failure);
    } catch (_) {
      await _signOutQuietly();
      throw ProfileCreationFailure();
    }
  }

  /// Returns the existing account when it belongs to the caller and still has
  /// no profile. Returns null when the email is really taken.
  Future<AuthUser?> _recoverIncompleteSignUp(
    String email,
    String password,
  ) async {
    final AuthUser user;
    try {
      user = await authRepository.signIn(email: email, password: password);
    } on EmailConfirmationRequiredFailure {
      rethrow;
    } on AuthFailure {
      return null;
    }

    try {
      await profileRepository.getProfile(user.id);
    } on ProfileNotFoundFailure {
      return user;
    } catch (_) {
      await _signOutQuietly();
      rethrow;
    }
    await _signOutQuietly();
    return null;
  }

  Future<void> _signOutQuietly() async {
    try {
      await authRepository.signOut();
    } catch (_) {
      // The original failure is the one worth reporting.
    }
  }
}
