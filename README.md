# Keycast Flutter Demo

A reference implementation demonstrating how to integrate [Keycast](https://login.divine.video) authentication into a Flutter app. This project contains both a reusable library (`keycast_flutter`) and a working demo app.

**Purpose:** Working code as documentation for integrating Keycast into `divine-mobile`.

## Signing Modes

After authentication, `KeycastSession` provides two ways to sign Nostr events:

### 1. RPC Mode (Recommended)

Direct HTTPS calls to Keycast's RPC API. This demo uses RPC for better latency and scalability.

```dart
final rpc = KeycastRpc.fromSession(config, session);
final signedEvent = await rpc.signEvent(event);
```

### 2. NIP-46 Bunker Mode

The session also provides a `bunkerUrl` for NIP-46 remote signing over Nostr relays. Use this if you already have a NIP-46 client implementation (like NDK or a custom `NostrRemoteSigner`).

```dart
final bunkerUrl = session.bunkerUrl;
// bunker://<pubkey>?relay=wss://...&secret=...

// Use with your NIP-46 client:
final signer = NostrRemoteSigner.fromBunkerUrl(bunkerUrl);
```

Both modes support the same operations: `sign_event`, `get_public_key`, `nip44_encrypt`, `nip44_decrypt`, `nip04_encrypt`, `nip04_decrypt`.

## Quick Start

```bash
# Run on iOS simulator (recommended - OAuth works correctly)
flutter run -d "iPhone 15 Pro"

# Run on macOS (OAuth has known issues - see Troubleshooting)
flutter run -d macos
```

## Project Structure

```
keycast_flutter_demo/
├── packages/
│   ├── keycast_flutter/     # The library - copy this to divine-mobile
│   └── nostr_sdk/           # Minimal nostr_sdk (vendored from divine-mobile)
├── lib/                     # Demo app showing integration patterns
│   ├── main.dart            # Deep link handling setup
│   ├── providers/           # Riverpod state management
│   └── screens/             # 3-step demo UI
└── ios/Runner/
    └── Runner.entitlements  # Universal Links config
```

---

## Integration Guide for divine-mobile

### Step 1: Copy the Library

Copy `packages/keycast_flutter/` into `divine-mobile/mobile/packages/`.

Update `divine-mobile/mobile/pubspec.yaml`:
```yaml
dependencies:
  keycast_flutter:
    path: packages/keycast_flutter
```

### Step 2: Configure OAuth

Create a provider for OAuth configuration:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:keycast_flutter/keycast_flutter.dart';

final oauthConfigProvider = Provider<OAuthConfig>((ref) {
  return const OAuthConfig(
    serverUrl: 'https://login.divine.video',
    clientId: 'divine-mobile',
    redirectUri: 'https://login.divine.video/app/callback',
  );
});

final oauthClientProvider = Provider<KeycastOAuth>((ref) {
  final config = ref.watch(oauthConfigProvider);
  return KeycastOAuth(config: config);
});
```

### Step 3: Handle Deep Links (Universal Links)

In your app's main widget, set up deep link handling:

```dart
import 'package:app_links/app_links.dart';
import 'package:keycast_flutter/keycast_flutter.dart';

class MyApp extends ConsumerStatefulWidget {
  // ...
}

class _MyAppState extends ConsumerState<MyApp> {
  final _appLinks = AppLinks();

  @override
  void initState() {
    super.initState();
    _initDeepLinks();
  }

  Future<void> _initDeepLinks() async {
    // Handle app launch from Universal Link
    final initialLink = await _appLinks.getInitialLink();
    if (initialLink != null) {
      _handleOAuthCallback(initialLink);
    }

    // Handle Universal Links while app is running
    _appLinks.uriLinkStream.listen(_handleOAuthCallback);
  }

  Future<void> _handleOAuthCallback(Uri uri) async {
    // Only handle our OAuth callback URL
    if (uri.scheme != 'https' ||
        uri.host != 'login.divine.video' ||
        !uri.path.startsWith('/app/callback')) {
      return;
    }

    final oauth = ref.read(oauthClientProvider);
    final result = oauth.parseCallback(uri.toString());

    if (result is CallbackSuccess) {
      final verifier = ref.read(pendingVerifierProvider);
      if (verifier == null) return;

      try {
        final tokenResponse = await oauth.exchangeCode(
          code: result.code,
          verifier: verifier,
        );

        final session = KeycastSession.fromTokenResponse(tokenResponse);
        await session.save();

        // Update your app state here
      } catch (e) {
        // Handle error
      }
    }
  }
}
```

### Step 4: iOS Configuration (Universal Links)

Add to `ios/Runner/Runner.entitlements`:
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.developer.associated-domains</key>
    <array>
        <string>applinks:login.divine.video</string>
    </array>
</dict>
</plist>
```

Add `CODE_SIGN_ENTITLEMENTS = Runner/Runner.entitlements;` to your Xcode project's build settings (Debug, Release, and Profile configurations).

### Step 5: macOS Configuration (Universal Links)

> **Warning:** macOS HTTPS callbacks with ASWebAuthenticationSession do not work reliably due to Apple platform differences. The completion handler often doesn't fire on macOS, even though the same API works on iOS. See [Troubleshooting](#user-canceled-login--oauth-immediately-fails) for details.

macOS requires Associated Domains for HTTPS callbacks. Add to both `macos/Runner/DebugProfile.entitlements` and `macos/Runner/Release.entitlements`:
```xml
<key>com.apple.developer.associated-domains</key>
<array>
    <string>applinks:login.divine.video</string>
    <string>webcredentials:login.divine.video</string>
</array>
```

**Note:** macOS Universal Links require macOS 14.4+ and the same AASA file configuration as iOS. The app must be signed with an Apple Developer certificate that matches the AASA file's app IDs.

### Step 6: Android Configuration (App Links)

Add to `android/app/src/main/AndroidManifest.xml` inside `<activity>`:
```xml
<intent-filter android:autoVerify="true">
    <action android:name="android.intent.action.VIEW"/>
    <category android:name="android.intent.category.DEFAULT"/>
    <category android:name="android.intent.category.BROWSABLE"/>
    <data android:scheme="https" android:host="login.divine.video" android:pathPrefix="/app/callback"/>
</intent-filter>
```

---

## Usage Examples

### Starting OAuth Flow (Server-Generated Key)

```dart
// User wants a NEW Nostr identity created by Keycast
void connectWithKeycast() async {
  final oauth = ref.read(oauthClientProvider);

  final (url, verifier) = oauth.getAuthorizationUrl(
    scope: 'policy:social',
    defaultRegister: true,
  );

  // Store verifier for token exchange later
  ref.read(pendingVerifierProvider.notifier).set(verifier);

  // Open OAuth page in browser
  await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
}
```

### Starting OAuth Flow (BYOK - Bring Your Own Key)

```dart
// User wants to use their EXISTING Nostr identity
void connectWithBYOK(String nsec) async {
  final oauth = ref.read(oauthClientProvider);

  // Pass nsec - the library derives byok_pubkey internally
  final (url, verifier) = oauth.getAuthorizationUrl(
    nsec: nsec,  // e.g., "nsec1..."
    scope: 'policy:social',
    defaultRegister: true,
  );

  ref.read(pendingVerifierProvider.notifier).set(verifier);
  await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
}
```

### Using the RPC Client (NostrSigner)

`KeycastRpc` implements the `NostrSigner` interface, making it a drop-in replacement:

```dart
// Create RPC client from session
final session = await KeycastSession.load();
if (session == null || !session.hasRpcAccess) {
  throw Exception('Not authenticated');
}

final config = ref.read(oauthConfigProvider);
final rpc = KeycastRpc.fromSession(config, session);

// Get public key
final pubkey = await rpc.getPublicKey();

// Sign an event
final event = Event(
  kind: 1,
  content: 'Hello from divine-mobile!',
  tags: [],
  createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
  pubkey: pubkey!,
);
final signedEvent = await rpc.signEvent(event);

// Encrypt (NIP-44)
final ciphertext = await rpc.nip44Encrypt(recipientPubkey, 'secret message');

// Decrypt (NIP-44)
final plaintext = await rpc.nip44Decrypt(senderPubkey, ciphertext);
```

### Session Persistence

Sessions are automatically persisted using `flutter_secure_storage`:

```dart
// Save after successful OAuth
final session = KeycastSession.fromTokenResponse(tokenResponse);
await session.save();

// Load on app start
final session = await KeycastSession.load();
if (session != null && session.hasRpcAccess) {
  // User is authenticated
}

// Clear on logout
await KeycastSession.clear();
```

### Checking Token Expiry

```dart
final session = await KeycastSession.load();

if (session == null) {
  // Not logged in
} else if (session.isExpired) {
  // Token expired - need to re-authenticate
  await KeycastSession.clear();
} else if (session.hasRpcAccess) {
  // Ready to use RPC
}
```

---

## API Reference

### KeycastOAuth

```dart
class KeycastOAuth {
  KeycastOAuth({required OAuthConfig config, http.Client? httpClient});

  /// Generate authorization URL
  /// Returns (url, verifier) - store verifier for token exchange
  (String url, String verifier) getAuthorizationUrl({
    String? nsec,           // Optional: enables BYOK flow
    String scope,           // Default: 'policy:social'
    bool defaultRegister,   // Default: true
  });

  /// Exchange authorization code for tokens
  Future<TokenResponse> exchangeCode({
    required String code,
    required String verifier,
  });

  /// Parse callback URL
  CallbackResult parseCallback(String url);
}
```

### KeycastRpc (implements NostrSigner)

```dart
class KeycastRpc implements NostrSigner {
  KeycastRpc({required String nostrApi, required String accessToken});

  factory KeycastRpc.fromSession(OAuthConfig config, KeycastSession session);

  Future<String?> getPublicKey();
  Future<Event?> signEvent(Event event);
  Future<String?> nip44Encrypt(String pubkey, String plaintext);
  Future<String?> nip44Decrypt(String pubkey, String ciphertext);
  Future<String?> encrypt(String pubkey, String plaintext);   // NIP-04
  Future<String?> decrypt(String pubkey, String ciphertext);  // NIP-04
}
```

### KeycastSession

```dart
class KeycastSession {
  final String bunkerUrl;
  final String? accessToken;
  final DateTime? expiresAt;
  final String? scope;
  final String? userPubkey;

  bool get isExpired;
  bool get hasRpcAccess;

  factory KeycastSession.fromTokenResponse(TokenResponse response);

  Future<void> save();
  static Future<KeycastSession?> load();
  static Future<void> clear();
}
```

---

## Server Configuration

The Keycast server at `login.divine.video` is already configured with:

- **AASA file:** `https://login.divine.video/.well-known/apple-app-site-association`
- **App IDs:** `GZCZBKH7MY.co.openvine.keycastFlutterDemo`, `GZCZBKH7MY.co.openvine.divine`
- **Callback path:** `/app/callback`

---

## Testing

The library includes comprehensive tests:

```bash
cd packages/keycast_flutter
flutter test
```

| Test File | Coverage |
|-----------|----------|
| `pkce_test.dart` | PKCE verifier/challenge, BYOK embedding |
| `oauth_client_test.dart` | URL building, token exchange, callback parsing |
| `rpc_client_test.dart` | All RPC methods, error handling |
| `session_test.dart` | Persistence, expiry, factory methods |
| `key_utils_test.dart` | nsec parsing, pubkey derivation |

All HTTP calls are mocked using `mocktail` - no network required.

---

## Troubleshooting

### "User canceled login" / OAuth immediately fails

This error occurs when ASWebAuthenticationSession can't match the callback URL. Common causes:

**1. Universal Links require Apple Developer Team membership.** The demo's AASA file at `login.divine.video` is configured for our Team ID (`GZCZBKH7MY`). If you build with a different Team ID, Universal Links won't work.

**2. macOS HTTPS callbacks don't work reliably.** Due to Apple platform differences, `ASWebAuthenticationSession.Callback.https` behaves differently on macOS vs iOS:
- **iOS 17.4+**: HTTPS callbacks work correctly - the completion handler fires
- **macOS 14.4+**: The completion handler often doesn't fire. The redirect goes to the Universal Links handler instead, causing the "User canceled login" error

This is a [known Apple platform behavior](https://stackoverflow.com/questions/61748589/does-aswebauthenticationsession-support-universal-links) that cannot be fixed through configuration. The flutter_web_auth_2 plugin would need platform-specific code to handle this.

**Solutions:**

1. **Use iOS for testing** - iOS (simulator and device) works correctly with HTTPS callbacks

2. **Read the code as reference** - The demo is primarily documentation. Study how OAuth + PKCE + Universal Links work, then implement in your own app

3. **Contact us** - If you're integrating with Keycast and need your app's bundle ID added to the AASA, reach out

### Universal Links not working in simulator

1. Delete and reinstall the app
2. iOS caches AASA files - wait a few minutes after server deploy
3. Check entitlements are in the built app: `codesign -d --entitlements - Runner.app`

### "Invalid redirect_uri" error

Ensure `redirectUri` in `OAuthConfig` matches exactly what's registered on the server:
```dart
redirectUri: 'https://login.divine.video/app/callback'  // Correct
redirectUri: 'https://login.divine.video/app/callback/' // Wrong (trailing slash)
```

### Token exchange fails

- Verify the `verifier` stored matches what was used to generate the URL
- Check the authorization `code` hasn't expired (typically 10 minutes)
- Ensure you're not reusing a code (single-use)

---

## License

MIT
