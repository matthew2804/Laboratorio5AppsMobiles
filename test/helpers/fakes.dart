import 'dart:async';

import 'package:moviles_auth/features/auth/domain/entities/auth_user.dart';
import 'package:moviles_auth/features/auth/domain/entities/profile.dart';
import 'package:moviles_auth/features/auth/domain/repository/auth_repository.dart';
import 'package:moviles_auth/features/auth/domain/repository/profile_repository.dart';

const testUser = AuthUser(id: 'uid-123', email: 'ana@icesi.edu.co');
const testProfile = Profile(
  id: 'uid-123',
  username: 'ana',
  fullName: 'Ana Gómez',
);

/// In-memory [AuthRepository] that records every call in [log].
class FakeAuthRepository implements AuthRepository {
  final List<String> log;

  AuthUser signUpResult = testUser;
  AuthUser signInResult = testUser;
  Object? signUpError;
  Object? signInError;
  Object? signOutError;

  /// When set, sign up and sign in wait for it before answering.
  Completer<void>? gate;

  String? lastEmail;
  String? lastPassword;

  FakeAuthRepository([List<String>? log]) : log = log ?? [];

  @override
  Future<AuthUser> signUp({
    required String email,
    required String password,
  }) async {
    log.add('auth.signUp');
    lastEmail = email;
    lastPassword = password;
    await gate?.future;
    final error = signUpError;
    if (error != null) throw error;
    return signUpResult;
  }

  @override
  Future<AuthUser> signIn({
    required String email,
    required String password,
  }) async {
    log.add('auth.signIn');
    lastEmail = email;
    lastPassword = password;
    await gate?.future;
    final error = signInError;
    if (error != null) throw error;
    return signInResult;
  }

  @override
  Future<void> signOut() async {
    log.add('auth.signOut');
    final error = signOutError;
    if (error != null) throw error;
  }
}

/// In-memory [ProfileRepository] that records every call in [log].
class FakeProfileRepository implements ProfileRepository {
  final List<String> log;
  final Map<String, Profile> profiles = {};

  Object? createError;
  Object? getError;

  String? createdId;
  String? createdEmail;
  String? requestedId;

  FakeProfileRepository([List<String>? log]) : log = log ?? [];

  @override
  Future<Profile> createProfile({
    required String id,
    required String username,
    required String fullName,
    required String email,
  }) async {
    log.add('profile.create');
    createdId = id;
    createdEmail = email;
    final error = createError;
    if (error != null) throw error;
    final profile = Profile(id: id, username: username, fullName: fullName);
    profiles[id] = profile;
    return profile;
  }

  @override
  Future<Profile> getProfile(String id) async {
    log.add('profile.get');
    requestedId = id;
    final error = getError;
    if (error != null) throw error;
    final profile = profiles[id];
    if (profile == null) {
      throw StateError('Configure getError for missing profiles in tests');
    }
    return profile;
  }
}
