// ABOUTME: Entry point for Keycast Flutter Demo app
// ABOUTME: Sets up Riverpod, theme, and deep link handling for OAuth callback

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:app_links/app_links.dart';
import 'package:keycast_flutter/keycast_flutter.dart';

import 'theme/app_theme.dart';
import 'screens/demo_screen.dart';
import 'providers/demo_provider.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: KeycastDemoApp()));
}

class KeycastDemoApp extends ConsumerStatefulWidget {
  const KeycastDemoApp({super.key});

  @override
  ConsumerState<KeycastDemoApp> createState() => _KeycastDemoAppState();
}

class _KeycastDemoAppState extends ConsumerState<KeycastDemoApp> {
  final _appLinks = AppLinks();
  final _scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

  @override
  void initState() {
    super.initState();
    _initDeepLinks();
  }

  Future<void> _initDeepLinks() async {
    final initialLink = await _appLinks.getInitialLink();
    if (initialLink != null) {
      _handleDeepLink(initialLink);
    }

    _appLinks.uriLinkStream.listen(_handleDeepLink);
  }

  Future<void> _handleDeepLink(Uri uri) async {
    debugPrint('[Keycast] Received deep link: $uri');

    // Handle Universal Links callback
    // Universal Link: https://login.divine.video/app/callback?code=...
    // Note: With flutter_web_auth_2 and iOS 17.4+, the callback is handled
    // automatically by ASWebAuthenticationSession. This handler is a fallback
    // for cases where the app is opened via deep link (e.g., from browser redirect)
    final isUniversalLink = uri.scheme == 'https' &&
        uri.host == 'login.divine.video' &&
        uri.path.startsWith('/app/callback');

    final isOAuthCallback = isUniversalLink;

    if (!isOAuthCallback) {
      debugPrint('[Keycast] Not an OAuth callback, ignoring');
      return;
    }

    debugPrint('[Keycast] Processing OAuth callback...');

    final oauth = ref.read(oauthClientProvider);
    final result = oauth.parseCallback(uri.toString());

    if (result is CallbackSuccess) {
      final verifier = ref.read(pendingVerifierProvider);
      if (verifier == null) {
        _showError('No pending OAuth flow');
        return;
      }

      try {
        debugPrint('[Keycast] Exchanging code for tokens...');
        final tokenResponse = await oauth.exchangeCode(
          code: result.code,
          verifier: verifier,
        );
        debugPrint('[Keycast] Token exchange successful');

        final session = KeycastSession.fromTokenResponse(tokenResponse);
        await ref.read(sessionProvider.notifier).setSession(session);

        ref.read(pendingVerifierProvider.notifier).set(null);

        _showSuccess('Connected successfully!');
      } catch (e, stackTrace) {
        debugPrint('[Keycast] Token exchange failed: $e');
        debugPrint('[Keycast] Stack trace: $stackTrace');
        _showError('Token exchange failed: $e');
      }
    } else if (result is CallbackError) {
      _showError('OAuth error: ${result.error}');
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    _scaffoldMessengerKey.currentState?.showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppTheme.errorRed,
      ),
    );
  }

  void _showSuccess(String message) {
    if (!mounted) return;
    _scaffoldMessengerKey.currentState?.showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppTheme.successGreen,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      scaffoldMessengerKey: _scaffoldMessengerKey,
      title: 'Keycast Flutter Demo',
      theme: AppTheme.darkTheme,
      debugShowCheckedModeBanner: false,
      home: const DemoScreen(),
    );
  }
}
