// ABOUTME: Keycast OAuth client for authentication flow
// ABOUTME: Handles authorization URL generation, callback parsing, and token exchange

import 'dart:convert';
import 'package:http/http.dart' as http;

import 'oauth_config.dart';
import 'callback_result.dart';
import 'token_response.dart';
import 'pkce.dart';
import '../crypto/key_utils.dart';
import '../models/exceptions.dart';

class KeycastOAuth {
  final OAuthConfig config;
  final http.Client _client;

  KeycastOAuth({
    required this.config,
    http.Client? httpClient,
  }) : _client = httpClient ?? http.Client();

  (String url, String verifier) getAuthorizationUrl({
    String? nsec,
    String scope = 'policy:social',
    bool defaultRegister = true,
  }) {
    String? byokPubkey;
    if (nsec != null) {
      byokPubkey = KeyUtils.derivePublicKeyFromNsec(nsec);
      if (byokPubkey == null) {
        return ('', '');
      }
    }

    final verifier = Pkce.generateVerifier(nsec: nsec);
    final challenge = Pkce.generateChallenge(verifier);

    final params = <String, String>{
      'client_id': config.clientId,
      'redirect_uri': config.redirectUri,
      'scope': scope,
      'code_challenge': challenge,
      'code_challenge_method': 'S256',
      'default_register': defaultRegister.toString(),
    };

    if (byokPubkey != null) {
      params['byok_pubkey'] = byokPubkey;
    }

    final uri = Uri.parse(config.authorizeUrl).replace(queryParameters: params);
    return (uri.toString(), verifier);
  }

  CallbackResult parseCallback(String url) {
    final uri = Uri.parse(url);
    final params = uri.queryParameters;

    if (params.containsKey('error')) {
      return CallbackError(
        error: params['error']!,
        description: params['error_description'],
      );
    }

    if (params.containsKey('code')) {
      return CallbackSuccess(code: params['code']!);
    }

    return CallbackError(
      error: 'invalid_response',
      description: 'Missing code or error in callback URL',
    );
  }

  Future<TokenResponse> exchangeCode({
    required String code,
    required String verifier,
  }) async {
    final response = await _client.post(
      Uri.parse(config.tokenUrl),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'grant_type': 'authorization_code',
        'code': code,
        'client_id': config.clientId,
        'redirect_uri': config.redirectUri,
        'code_verifier': verifier,
      }),
    );

    final json = jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode != 200) {
      final error = json['error'] as String? ?? 'unknown_error';
      final description = json['error_description'] as String?;
      throw OAuthException(
        description ?? 'Token exchange failed',
        errorCode: error,
      );
    }

    return TokenResponse.fromJson(json);
  }

  Future<void> disconnect() async {
    await _client.post(
      Uri.parse('${config.serverUrl}/api/auth/logout'),
    );
  }

  void close() {
    _client.close();
  }
}
