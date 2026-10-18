import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:moviles_auth/core/config/configuration_error_screen.dart';
import 'package:moviles_auth/core/config/supabase_config.dart';
import 'package:moviles_auth/features/auth/data/repository/auth_repository_impl.dart';
import 'package:moviles_auth/features/auth/data/repository/profile_repository_impl.dart';
import 'package:moviles_auth/features/auth/data/source/supabase_auth_data_source.dart';
import 'package:moviles_auth/features/auth/data/source/supabase_profile_data_source.dart';
import 'package:moviles_auth/features/auth/domain/entities/user_session.dart';
import 'package:moviles_auth/features/auth/domain/repository/auth_repository.dart';
import 'package:moviles_auth/features/auth/domain/repository/profile_repository.dart';
import 'package:moviles_auth/features/auth/domain/usecases/sign_in_usecase.dart';
import 'package:moviles_auth/features/auth/domain/usecases/sign_out_usecase.dart';
import 'package:moviles_auth/features/auth/domain/usecases/sign_up_usecase.dart';
import 'package:moviles_auth/features/home/ui/bloc/home_bloc.dart';
import 'package:moviles_auth/features/home/ui/screens/home_screen.dart';
import 'package:moviles_auth/features/login/ui/bloc/login_bloc.dart';
import 'package:moviles_auth/features/login/ui/screens/login_screen.dart';
import 'package:moviles_auth/features/register/ui/bloc/register_bloc.dart';
import 'package:moviles_auth/features/register/ui/screens/register_screen.dart';
import 'package:moviles_auth/theme/app_theme.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final config = SupabaseConfig.fromEnvironment();
  final configError = config.validate();
  if (configError != null) {
    runApp(ConfigurationErrorApp(message: configError));
    return;
  }

  try {
    await Supabase.initialize(
      url: config.url.trim(),
      publishableKey: config.publishableKey.trim(),
    );
  } catch (error) {
    developer.log('Supabase.initialize failed: ${error.runtimeType}');
    runApp(
      const ConfigurationErrorApp(
        message: 'No se pudo inicializar Supabase con la configuración dada.',
      ),
    );
    return;
  }

  final client = Supabase.instance.client;
  runApp(
    App(
      authRepository: AuthRepositoryImpl(SupabaseAuthDataSource(client)),
      profileRepository: ProfileRepositoryImpl(
        SupabaseProfileDataSource(client),
      ),
    ),
  );
}

/// Root widget that declares the theme and the named routes.
///
/// The repositories are received from outside so tests can replace them.
class App extends StatelessWidget {
  final AuthRepository authRepository;
  final ProfileRepository profileRepository;

  const App({
    super.key,
    required this.authRepository,
    required this.profileRepository,
  });

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider(
          create: (_) => SignUpUseCase(
            authRepository: authRepository,
            profileRepository: profileRepository,
          ),
        ),
        RepositoryProvider(
          create: (_) => SignInUseCase(
            authRepository: authRepository,
            profileRepository: profileRepository,
          ),
        ),
        RepositoryProvider(
          create: (_) => SignOutUseCase(authRepository: authRepository),
        ),
      ],
      child: MaterialApp(
        title: 'Moviles Auth',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(),
        initialRoute: '/login',
        routes: {
          '/login': (_) => _buildLogin(),
          '/register': (_) => BlocProvider(
            create: (context) =>
                RegisterBloc(signUpUseCase: context.read<SignUpUseCase>()),
            child: const RegisterScreen(),
          ),
          '/home': (context) {
            final session = ModalRoute.of(context)?.settings.arguments;
            // Without a signed in session there is nothing to show.
            if (session is! UserSession) return _buildLogin();
            return BlocProvider(
              create: (context) =>
                  HomeBloc(signOutUseCase: context.read<SignOutUseCase>()),
              child: HomeScreen(
                username: session.profile.username,
                fullName: session.profile.fullName,
                email: session.user.email,
              ),
            );
          },
        },
      ),
    );
  }

  Widget _buildLogin() {
    return BlocProvider(
      create: (context) =>
          LoginBloc(signInUseCase: context.read<SignInUseCase>()),
      child: const LoginScreen(),
    );
  }
}
