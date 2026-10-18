import 'package:moviles_auth/features/auth/data/source/supabase_auth_data_source.dart';
import 'package:moviles_auth/features/auth/domain/entities/auth_user.dart';
import 'package:moviles_auth/features/auth/domain/failures/auth_failure.dart';
import 'package:moviles_auth/features/auth/domain/repository/auth_repository.dart';

class AuthRepositoryImpl implements AuthRepository {
  final SupabaseAuthDataSource dataSource;

  const AuthRepositoryImpl(this.dataSource);

  @override
  Future<AuthUser> signUp({required String email, required String password}) =>
      _guard(() async {
        final model = await dataSource.signUp(email: email, password: password);
        return model.toEntity();
      });

  @override
  Future<AuthUser> signIn({required String email, required String password}) =>
      _guard(() async {
        final model = await dataSource.signIn(email: email, password: password);
        return model.toEntity();
      });

  @override
  Future<void> signOut() => _guard(dataSource.signOut);

  /// Makes sure only `AuthFailure`s reach the domain.
  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on AuthFailure {
      rethrow;
    } catch (_) {
      throw const UnexpectedFailure();
    }
  }
}
