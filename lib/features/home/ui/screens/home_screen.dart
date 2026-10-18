import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:moviles_auth/components/error_message.dart';
import 'package:moviles_auth/components/primary_button.dart';
import 'package:moviles_auth/components/profile_field.dart';
import 'package:moviles_auth/features/home/ui/bloc/home_bloc.dart';
import 'package:moviles_auth/theme/app_theme.dart';

/// Shows the profile of the signed in user and lets them sign out.
class HomeScreen extends StatelessWidget {
  final String username;
  final String fullName;
  final String email;

  const HomeScreen({
    super.key,
    required this.username,
    required this.fullName,
    required this.email,
  });

  void _signOut(BuildContext context) {
    context.read<HomeBloc>().add(const SignOutRequested());
  }

  void _onStateChanged(BuildContext context, HomeState state) {
    if (state.status == HomeStatus.signedOut) {
      Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<HomeBloc, HomeState>(
      listenWhen: (previous, current) => previous.status != current.status,
      listener: _onStateChanged,
      child: _buildScaffold(context),
    );
  }

  Widget _buildScaffold(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Perfil')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Container(
                width: 96,
                height: 96,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  fullName.isEmpty ? '?' : fullName[0].toUpperCase(),
                  style: const TextStyle(
                    fontSize: 40,
                    fontWeight: FontWeight.w700,
                    color: AppColors.surface,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                fullName,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '@$username',
                style: const TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 32),
              ProfileField(
                icon: Icons.alternate_email,
                label: 'Nombre de usuario',
                value: username,
              ),
              const SizedBox(height: 12),
              ProfileField(
                icon: Icons.person_outline,
                label: 'Nombre completo',
                value: fullName,
              ),
              const SizedBox(height: 12),
              ProfileField(
                icon: Icons.mail_outline,
                label: 'Correo',
                value: email,
              ),
              const SizedBox(height: 32),
              BlocBuilder<HomeBloc, HomeState>(
                builder: (context, state) {
                  final errorMessage = state.status == HomeStatus.failure
                      ? state.errorMessage
                      : null;
                  return Column(
                    children: [
                      if (errorMessage != null) ...[
                        ErrorMessage(message: errorMessage),
                        const SizedBox(height: 16),
                      ],
                      PrimaryButton(
                        label: 'Cerrar sesión',
                        isLoading:
                            state.status == HomeStatus.loading ||
                            state.status == HomeStatus.signedOut,
                        onPressed: () => _signOut(context),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
