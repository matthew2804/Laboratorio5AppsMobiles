import 'package:moviles_auth/features/auth/domain/entities/profile.dart';

/// Profile operations. Implementations throw an `AuthFailure` when they fail.
abstract class ProfileRepository {
  /// Saves the profile of the account [id]. [email] is stored alongside it
  /// because the `profiles` table of this project requires that column.
  Future<Profile> createProfile({
    required String id,
    required String username,
    required String fullName,
    required String email,
  });

  /// Throws `ProfileNotFoundFailure` when there is no profile with [id].
  Future<Profile> getProfile(String id);
}
