import 'dart:convert';

/// Supabase project settings, read at compile time from `--dart-define` or
/// `--dart-define-from-file=config/supabase.json`.
///
/// Only the publishable (or legacy anon) key belongs in the app. Its access
/// is limited by the RLS policies of the database.
class SupabaseConfig {
  static const urlKey = 'SUPABASE_URL';
  static const publishableKeyKey = 'SUPABASE_PUBLISHABLE_KEY';

  final String url;
  final String publishableKey;

  const SupabaseConfig({required this.url, required this.publishableKey});

  factory SupabaseConfig.fromEnvironment() => const SupabaseConfig(
    url: String.fromEnvironment(urlKey),
    publishableKey: String.fromEnvironment(publishableKeyKey),
  );

  /// Describes what is wrong with the settings, or returns null when they
  /// can be used. Never includes the key itself.
  String? validate() {
    final url = this.url.trim();
    final key = publishableKey.trim();
    if (url.isEmpty || key.isEmpty) {
      final missing = [
        if (url.isEmpty) urlKey,
        if (key.isEmpty) publishableKeyKey,
      ].join(' y ');
      return 'Falta configurar $missing.';
    }
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      return '$urlKey no es una URL válida.';
    }
    if (_isSecretKey(key)) {
      return 'La clave configurada es secreta (service_role o sb_secret). '
          'Usa la publishable key del proyecto.';
    }
    return null;
  }

  static bool _isSecretKey(String key) {
    if (key.startsWith('sb_secret_')) return true;
    final parts = key.split('.');
    if (parts.length != 3) return false;
    try {
      final payload = utf8.decode(
        base64Url.decode(base64Url.normalize(parts[1])),
      );
      final role = (jsonDecode(payload) as Map<String, dynamic>)['role'];
      return role == 'service_role';
    } catch (_) {
      return false;
    }
  }
}
