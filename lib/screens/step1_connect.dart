// ABOUTME: OAuth connect screen with both server-generated and BYOK flows
// ABOUTME: Uses ASWebAuthenticationSession via flutter_web_auth_2 with Universal Links (iOS 17.4+)

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import 'package:keycast_flutter/keycast_flutter.dart';

import '../theme/app_theme.dart';
import '../providers/demo_provider.dart';
import '../widgets/result_display.dart';
import '../widgets/info_card.dart';

class Step1Connect extends ConsumerStatefulWidget {
  const Step1Connect({super.key});

  @override
  ConsumerState<Step1Connect> createState() => _Step1ConnectState();
}

class _Step1ConnectState extends ConsumerState<Step1Connect> {
  final _nsecController = TextEditingController();
  bool _showByokSection = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _nsecController.dispose();
    super.dispose();
  }

  Future<void> _connectWithKeycast({String? nsec}) async {
    final oauth = ref.read(oauthClientProvider);
    final (url, verifier) = oauth.getAuthorizationUrl(nsec: nsec);

    if (url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid nsec format')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      debugPrint('[Keycast] Starting OAuth flow with ASWebAuthenticationSession');
      debugPrint('[Keycast] Auth URL: $url');

      // Use ASWebAuthenticationSession via flutter_web_auth_2 with Universal Links
      // iOS 17.4+ supports https callbacks via ASWebAuthenticationSession.Callback.https
      // This provides DNS-verified app identity - more secure than custom URL schemes
      final result = await FlutterWebAuth2.authenticate(
        url: url,
        callbackUrlScheme: 'https',
        options: const FlutterWebAuth2Options(
          httpsHost: 'login.divine.video',
          httpsPath: '/app/callback',
        ),
      );

      debugPrint('[Keycast] OAuth callback received: $result');

      // Parse the callback URL
      final callbackResult = oauth.parseCallback(result);

      if (callbackResult is CallbackSuccess) {
        debugPrint('[Keycast] Exchanging code for tokens...');
        final tokenResponse = await oauth.exchangeCode(
          code: callbackResult.code,
          verifier: verifier,
        );
        debugPrint('[Keycast] Token exchange successful');

        final session = KeycastSession.fromTokenResponse(tokenResponse);
        await ref.read(sessionProvider.notifier).setSession(session);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Connected successfully!'),
              backgroundColor: AppTheme.successGreen,
            ),
          );
        }
      } else if (callbackResult is CallbackError) {
        throw Exception('OAuth error: ${callbackResult.error}');
      }
    } catch (e, stackTrace) {
      debugPrint('[Keycast] OAuth flow failed: $e');
      debugPrint('[Keycast] Stack trace: $stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Connection failed: $e'),
            backgroundColor: AppTheme.errorRed,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionProvider);
    final generatedKey = ref.watch(generatedKeyProvider);

    if (session != null) {
      return _buildConnectedState(session);
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Connect to Keycast',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'OAuth 2.0 + PKCE authentication flow',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          const InfoCard(
            text: 'Keycast is a Nostr signing service. It holds your private key '
                'and signs events on your behalf via API calls.',
            icon: Icons.key,
          ),
          const SizedBox(height: 24),

          Text(
            'Option A: Server-Generated Key',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            'Keycast creates a new Nostr identity for you. The private key is '
            'generated and stored server-side.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _isLoading ? null : () => _connectWithKeycast(),
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Connect with Keycast'),
          ),
          const SizedBox(height: 32),

          const Divider(color: AppTheme.cardBackground),
          const SizedBox(height: 24),

          Text(
            'Option B: Bring Your Own Key (BYOK)',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            'Use your existing Nostr identity. The nsec is securely transmitted '
            'to Keycast via the PKCE code_verifier.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          const InfoCard(
            text: 'BYOK embeds your nsec in the PKCE verifier as: '
                '"random_string.nsec1...". This is sent during token exchange, '
                'not in the URL.',
            icon: Icons.security,
          ),
          const SizedBox(height: 16),

          if (!_showByokSection)
            OutlinedButton(
              onPressed: () {
                setState(() {
                  _showByokSection = true;
                });
                ref.read(generatedKeyProvider.notifier).generateKey();
              },
              child: const Text('Set Up BYOK'),
            )
          else ...[
            if (generatedKey != null) ...[
              Row(
                children: [
                  const Icon(Icons.vpn_key, size: 16, color: AppTheme.textSecondary),
                  const SizedBox(width: 6),
                  const Text(
                    'Local Keypair',
                    style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryGreen.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'Generated on device',
                      style: TextStyle(
                        color: AppTheme.primaryGreen,
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              KeyValueDisplay(data: {
                'npub': generatedKey.npub,
                'nsec': generatedKey.nsec,
              }),
              const SizedBox(height: 12),
              const InfoCard(
                text: 'This keypair was generated locally. The nsec will be sent '
                    'to Keycast during OAuth. Compare the npub after connecting '
                    'to verify it matches.',
                icon: Icons.info_outline,
              ),
              const SizedBox(height: 16),
            ],
            TextFormField(
              controller: _nsecController,
              decoration: const InputDecoration(
                labelText: 'Or import existing nsec',
                hintText: 'nsec1...',
              ),
              onChanged: (value) {
                if (value.startsWith('nsec1') && value.length > 50) {
                  ref.read(generatedKeyProvider.notifier).setFromNsec(value);
                }
              },
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      ref.read(generatedKeyProvider.notifier).generateKey();
                      _nsecController.clear();
                    },
                    child: const Text('Generate Local Key'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: generatedKey != null && !_isLoading
                        ? () => _connectWithKeycast(nsec: generatedKey.nsec)
                        : null,
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Connect with BYOK'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildConnectedState(KeycastSession session) {
    final generatedKey = ref.watch(generatedKeyProvider);
    final wasByokFlow = generatedKey != null;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.check_circle, color: AppTheme.successGreen),
              const SizedBox(width: 8),
              Text(
                'Connected',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            wasByokFlow ? 'BYOK flow completed' : 'Server-generated key',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          const InfoCard(
            text: 'You now have an access token to make RPC calls. '
                'Go to the Sign tab to test signing events.',
            icon: Icons.arrow_forward,
          ),
          const SizedBox(height: 24),

          if (wasByokFlow) ...[
            Row(
              children: [
                const Icon(Icons.vpn_key, size: 16, color: AppTheme.textSecondary),
                const SizedBox(width: 6),
                const Text(
                  'Local Keypair (for comparison)',
                  style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w500),
                ),
              ],
            ),
            const SizedBox(height: 8),
            KeyValueDisplay(data: {
              'Local npub': generatedKey.npub,
              'Local nsec': '${generatedKey.nsec.substring(0, 20)}...',
            }),
            const SizedBox(height: 16),
          ],

          const Text(
            'Session Info',
            style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          KeyValueDisplay(data: {
            'Bunker URL': session.bunkerUrl.length > 60
                ? '${session.bunkerUrl.substring(0, 60)}...'
                : session.bunkerUrl,
            if (session.accessToken != null)
              'Access Token': '${session.accessToken!.substring(0, 20)}...',
            if (session.expiresAt != null)
              'Expires': session.expiresAt!.toIso8601String(),
            if (session.scope != null) 'Scope': session.scope!,
          }),
          const SizedBox(height: 24),
          OutlinedButton(
            onPressed: () async {
              await ref.read(sessionProvider.notifier).clearSession();
              ref.read(generatedKeyProvider.notifier).clear();
              setState(() {
                _showByokSection = false;
              });
            },
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.errorRed,
              side: const BorderSide(color: AppTheme.errorRed),
            ),
            child: const Text('Disconnect'),
          ),
        ],
      ),
    );
  }
}
