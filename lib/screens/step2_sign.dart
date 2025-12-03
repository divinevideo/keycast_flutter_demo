// ABOUTME: Step 2 - Sign events screen demonstrating RPC signing
// ABOUTME: Shows get_public_key and sign_event RPC calls

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:keycast_flutter/keycast_flutter.dart';
import 'package:nostr_sdk/nostr_sdk.dart';

import '../theme/app_theme.dart';
import '../providers/demo_provider.dart';
import '../widgets/result_display.dart';
import '../widgets/info_card.dart';

class Step2Sign extends ConsumerStatefulWidget {
  const Step2Sign({super.key});

  @override
  ConsumerState<Step2Sign> createState() => _Step2SignState();
}

class _Step2SignState extends ConsumerState<Step2Sign> {
  final _contentController = TextEditingController(text: 'Hello from Keycast Flutter Demo!');
  String? _pubkey;
  String? _npub;
  Event? _signedEvent;
  String? _error;
  bool _loading = false;

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _getPublicKey() async {
    final rpc = ref.read(rpcClientProvider);
    if (rpc == null) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final pubkey = await rpc.getPublicKey();
      setState(() {
        _pubkey = pubkey;
        _npub = pubkey != null ? Nip19.encodePubKey(pubkey) : null;
      });
      if (pubkey != null) {
        ref.read(sessionProvider.notifier).updateUserPubkey(pubkey);
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  Future<void> _signEvent() async {
    final rpc = ref.read(rpcClientProvider);
    if (rpc == null || _pubkey == null) return;

    setState(() {
      _loading = true;
      _error = null;
      _signedEvent = null;
    });

    try {
      final unsigned = Event(
        _pubkey!,
        1,
        [],
        _contentController.text,
      );

      final signed = await rpc.signEvent(unsigned);
      setState(() {
        _signedEvent = signed;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionProvider);
    final rpc = ref.watch(rpcClientProvider);
    final signingMode = ref.watch(signingModeProvider);

    if (session == null) {
      return _buildNotConnected();
    }

    if (signingMode == SigningMode.bunker) {
      return _buildBunkerMode(session);
    }

    if (rpc == null) {
      return _buildNotConnected();
    }

    final generatedKey = ref.watch(generatedKeyProvider);
    final wasByokFlow = generatedKey != null;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Sign Events',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Server-side signing via RPC API',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          const InfoCard(
            text: 'Signing happens server-side. Your app sends unsigned events '
                'to Keycast, which signs them with the stored private key.',
            icon: Icons.cloud,
          ),
          const SizedBox(height: 24),

          Text(
            'Get Public Key',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            'RPC method: get_public_key',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loading ? null : _getPublicKey,
            child: _loading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Get Public Key'),
          ),
          if (_pubkey != null) ...[
            const SizedBox(height: 16),
            const Text(
              'Server Response',
              style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            KeyValueDisplay(data: {
              'hex': _pubkey!,
              'npub': _npub ?? '',
            }),
            if (wasByokFlow) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _npub == generatedKey.npub
                      ? AppTheme.successGreen.withValues(alpha: 0.1)
                      : AppTheme.errorRed.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _npub == generatedKey.npub
                        ? AppTheme.successGreen.withValues(alpha: 0.3)
                        : AppTheme.errorRed.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      _npub == generatedKey.npub
                          ? Icons.check_circle
                          : Icons.error,
                      size: 18,
                      color: _npub == generatedKey.npub
                          ? AppTheme.successGreen
                          : AppTheme.errorRed,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _npub == generatedKey.npub
                            ? 'Server pubkey matches local BYOK keypair'
                            : 'Mismatch! Server pubkey differs from local',
                        style: TextStyle(
                          color: _npub == generatedKey.npub
                              ? AppTheme.successGreen
                              : AppTheme.errorRed,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Local Keypair (BYOK)',
                style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 8),
              KeyValueDisplay(data: {
                'npub': generatedKey.npub,
              }),
            ],
          ],
          const SizedBox(height: 32),

          const Divider(color: AppTheme.cardBackground),
          const SizedBox(height: 24),

          Text(
            'Sign Event',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            'RPC method: sign_event',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          const InfoCard(
            text: 'Creates a Kind 1 note (text post). The event is constructed '
                'locally with your content, then sent to Keycast for signing.',
            icon: Icons.edit_note,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _contentController,
            decoration: const InputDecoration(
              labelText: 'Note content',
              hintText: 'Hello world!',
            ),
            maxLines: 3,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loading || _pubkey == null ? null : _signEvent,
            child: const Text('Sign Event'),
          ),
          if (_signedEvent != null) ...[
            const SizedBox(height: 16),
            const Text(
              'Signed Event (ready to publish)',
              style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            ResultDisplay(
              title: 'JSON',
              content: const JsonEncoder.withIndent('  ').convert(_signedEvent!.toJson()),
            ),
            const SizedBox(height: 8),
            const InfoCard(
              text: 'The event now has a valid id and sig. It can be published '
                  'to any Nostr relay.',
              icon: Icons.check_circle_outline,
            ),
          ],

          if (_error != null) ...[
            const SizedBox(height: 16),
            ResultDisplay(
              title: 'Error',
              content: _error!,
              isError: true,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBunkerMode(KeycastSession session) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Bunker Mode',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'NIP-46 Remote Signing',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          const InfoCard(
            text: 'Bunker mode uses NIP-46 to sign events over Nostr relays. '
                'Your bunker URL contains the remote signer pubkey and relays.',
            icon: Icons.hub,
          ),
          const SizedBox(height: 24),
          Text(
            'Bunker URL',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          ResultDisplay(
            title: 'bunker://',
            content: session.bunkerUrl,
          ),
          const SizedBox(height: 24),
          const InfoCard(
            text: 'NIP-46 is not yet implemented in nostr_sdk. You can use the '
                'NDK package (pub.dev/packages/ndk) which has built-in NIP-46 support.',
            icon: Icons.info_outline,
          ),
          const SizedBox(height: 24),
          Text(
            'NIP-46 Flow',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          const Text(
            '1. Parse bunker URL for pubkey + relays\n'
            '2. Connect to relays via WebSocket\n'
            '3. Send encrypted request (kind 24133)\n'
            '4. Receive encrypted response\n'
            '5. Event is signed and ready to publish',
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 13,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotConnected() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.lock_outline,
              size: 64,
              color: AppTheme.textSecondary,
            ),
            const SizedBox(height: 16),
            Text(
              'Not Connected',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Connect with Keycast first to sign events.',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
