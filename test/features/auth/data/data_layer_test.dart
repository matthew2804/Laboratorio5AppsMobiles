import 'package:flutter_test/flutter_test.dart';
import 'package:moviles_auth/features/auth/data/models/auth_user_model.dart';
import 'package:moviles_auth/features/auth/data/models/profile_model.dart';
import 'package:moviles_auth/features/auth/data/repository/auth_repository_impl.dart';
import 'package:moviles_auth/features/auth/data/repository/profile_repository_impl.dart';
import 'package:moviles_auth/features/auth/data/source/supabase_auth_data_source.dart';
import 'package:moviles_auth/features/auth/data/source/supabase_error_mapper.dart';
import 'package:moviles_auth/features/auth/data/source/supabase_profile_data_source.dart';
import 'package:moviles_auth/features/auth/domain/entities/auth_user.dart';
import 'package:moviles_auth/features/auth/domain/entities/profile.dart';
import 'package:moviles_auth/features/auth/domain/failures/auth_failure.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthUser;

class _FakeAuthDataSource implements SupabaseAuthDataSource {
  Object? error;

  @override
  SupabaseClient get client => throw UnimplementedError();

  @override
  Future<AuthUserModel> signUp({
    required String email,
    required String password,
  }) async {
    final error = this.error;
    if (error != null) throw error;
    return AuthUserModel(id: 'id-1', email: email);
  }

  @override
  Future<AuthUserModel> signIn({
    required String email,
    required String password,
  }) => signUp(email: email, password: password);

  @override
  Future<void> signOut() async {}
}

class _FakeProfileDataSource implements SupabaseProfileDataSource {
  ProfileModel? stored;
  Map<String, dynamic>? insertedRow;

  @override
  SupabaseClient get client => throw UnimplementedError();

  @override
  Future<void> insertProfile(ProfileModel profile, {required String email}) {
    insertedRow = profile.toRow(email: email);
    return Future.value();
  }

  @override
  Future<ProfileModel?> getProfileById(String id) async => stored;
}

void main() {
  group('ProfileModel', () {
    test('maps full_name to fullName', () {
      final model = ProfileModel.fromRow({
        'id': 'id-1',
        'username': 'ana',
        'full_name': 'Ana Gómez',
      });

      expect(
        model?.toEntity(),
        const Profile(id: 'id-1', username: 'ana', fullName: 'Ana Gómez'),
      );
    });

    test('returns null for incomplete rows', () {
      expect(ProfileModel.fromRow({'id': 'id-1', 'username': 'ana'}), isNull);
    });

    test('writes snake_case columns and no password', () {
      const model = ProfileModel(id: 'id-1', username: 'ana', fullName: 'Ana');

      expect(model.toRow(email: 'a@b.co'), {
        'id': 'id-1',
        'username': 'ana',
        'full_name': 'Ana',
        'email': 'a@b.co',
      });
    });
  });

  group('AuthRepositoryImpl', () {
    test('converts the model into an AuthUser', () async {
      final repository = AuthRepositoryImpl(_FakeAuthDataSource());

      final user = await repository.signUp(email: 'a@b.co', password: 'x');

      expect(user, const AuthUser(id: 'id-1', email: 'a@b.co'));
    });

    test('keeps AuthFailures and hides other errors', () async {
      final source = _FakeAuthDataSource()
        ..error = const InvalidCredentialsFailure();
      final repository = AuthRepositoryImpl(source);

      await expectLater(
        repository.signIn(email: 'a@b.co', password: 'x'),
        throwsA(isA<InvalidCredentialsFailure>()),
      );

      source.error = StateError('unexpected');
      await expectLater(
        repository.signIn(email: 'a@b.co', password: 'x'),
        throwsA(isA<UnexpectedFailure>()),
      );
    });
  });

  group('ProfileRepositoryImpl', () {
    test('inserts the row with the given id', () async {
      final source = _FakeProfileDataSource();
      final repository = ProfileRepositoryImpl(source);

      final profile = await repository.createProfile(
        id: 'auth-id',
        username: 'ana',
        fullName: 'Ana',
        email: 'a@b.co',
      );

      expect(profile.id, 'auth-id');
      expect(source.insertedRow?['id'], 'auth-id');
      expect(source.insertedRow?['full_name'], 'Ana');
    });

    test('a missing row becomes ProfileNotFoundFailure', () async {
      final repository = ProfileRepositoryImpl(_FakeProfileDataSource());

      await expectLater(
        repository.getProfile('nobody'),
        throwsA(isA<ProfileNotFoundFailure>()),
      );
    });
  });

  group('mapSupabaseError', () {
    AuthFailure map(Object error) => mapSupabaseError(error, operation: 'test');

    test('maps Auth error codes', () {
      expect(
        map(const AuthApiException('x', code: 'user_already_exists')),
        isA<EmailAlreadyRegisteredFailure>(),
      );
      expect(
        map(const AuthApiException('x', code: 'invalid_credentials')),
        isA<InvalidCredentialsFailure>(),
      );
      expect(
        map(const AuthApiException('x', code: 'email_not_confirmed')),
        isA<EmailConfirmationRequiredFailure>(),
      );
      expect(
        map(const AuthApiException('User already registered')),
        isA<EmailAlreadyRegisteredFailure>(),
      );
      expect(
        map(AuthRetryableFetchException(message: 'offline')),
        isA<NetworkFailure>(),
      );
    });

    test('maps Postgrest error codes', () {
      expect(
        map(const PostgrestException(message: 'rls', code: '42501')),
        isA<PermissionDeniedFailure>(),
      );
      expect(
        map(const PostgrestException(message: 'dup', code: '23505')),
        isA<ServerFailure>(),
      );
    });

    test('recognises network errors and hides unknown ones', () {
      expect(
        map(Exception('SocketException: Failed host lookup')),
        isA<NetworkFailure>(),
      );
      expect(map(Exception('boom')), isA<UnexpectedFailure>());
    });
  });
}
