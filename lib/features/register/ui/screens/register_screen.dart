import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:moviles_auth/components/error_message.dart';
import 'package:moviles_auth/components/primary_button.dart';
import 'package:moviles_auth/features/register/ui/bloc/register_bloc.dart';
import 'package:moviles_auth/theme/app_theme.dart';

/// Sign up form with username, full name, email and password.
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  static final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  final _usernameController = TextEditingController();
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  /// Error found by the form itself, before anything is sent to the bloc.
  String? _validationError;

  @override
  void dispose() {
    _usernameController.dispose();
    _fullNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  String? _validate({
    required String username,
    required String fullName,
    required String email,
    required String password,
  }) {
    if (username.isEmpty ||
        fullName.isEmpty ||
        email.isEmpty ||
        password.isEmpty ||
        _confirmPasswordController.text.isEmpty) {
      return 'Completa todos los campos';
    }
    if (!_emailPattern.hasMatch(email)) {
      return 'Escribe un correo válido';
    }
    if (password.length < 6) {
      return 'La contraseña debe tener al menos 6 caracteres';
    }
    if (password != _confirmPasswordController.text) {
      return 'Las contraseñas no coinciden';
    }
    return null;
  }

  void _submit() {
    final bloc = context.read<RegisterBloc>();
    if (bloc.state.status == RegisterStatus.loading) return;

    final username = _usernameController.text.trim();
    final fullName = _fullNameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final error = _validate(
      username: username,
      fullName: fullName,
      email: email,
      password: password,
    );
    setState(() => _validationError = error);
    if (error != null) return;

    bloc.add(
      RegisterSubmitted(
        username: username,
        fullName: fullName,
        email: email,
        password: password,
      ),
    );
  }

  void _onStateChanged(BuildContext context, RegisterState state) {
    final session = state.session;
    if (state.status == RegisterStatus.success && session != null) {
      Navigator.pushReplacementNamed(context, '/home', arguments: session);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Crear cuenta')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: BlocListener<RegisterBloc, RegisterState>(
            listenWhen: (previous, current) =>
                previous.status != current.status,
            listener: _onStateChanged,
            child: BlocBuilder<RegisterBloc, RegisterState>(
              builder: (context, state) {
                final isLoading =
                    state.status == RegisterStatus.loading ||
                    state.status == RegisterStatus.success;
                final errorMessage =
                    _validationError ??
                    (state.status == RegisterStatus.failure
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
          'Crea tu cuenta',
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Completa tus datos para registrarte',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        const SizedBox(height: 32),
        TextField(
          controller: _usernameController,
          enabled: !isLoading,
          autocorrect: false,
          decoration: const InputDecoration(
            labelText: 'Nombre de usuario',
            prefixIcon: Icon(Icons.alternate_email),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _fullNameController,
          enabled: !isLoading,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            labelText: 'Nombre completo',
            prefixIcon: Icon(Icons.person_outline),
          ),
        ),
        const SizedBox(height: 16),
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
        const SizedBox(height: 16),
        TextField(
          controller: _confirmPasswordController,
          enabled: !isLoading,
          obscureText: true,
          decoration: const InputDecoration(
            labelText: 'Confirmar contraseña',
            prefixIcon: Icon(Icons.lock_outline),
          ),
        ),
        const SizedBox(height: 24),
        if (errorMessage != null) ...[
          ErrorMessage(message: errorMessage),
          const SizedBox(height: 16),
        ],
        PrimaryButton(
          label: 'Registrarme',
          isLoading: isLoading,
          onPressed: _submit,
        ),
        const SizedBox(height: 8),
        Center(
          child: TextButton(
            onPressed: isLoading
                ? null
                : () => Navigator.pushReplacementNamed(context, '/login'),
            child: const Text('¿Ya tienes cuenta? Inicia sesión'),
          ),
        ),
      ],
    );
  }
}
