import 'package:flutter_test/flutter_test.dart';
import 'package:moviles_auth/features/auth/domain/entities/auth_user.dart';
import 'package:moviles_auth/features/auth/domain/entities/profile.dart';
import 'package:moviles_auth/features/auth/domain/failures/auth_failure.dart';
import 'package:moviles_auth/features/auth/domain/usecases/sign_in_usecase.dart';
import 'package:moviles_auth/features/auth/domain/usecases/sign_out_usecase.dart';

import '../../../helpers/fakes.dart';

void main() {
  late List<String> log;
  late FakeAuthRepository auth;
  late FakeProfileRepository profiles;

  setUp(() {
    log = [];
    auth = FakeAuthRepository(log);
    profiles = FakeProfileRepository(log);
  });

  group('SignInUseCase', () {
    late SignInUseCase signIn;

    setUp(() {
      signIn = SignInUseCase(authRepository: auth, profileRepository: profiles);
    });

    test('signs in and loads the profile with the Auth id', () async {
      auth.signInResult = const AuthUser(id: 'auth-id-7', email: 'x@y.co');
      profiles.profiles['auth-id-7'] = const Profile(
        id: 'auth-id-7',
        username: 'x',
        fullName: 'Equis',
      );

      final session = await signIn(email: 'x@y.co', password: 'pw1234');

      expect(log, ['auth.signIn', 'profile.get']);
      expect(profiles.requestedId, 'auth-id-7');
      expect(session.user.email, 'x@y.co');
      expect(session.profile.username, 'x');
    });

    test('wrong credentials do not query the profile', () async {
      auth.signInError = const InvalidCredentialsFailure();

      await expectLater(
        signIn(email: 'x@y.co', password: 'bad'),
        throwsA(isA<InvalidCredentialsFailure>()),
      );
      expect(log, ['auth.signIn']);
    });

    test('a missing profile fails and closes the session', () async {
      profiles.getError = const ProfileNotFoundFailure();

      await expectLater(
        signIn(email: 'x@y.co', password: 'pw1234'),
        throwsA(isA<ProfileNotFoundFailure>()),
      );
      expect(log, ['auth.signIn', 'profile.get', 'auth.signOut']);
    });
  });

  group('SignOutUseCase', () {
    test('delegates to the repository', () async {
      await SignOutUseCase(authRepository: auth)();

      expect(log, ['auth.signOut']);
    });

    test('propagates failures', () async {
      auth.signOutError = const NetworkFailure();

      await expectLater(
        SignOutUseCase(authRepository: auth)(),
        throwsA(isA<NetworkFailure>()),
      );
    });
  });
}
