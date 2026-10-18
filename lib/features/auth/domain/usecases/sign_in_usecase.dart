import 'package:moviles_auth/features/auth/domain/entities/user_session.dart';
import 'package:moviles_auth/features/auth/domain/repository/auth_repository.dart';
import 'package:moviles_auth/features/auth/domain/repository/profile_repository.dart';

/// Signs in with email and password and loads the profile of that account.
///
/// When the profile cannot be loaded the session is closed again, so a failed
/// sign in never leaves a half signed in user behind.
class SignInUseCase {
  final AuthRepository authRepository;
  final ProfileRepository profileRepository;

  const SignInUseCase({
    required this.authRepository,
    required this.profileRepository,
  });

  Future<UserSession> call({
    required String email,
    required String password,
  }) async {
    final user = await authRepository.signIn(email: email, password: password);
    try {
      final profile = await profileRepository.getProfile(user.id);
      return UserSession(user: user, profile: profile);
    } catch (_) {
      try {
        await authRepository.signOut();
      } catch (_) {
        // The profile failure is the one worth reporting.
      }
      rethrow;
    }
  }
}
