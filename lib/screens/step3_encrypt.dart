// ABOUTME: Step 3 - Encryption screen demonstrating NIP-44 and NIP-04
// ABOUTME: Shows encrypt and decrypt RPC calls with round-trip testing

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:keycast_flutter/keycast_flutter.dart';

import '../theme/app_theme.dart';
import '../providers/demo_provider.dart';
import '../widgets/result_display.dart';
import '../widgets/info_card.dart';

class Step3Encrypt extends ConsumerStatefulWidget {
  const Step3Encrypt({super.key});

  @override
  ConsumerState<Step3Encrypt> createState() => _Step3EncryptState();
}

class _Step3EncryptState extends ConsumerState<Step3Encrypt> {
  final _pubkeyController = TextEditingController();
  final _plaintextController = TextEditingController(text: 'Secret message!');
  final _ciphertextController = TextEditingController();

  bool _useNip44 = true;
  String? _encryptResult;
  String? _decryptResult;
  String? _error;
  bool _loading = false;
  bool _initializedPubkey = false;

  @override
  void dispose() {
    _pubkeyController.dispose();
    _plaintextController.dispose();
    _ciphertextController.dispose();
    super.dispose();
  }

  void _initializePubkeyIfNeeded() {
    if (_initializedPubkey) return;
    final session = ref.read(sessionProvider);
    if (session?.userPubkey != null && _pubkeyController.text.isEmpty) {
      _pubkeyController.text = session!.userPubkey!;
      _initializedPubkey = true;
    }
  }

  Future<void> _encrypt() async {
    final rpc = ref.read(rpcClientProvider);
    if (rpc == null) return;

    final pubkey = _pubkeyController.text.trim();
    final plaintext = _plaintextController.text;

    if (pubkey.isEmpty) {
      setState(() {
        _error = 'Enter a recipient pubkey';
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _encryptResult = null;
    });

    try {
      final ciphertext = _useNip44
          ? await rpc.nip44Encrypt(pubkey, plaintext)
          : await rpc.encrypt(pubkey, plaintext);

      setState(() {
        _encryptResult = ciphertext;
        _ciphertextController.text = ciphertext ?? '';
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

  Future<void> _decrypt() async {
    final rpc = ref.read(rpcClientProvider);
    if (rpc == null) return;

    final pubkey = _pubkeyController.text.trim();
    final ciphertext = _ciphertextController.text.trim();

    if (pubkey.isEmpty || ciphertext.isEmpty) {
      setState(() {
        _error = 'Enter both pubkey and ciphertext';
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _decryptResult = null;
    });

    try {
      final plaintext = _useNip44
          ? await rpc.nip44Decrypt(pubkey, ciphertext)
          : await rpc.decrypt(pubkey, ciphertext);

      setState(() {
        _decryptResult = plaintext;
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

  void _useOwnPubkey() {
    final session = ref.read(sessionProvider);
    if (session?.userPubkey != null) {
      _pubkeyController.text = session!.userPubkey!;
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

    // Auto-populate pubkey with user's own key on first visit
    _initializePubkeyIfNeeded();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Encrypt/Decrypt',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'NIP-44 and NIP-04 encryption via RPC',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          const InfoCard(
            text: 'NIP-44 is the modern standard with better security. '
                'NIP-04 is legacy but still widely used. Both use the '
                'recipient\'s pubkey to encrypt messages only they can decrypt.',
            icon: Icons.security,
          ),
          const SizedBox(height: 24),

          Row(
            children: [
              const Text('Encryption Method: '),
              const SizedBox(width: 16),
              ChoiceChip(
                label: const Text('NIP-44'),
                selected: _useNip44,
                onSelected: (selected) {
                  setState(() {
                    _useNip44 = true;
                  });
                },
                selectedColor: AppTheme.primaryGreen,
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                label: const Text('NIP-04'),
                selected: !_useNip44,
                onSelected: (selected) {
                  setState(() {
                    _useNip44 = false;
                  });
                },
                selectedColor: AppTheme.primaryGreen,
              ),
            ],
          ),
          const SizedBox(height: 24),

          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _pubkeyController,
                  decoration: const InputDecoration(
                    labelText: 'Recipient/Sender Pubkey (hex)',
                    hintText: '64-character hex pubkey',
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.person),
                tooltip: 'Use my pubkey',
                onPressed: session.userPubkey != null ? _useOwnPubkey : null,
              ),
            ],
          ),
          const SizedBox(height: 32),

          Text(
            'Encrypt',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            _useNip44 ? 'RPC method: nip44_encrypt' : 'RPC method: nip04_encrypt',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _plaintextController,
            decoration: const InputDecoration(
              labelText: 'Plaintext',
              hintText: 'Enter message to encrypt',
            ),
            maxLines: 2,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loading ? null : _encrypt,
            child: _loading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Encrypt'),
          ),
          if (_encryptResult != null) ...[
            const SizedBox(height: 16),
            ResultDisplay(
              title: 'Ciphertext',
              content: _encryptResult!,
            ),
          ],
          const SizedBox(height: 32),

          const Divider(color: AppTheme.cardBackground),
          const SizedBox(height: 32),

          Text(
            'Decrypt',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            _useNip44 ? 'RPC method: nip44_decrypt' : 'RPC method: nip04_decrypt',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _ciphertextController,
            decoration: const InputDecoration(
              labelText: 'Ciphertext',
              hintText: 'Enter ciphertext to decrypt',
            ),
            maxLines: 2,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loading ? null : _decrypt,
            child: const Text('Decrypt'),
          ),
          if (_decryptResult != null) ...[
            const SizedBox(height: 16),
            ResultDisplay(
              title: 'Decrypted Plaintext',
              content: _decryptResult!,
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
            'NIP-46 Remote Encryption',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          const InfoCard(
            text: 'Bunker mode uses NIP-46 for encryption operations over Nostr relays. '
                'Both NIP-44 and NIP-04 encryption are supported.',
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
            'NIP-46 Encryption Flow',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          const Text(
            '1. Connect to bunker via relays\n'
            '2. Send encrypt/decrypt request\n'
            '3. Bunker performs crypto operation\n'
            '4. Receive result over relay',
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
              'Connect with Keycast first to use encryption.',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
