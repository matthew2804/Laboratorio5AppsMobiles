import 'package:moviles_auth/features/auth/domain/repository/auth_repository.dart';

/// Closes the current session.
class SignOutUseCase {
  final AuthRepository authRepository;

  const SignOutUseCase({required this.authRepository});

  Future<void> call() => authRepository.signOut();
}
