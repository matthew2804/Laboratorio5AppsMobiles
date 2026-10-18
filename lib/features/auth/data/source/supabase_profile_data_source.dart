import 'package:moviles_auth/features/auth/data/models/profile_model.dart';
import 'package:moviles_auth/features/auth/data/source/supabase_error_mapper.dart';
import 'package:moviles_auth/features/auth/domain/failures/auth_failure.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Reads and writes `public.profiles`. Every error leaves this class as an
/// `AuthFailure`.
class SupabaseProfileDataSource {
  final SupabaseClient client;

  const SupabaseProfileDataSource(this.client);

  /// The row is inserted without reading it back, so the insert does not
  /// depend on the select policy.
  Future<void> insertProfile(
    ProfileModel profile, {
    required String email,
  }) async {
    try {
      await client.from(ProfileModel.table).insert(profile.toRow(email: email));
    } catch (error) {
      throw mapSupabaseError(error, operation: 'insertProfile');
    }
  }

  /// Returns null when there is no profile with [id] or RLS hides it.
  Future<ProfileModel?> getProfileById(String id) async {
    final Map<String, dynamic>? row;
    try {
      row = await client
          .from(ProfileModel.table)
          .select(ProfileModel.columns)
          .eq('id', id)
          .maybeSingle();
    } catch (error) {
      throw mapSupabaseError(error, operation: 'getProfileById');
    }

    if (row == null) return null;
    final profile = ProfileModel.fromRow(row);
    if (profile == null) {
      throw const ServerFailure(
        'El perfil guardado está incompleto. Revisa la tabla profiles.',
      );
    }
    return profile;
  }
}
