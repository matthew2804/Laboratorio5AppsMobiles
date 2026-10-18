import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:moviles_auth/core/config/supabase_config.dart';

String _fakeJwt(String role) {
  String part(Map<String, dynamic> json) =>
      base64Url.encode(utf8.encode(jsonEncode(json))).replaceAll('=', '');
  return '${part({'alg': 'HS256'})}.${part({'role': role})}.signature';
}

void main() {
  test('accepts a URL and a publishable key', () {
    const config = SupabaseConfig(
      url: 'https://example.supabase.co',
      publishableKey: 'sb_publishable_abc',
    );

    expect(config.validate(), isNull);
  });

  test('reports missing values', () {
    const config = SupabaseConfig(url: '', publishableKey: '');

    expect(config.validate(), contains('SUPABASE_URL'));
    expect(config.validate(), contains('SUPABASE_PUBLISHABLE_KEY'));
  });

  test('rejects an invalid URL', () {
    const config = SupabaseConfig(url: 'no-url', publishableKey: 'k');

    expect(config.validate(), contains('URL'));
  });

  test('rejects secret and service_role keys', () {
    expect(
      const SupabaseConfig(
        url: 'https://example.supabase.co',
        publishableKey: 'sb_secret_abc',
      ).validate(),
      contains('secreta'),
    );
    expect(
      SupabaseConfig(
        url: 'https://example.supabase.co',
        publishableKey: _fakeJwt('service_role'),
      ).validate(),
      contains('secreta'),
    );
    expect(
      SupabaseConfig(
        url: 'https://example.supabase.co',
        publishableKey: _fakeJwt('anon'),
      ).validate(),
      isNull,
    );
  });
}
