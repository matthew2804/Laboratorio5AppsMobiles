import 'package:moviles_auth/features/auth/data/models/profile_model.dart';
import 'package:moviles_auth/features/auth/data/source/supabase_profile_data_source.dart';
import 'package:moviles_auth/features/auth/domain/entities/profile.dart';
import 'package:moviles_auth/features/auth/domain/failures/auth_failure.dart';
import 'package:moviles_auth/features/auth/domain/repository/profile_repository.dart';

class ProfileRepositoryImpl implements ProfileRepository {
  final SupabaseProfileDataSource dataSource;

  const ProfileRepositoryImpl(this.dataSource);

  @override
  Future<Profile> createProfile({
    required String id,
    required String username,
    required String fullName,
    required String email,
  }) => _guard(() async {
    final model = ProfileModel(id: id, username: username, fullName: fullName);
    await dataSource.insertProfile(model, email: email);
    return model.toEntity();
  });

  @override
  Future<Profile> getProfile(String id) => _guard(() async {
    final model = await dataSource.getProfileById(id);
    if (model == null) throw const ProfileNotFoundFailure();
    return model.toEntity();
  });

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
