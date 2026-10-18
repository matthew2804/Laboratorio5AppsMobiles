import 'package:moviles_auth/features/auth/domain/entities/auth_user.dart';

/// Account data as read from Supabase Auth.
class AuthUserModel {
  final String id;
  final String email;

  const AuthUserModel({required this.id, required this.email});

  AuthUser toEntity() => AuthUser(id: id, email: email);
}
