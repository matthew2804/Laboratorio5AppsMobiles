import 'package:moviles_auth/features/auth/domain/entities/profile.dart';

/// Row of `public.profiles`. Translates between the snake_case columns of the
/// table and the camelCase fields of the app.
class ProfileModel {
  static const table = 'profiles';
  static const columns = 'id, username, full_name';

  final String id;
  final String username;
  final String fullName;

  const ProfileModel({
    required this.id,
    required this.username,
    required this.fullName,
  });

  /// Returns null when the row is missing a column or has a wrong type.
  static ProfileModel? fromRow(Map<String, dynamic> row) {
    final id = row['id'];
    final username = row['username'];
    final fullName = row['full_name'];
    if (id is! String || username is! String || fullName is! String) {
      return null;
    }
    return ProfileModel(id: id, username: username, fullName: fullName);
  }

  Map<String, dynamic> toRow({required String email}) => {
    'id': id,
    'username': username,
    'full_name': fullName,
    'email': email,
  };

  Profile toEntity() => Profile(id: id, username: username, fullName: fullName);
}
