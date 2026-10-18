import 'package:flutter/material.dart';

import 'package:moviles_auth/components/error_message.dart';
import 'package:moviles_auth/theme/app_theme.dart';

/// Shown instead of the app when Supabase cannot be configured.
class ConfigurationErrorApp extends StatelessWidget {
  final String message;

  const ConfigurationErrorApp({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Moviles Auth',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      home: Scaffold(
        appBar: AppBar(title: const Text('Configuración incompleta')),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'No se pudo conectar con Supabase',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 16),
                ErrorMessage(message: message),
                const SizedBox(height: 16),
                const Text(
                  'Copia config/supabase.example.json como '
                  'config/supabase.json, escribe la URL y la publishable key '
                  'del proyecto y ejecuta:\n\n'
                  'flutter run --dart-define-from-file=config/supabase.json',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
