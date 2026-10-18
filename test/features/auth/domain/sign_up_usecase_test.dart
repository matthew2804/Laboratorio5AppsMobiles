import 'package:flutter_test/flutter_test.dart';
import 'package:moviles_auth/features/auth/domain/entities/auth_user.dart';
import 'package:moviles_auth/features/auth/domain/entities/user_session.dart';
import 'package:moviles_auth/features/auth/domain/failures/auth_failure.dart';
import 'package:moviles_auth/features/auth/domain/usecases/sign_up_usecase.dart';

import '../../../helpers/fakes.dart';

void main() {
  late List<String> log;
  late FakeAuthRepository auth;
  late FakeProfileRepository profiles;
  late SignUpUseCase signUp;

  setUp(() {
    log = [];
    auth = FakeAuthRepository(log);
    profiles = FakeProfileRepository(log);
    signUp = SignUpUseCase(authRepository: auth, profileRepository: profiles);
  });

  Future<UserSession> run() => signUp(
    username: 'ana',
    fullName: 'Ana Gómez',
    email: 'ana@icesi.edu.co',
    password: 'secreto123',
  );

  test('creates the account first and then the profile', () async {
    await run();

    expect(log, ['auth.signUp', 'profile.create']);
    expect(auth.lastEmail, 'ana@icesi.edu.co');
    expect(auth.lastPassword, 'secreto123');
  });

  test('uses the id returned by Auth for the profile', () async {
    auth.signUpResult = const AuthUser(id: 'auth-id-42', email: 'a@b.co');

    final session = await signUp(
      username: 'ana',
      fullName: 'Ana Gómez',
      email: 'a@b.co',
      password: 'secreto123',
    );

    expect(profiles.createdId, 'auth-id-42');
    expect(profiles.createdEmail, 'a@b.co');
    expect(session.profile.id, 'auth-id-42');
    expect(session.profile.username, 'ana');
    expect(session.profile.fullName, 'Ana Gómez');
    expect(session.user.id, 'auth-id-42');
  });

  test('does not create the profile when Auth fails', () async {
    auth.signUpError = const NetworkFailure();

    await expectLater(run(), throwsA(isA<NetworkFailure>()));
    expect(log, ['auth.signUp']);
  });

  test('propagates a profile failure and closes the session', () async {
    profiles.createError = const PermissionDeniedFailure();

    await expectLater(
      run(),
      throwsA(
        isA<ProfileCreationFailure>()
            .having((f) => f.cause, 'cause', isA<PermissionDeniedFailure>())
            .having((f) => f.message, 'message', contains('permisos')),
      ),
    );
    expect(log, ['auth.signUp', 'profile.create', 'auth.signOut']);
  });

  test('wraps unexpected profile errors in ProfileCreationFailure', () async {
    profiles.createError = Exception('boom');

    await expectLater(run(), throwsA(isA<ProfileCreationFailure>()));
  });

  test('a taken email whose password does not match stays an error', () async {
    auth.signUpError = const EmailAlreadyRegisteredFailure();
    auth.signInError = const InvalidCredentialsFailure();

    await expectLater(run(), throwsA(isA<EmailAlreadyRegisteredFailure>()));
    expect(log, ['auth.signUp', 'auth.signIn']);
  });

  test('a taken email that already has a profile stays an error', () async {
    auth.signUpError = const EmailAlreadyRegisteredFailure();
    profiles.profiles[testUser.id] = testProfile;

    await expectLater(run(), throwsA(isA<EmailAlreadyRegisteredFailure>()));
    expect(log, ['auth.signUp', 'auth.signIn', 'profile.get', 'auth.signOut']);
  });

  test(
    'retrying after a failed profile insert completes the profile',
    () async {
      auth.signUpError = const EmailAlreadyRegisteredFailure();
      profiles.getError = const ProfileNotFoundFailure();

      final session = await run();

      expect(log, [
        'auth.signUp',
        'auth.signIn',
        'profile.get',
        'profile.create',
      ]);
      expect(session.profile.id, testUser.id);
    },
  );
}
