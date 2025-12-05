// ABOUTME: Riverpod state management for Keycast demo app
// ABOUTME: Manages OAuth flow state, session, RPC client, and signing mode

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:keycast_flutter/keycast_flutter.dart';
import 'package:nostr_sdk/nostr_sdk.dart';

/// Signing mode determines how the app communicates with Keycast
enum SigningMode {
  /// HTTP RPC API - Direct calls to /api/nostr with Bearer token
  rpc,

  /// NIP-46 Bunker - Uses bunker:// URL over Nostr relays
  bunker,
}

/// Provider for the current signing mode
final signingModeProvider =
    NotifierProvider<SigningModeNotifier, SigningMode>(SigningModeNotifier.new);

class SigningModeNotifier extends Notifier<SigningMode> {
  @override
  SigningMode build() => SigningMode.rpc;

  void setMode(SigningMode mode) {
    state = mode;
  }

  void toggle() {
    state = state == SigningMode.rpc ? SigningMode.bunker : SigningMode.rpc;
  }
}

/// Provides the appropriate NostrSigner based on signing mode
final signerProvider = Provider<NostrSigner?>((ref) {
  final mode = ref.watch(signingModeProvider);
  final session = ref.watch(sessionProvider);

  if (session == null) return null;

  switch (mode) {
    case SigningMode.rpc:
      return ref.watch(rpcClientProvider);
    case SigningMode.bunker:
      // Bunker mode would use NostrRemoteSigner from nostr_sdk
      // For now, return null - Sign/Encrypt tabs will show bunker info
      return null;
  }
});

final oauthConfigProvider = Provider<OAuthConfig>((ref) {
  return const OAuthConfig(
    serverUrl: 'https://login.divine.video',
    clientId: 'divine-flutter-demo',
    // Use Universal Links (https) for secure OAuth callback
    // iOS 17.4+ supports this via ASWebAuthenticationSession.Callback.https
    // DNS ownership proves app identity - more secure than custom URL schemes
    redirectUri: 'https://login.divine.video/app/callback',
  );
});

final oauthClientProvider = Provider<KeycastOAuth>((ref) {
  final config = ref.watch(oauthConfigProvider);
  return KeycastOAuth(
    config: config,
    storage: SecureKeycastStorage(),
  );
});

final sessionProvider =
    NotifierProvider<SessionNotifier, KeycastSession?>(SessionNotifier.new);

class SessionNotifier extends Notifier<KeycastSession?> {
  @override
  KeycastSession? build() {
    _loadSession();
    return null;
  }

  Future<void> _loadSession() async {
    state = await KeycastSession.load();
  }

  Future<void> setSession(KeycastSession session) async {
    state = session;
    await session.save();
  }

  Future<void> clearSession() async {
    await KeycastSession.clear();
    state = null;
  }

  void updateUserPubkey(String pubkey) {
    if (state != null) {
      state = state!.copyWith(userPubkey: pubkey);
    }
  }
}

final rpcClientProvider = Provider<KeycastRpc?>((ref) {
  final config = ref.watch(oauthConfigProvider);
  final session = ref.watch(sessionProvider);

  if (session == null || !session.hasRpcAccess) {
    return null;
  }

  return KeycastRpc.fromSession(config, session);
});

final generatedKeyProvider =
    NotifierProvider<GeneratedKeyNotifier, GeneratedKey?>(
        GeneratedKeyNotifier.new);

class GeneratedKey {
  final String nsec;
  final String npub;
  final String hexPrivateKey;
  final String hexPublicKey;

  GeneratedKey({
    required this.nsec,
    required this.npub,
    required this.hexPrivateKey,
    required this.hexPublicKey,
  });
}

class GeneratedKeyNotifier extends Notifier<GeneratedKey?> {
  @override
  GeneratedKey? build() {
    return null;
  }

  void generateKey() {
    final hexPrivateKey = generatePrivateKey();
    final hexPublicKey = getPublicKey(hexPrivateKey);
    final nsec = Nip19.encodePrivateKey(hexPrivateKey);
    final npub = Nip19.encodePubKey(hexPublicKey);

    state = GeneratedKey(
      nsec: nsec,
      npub: npub,
      hexPrivateKey: hexPrivateKey,
      hexPublicKey: hexPublicKey,
    );
  }

  void setFromNsec(String nsec) {
    final hexPrivateKey = KeyUtils.parseNsec(nsec);
    if (hexPrivateKey == null) return;

    final hexPublicKey = KeyUtils.derivePublicKey(hexPrivateKey);
    if (hexPublicKey == null) return;

    final npub = Nip19.encodePubKey(hexPublicKey);

    state = GeneratedKey(
      nsec: nsec,
      npub: npub,
      hexPrivateKey: hexPrivateKey,
      hexPublicKey: hexPublicKey,
    );
  }

  void clear() {
    state = null;
  }
}

final pendingVerifierProvider =
    NotifierProvider<PendingVerifierNotifier, String?>(
        PendingVerifierNotifier.new);

class PendingVerifierNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void set(String? value) {
    state = value;
  }
}
