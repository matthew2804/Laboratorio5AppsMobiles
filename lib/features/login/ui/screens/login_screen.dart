import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:moviles_auth/components/error_message.dart';
import 'package:moviles_auth/components/primary_button.dart';
import 'package:moviles_auth/features/login/ui/bloc/login_bloc.dart';
import 'package:moviles_auth/theme/app_theme.dart';

/// Sign in form with email and password.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  /// Error found by the form itself, before anything is sent to the bloc.
  String? _validationError;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _submit() {
    final bloc = context.read<LoginBloc>();
    if (bloc.state.status == LoginStatus.loading) return;

    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final error = email.isEmpty || password.isEmpty
        ? 'Escribe tu correo y tu contraseña'
        : null;
    setState(() => _validationError = error);
    if (error != null) return;

    bloc.add(LoginSubmitted(email: email, password: password));
  }

  void _onStateChanged(BuildContext context, LoginState state) {
    final session = state.session;
    if (state.status == LoginStatus.success && session != null) {
      Navigator.pushReplacementNamed(context, '/home', arguments: session);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Iniciar sesión')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: BlocListener<LoginBloc, LoginState>(
            listenWhen: (previous, current) =>
                previous.status != current.status,
            listener: _onStateChanged,
            child: BlocBuilder<LoginBloc, LoginState>(
              builder: (context, state) {
                final isLoading =
                    state.status == LoginStatus.loading ||
                    state.status == LoginStatus.success;
                final errorMessage =
                    _validationError ??
                    (state.status == LoginStatus.failure
                        ? state.errorMessage
                        : null);
                return _buildForm(
                  isLoading: isLoading,
                  errorMessage: errorMessage,
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildForm({required bool isLoading, String? errorMessage}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Bienvenido de nuevo',
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Ingresa con tu correo y tu contraseña',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        const SizedBox(height: 32),
        TextField(
          controller: _emailController,
          enabled: !isLoading,
          keyboardType: TextInputType.emailAddress,
          autocorrect: false,
          decoration: const InputDecoration(
            labelText: 'Correo',
            prefixIcon: Icon(Icons.mail_outline),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _passwordController,
          enabled: !isLoading,
          obscureText: true,
          decoration: const InputDecoration(
            labelText: 'Contraseña',
            prefixIcon: Icon(Icons.lock_outline),
          ),
        ),
        const SizedBox(height: 24),
        if (errorMessage != null) ...[
          ErrorMessage(message: errorMessage),
          const SizedBox(height: 16),
        ],
        PrimaryButton(
          label: 'Iniciar sesión',
          isLoading: isLoading,
          onPressed: _submit,
        ),
        const SizedBox(height: 8),
        Center(
          child: TextButton(
            onPressed: isLoading
                ? null
                : () => Navigator.pushReplacementNamed(context, '/register'),
            child: const Text('¿No tienes cuenta? Regístrate'),
          ),
        ),
      ],
    );
  }
}
