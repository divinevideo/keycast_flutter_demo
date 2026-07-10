# Keycast Flutter Demo

A reference implementation showing how to add [Keycast](https://login.divine.video) authentication to a Flutter app. The repository is a pub workspace containing a reusable library, `keycast_flutter`, and a working demo app that exercises it. Keycast is a Nostr signing service: it holds the private key and signs events on the user's behalf over an authenticated API, so the app never has to handle raw keys. The demo covers the full flow — OAuth 2.0 with PKCE, optional BYOK (bring your own key), and remote signing/encryption — and doubles as working documentation for integrating Keycast elsewhere.

## What's in the box

```
keycast_flutter_demo/
├── packages/
│   ├── keycast_flutter/     # The library you integrate
│   └── nostr_sdk/           # Vendored nostr_sdk (Nip19, Event, NostrSigner, ...)
├── lib/                     # Demo app
│   ├── main.dart            # Deep-link handling for the OAuth callback
│   ├── providers/           # Riverpod state (config, session, signer, signing mode)
│   ├── screens/             # 3-step demo UI: connect, sign, encrypt
│   ├── widgets/             # Info cards and result display
│   └── theme/               # App theme
├── docs/keycast-oauth-flow.d2   # OAuth flow diagram (+ .png)
├── ios/  android/  macos/  linux/   # Platform runners and deep-link config
```

The demo requires Dart SDK `^3.10.0` and uses [pub workspaces](https://dart.dev/tools/pub/workspaces): the root `pubspec.yaml` declares the workspace members and the packages resolve locally via `path` dependencies.

## Install / add the library

`keycast_flutter` is not published to pub.dev (`publish_to: 'none'`). Integrate it by copying `packages/keycast_flutter/` (and its `packages/nostr_sdk/` dependency) into your app and referencing them as path dependencies:

```yaml
dependencies:
  keycast_flutter:
    path: packages/keycast_flutter
  nostr_sdk:
    path: packages/nostr_sdk
```

Then import the public API:

```dart
import 'package:keycast_flutter/keycast_flutter.dart';
```

The library depends on `http`, `crypto`, `flutter_secure_storage`, and the vendored `nostr_sdk`. The demo app additionally uses `flutter_riverpod`, `app_links`, `url_launcher`, and `flutter_web_auth_2` to drive the OAuth UI.

## Usage

### 1. Configure OAuth

```dart
const config = OAuthConfig(
  serverUrl: 'https://login.divine.video',
  clientId: 'divine-flutter-demo',
  redirectUri: 'https://login.divine.video/app/callback',
  // defaultScopes defaults to const ['policy:social']
);

final oauth = KeycastOAuth(
  config: config,
  storage: SecureKeycastStorage(), // optional; defaults to MemoryKeycastStorage
);
```

`OAuthConfig` derives the server endpoints it needs: `authorizeUrl` (`/api/oauth/authorize`), `tokenUrl` (`/api/oauth/token`), and `nostrApiUrl` (`/api/nostr`).

### 2. Start the OAuth + PKCE flow

`getAuthorizationUrl` is asynchronous and returns a `(String url, String verifier)` record. It generates the PKCE verifier/challenge for you; keep the returned `verifier` around — you need it to exchange the code. If a stored authorization handle exists it is reused automatically for silent re-auth.

```dart
// Server-generated key: Keycast creates a new Nostr identity.
final (url, verifier) = await oauth.getAuthorizationUrl(
  scope: 'policy:social',
  defaultRegister: true,
);

// Open `url` in a browser / auth session, then hold onto `verifier`.
```

**BYOK — bring your own key.** Pass an existing `nsec`. The library derives the `byok_pubkey` and embeds the secret in the PKCE `code_verifier`, so it never travels as a plain query parameter. If the `nsec` is malformed, `getAuthorizationUrl` returns an empty `url`:

```dart
final (url, verifier) = await oauth.getAuthorizationUrl(
  nsec: nsec, // e.g. "nsec1..."
  scope: 'policy:social',
);
if (url.isEmpty) {
  // Invalid nsec format — surface an error to the user.
}
```

How you open `url` and receive the callback is platform-specific. The demo uses `flutter_web_auth_2` (`ASWebAuthenticationSession`) on iOS with an HTTPS callback, and `url_launcher` + `app_links` on Android, where the App Link brings the user back into `main.dart`'s deep-link handler.

### 3. Handle the callback and exchange the code

`parseCallback` returns a sealed `CallbackResult` — either `CallbackSuccess(code)` or `CallbackError(error, description)`. On success, exchange the code together with the stored verifier. `exchangeCode` persists the session (and any authorization handle) to the configured storage automatically before returning the `TokenResponse`.

```dart
final result = oauth.parseCallback(callbackUrl);

if (result is CallbackSuccess) {
  final tokenResponse = await oauth.exchangeCode(
    code: result.code,
    verifier: verifier,
  );
  final session = KeycastSession.fromTokenResponse(tokenResponse);
  // Use / persist `session` (see below).
} else if (result is CallbackError) {
  // result.error, result.description
}
```

### 4. Sign and encrypt

`KeycastRpc` implements `nostr_sdk`'s `NostrSigner`, so it is a drop-in signer. Build it from a session that still has RPC access:

```dart
final session = await KeycastSession.load();
if (session == null || !session.hasRpcAccess) {
  throw SessionExpiredException();
}

final rpc = KeycastRpc.fromSession(config, session);

final pubkey = await rpc.getPublicKey();

final event = Event(
  pubkey!,   // pubkey
  1,         // kind
  [],        // tags
  'Hello from Keycast!', // content
  createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
);
final signed = await rpc.signEvent(event);

final ciphertext = await rpc.nip44Encrypt(recipientPubkey, 'secret message');
final plaintext = await rpc.nip44Decrypt(senderPubkey, ciphertext);
// nip04 equivalents: rpc.encrypt(...) / rpc.decrypt(...)
```

### 5. Persist the session

`KeycastSession` serializes to `flutter_secure_storage`. `hasRpcAccess` is true when the session has an access token and has not expired.

```dart
await session.save();                          // store after a successful exchange
final restored = await KeycastSession.load();  // on app start
if (restored != null && restored.isExpired) {
  await KeycastSession.clear();
}
```

To log the user out, call `oauth.logout()` — it clears the stored session and authorization handle and posts to the server's `/api/auth/logout`.

## Signing modes

After authentication, a session gives you two ways to sign Nostr events. The demo exposes a toggle between them.

**RPC mode (default).** Direct authenticated HTTPS calls to Keycast's `/api/nostr` endpoint via `KeycastRpc`. This is what the demo signs with — lower latency and no relay round-trips.

**NIP-46 bunker mode.** Every session also carries a `bunkerUrl` (`bunker://<pubkey>?relay=wss://...&secret=...`) for NIP-46 remote signing over Nostr relays. Feed it to a NIP-46 client (for example `nostr_sdk`'s `NostrRemoteSigner`) if you already have one. The demo surfaces the bunker URL but performs its actual signing over RPC.

Both transports support the same operations: `sign_event`, `get_public_key`, `nip44_encrypt`, `nip44_decrypt`, `nip04_encrypt`, `nip04_decrypt`.

## Running the demo app

```bash
flutter pub get

# iOS simulator or device — OAuth callbacks work correctly here.
flutter run -d "iPhone 15 Pro"

# macOS — builds and runs, but the HTTPS OAuth callback is unreliable (see Troubleshooting).
flutter run -d macos
```

The demo's OAuth configuration (`clientId: divine-flutter-demo`, callback `https://login.divine.video/app/callback`) is registered against the Keycast server's deep-link configuration. Building with a different Apple Developer Team ID or Android signing key will break the Universal Link / App Link verification until the server is updated to include your app identifiers.

The UI walks through three steps: **Connect** (server-generated key or BYOK), **Sign** an event, and **Encrypt/decrypt** a message.

## Configuration

The Keycast server at `login.divine.video` must recognize each app for iOS Universal Links and Android App Links. Server-side deep-link configuration lives in the Keycast server repository.

### iOS (Universal Links)

- AASA file: `https://login.divine.video/.well-known/apple-app-site-association`
- App IDs: `GZCZBKH7MY.co.openvine.keycastFlutterDemo`, `GZCZBKH7MY.co.openvine.divine`
- Callback path: `/app/callback`

Add the associated domain to `ios/Runner/Runner.entitlements`:

```xml
<key>com.apple.developer.associated-domains</key>
<array>
    <string>applinks:login.divine.video</string>
</array>
```

macOS uses the same AASA configuration and requires macOS 14.4+ with a matching Apple Developer signing certificate.

### Android (App Links)

- Asset Links file: `https://login.divine.video/.well-known/assetlinks.json`
- Package names: `co.openvine.keycast_flutter_demo`, `co.openvine.divine`

Declare the callback intent filter inside your `<activity>` in `android/app/src/main/AndroidManifest.xml`:

```xml
<intent-filter android:autoVerify="true">
    <action android:name="android.intent.action.VIEW"/>
    <category android:name="android.intent.category.DEFAULT"/>
    <category android:name="android.intent.category.BROWSABLE"/>
    <data android:scheme="https" android:host="login.divine.video" android:pathPrefix="/app/callback"/>
</intent-filter>
```

To register a new Android app, add its package name and SHA256 signing fingerprint to `assetlinks.json`:

```bash
# Debug keystore
keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android | grep SHA256
```

## API reference

```dart
class KeycastOAuth {
  KeycastOAuth({
    required OAuthConfig config,
    http.Client? httpClient,
    KeycastStorage? storage,        // defaults to MemoryKeycastStorage
  });

  Future<KeycastSession?> getSession();          // null if missing or expired
  Future<String?> getAuthorizationHandle();
  Future<void> logout();                          // clears storage + server logout

  /// Returns (url, verifier). Reuses a stored handle for silent re-auth.
  Future<(String url, String verifier)> getAuthorizationUrl({
    String? nsec,                   // set to enable BYOK
    String scope = 'policy:social',
    bool defaultRegister = true,
    String? authorizationHandle,
  });

  CallbackResult parseCallback(String url);        // CallbackSuccess | CallbackError
  Future<TokenResponse> exchangeCode({             // auto-saves the session
    required String code,
    required String verifier,
  });
  void close();
}

class KeycastRpc implements NostrSigner {
  KeycastRpc({required String nostrApi, required String accessToken, http.Client? httpClient});
  factory KeycastRpc.fromSession(OAuthConfig config, KeycastSession session);

  Future<String?> getPublicKey();
  Future<Event?> signEvent(Event event);
  Future<String?> nip44Encrypt(String pubkey, String plaintext);
  Future<String?> nip44Decrypt(String pubkey, String ciphertext);
  Future<String?> encrypt(String pubkey, String plaintext);   // NIP-04
  Future<String?> decrypt(String pubkey, String ciphertext);  // NIP-04
}

class KeycastSession {
  final String bunkerUrl;
  final String? accessToken;
  final DateTime? expiresAt;
  final String? scope;
  final String? userPubkey;
  final String? authorizationHandle;

  bool get isExpired;
  bool get hasRpcAccess;

  factory KeycastSession.fromTokenResponse(TokenResponse response);
  KeycastSession copyWith({...});

  Future<void> save([FlutterSecureStorage? storage]);
  static Future<KeycastSession?> load([FlutterSecureStorage? storage]);
  static Future<void> clear([FlutterSecureStorage? storage]);
}
```

`KeyUtils` provides key helpers (`parseNsec`, `derivePublicKey`, `derivePublicKeyFromNsec`, `generatePrivateKey`, `encodeToNsec`, `encodeToPubkey`). Storage is pluggable through the `KeycastStorage` interface, with `SecureKeycastStorage` (backed by `flutter_secure_storage`) and `MemoryKeycastStorage` implementations. Typed errors are `SessionExpiredException`, `OAuthException`, `RpcException`, and `InvalidKeyException`, all extending `KeycastException`.

## Testing

The library ships with unit tests that mock all HTTP with `mocktail`, so no network is required:

```bash
cd packages/keycast_flutter
flutter test
```

| Test file | Coverage |
|-----------|----------|
| `pkce_test.dart` | PKCE verifier/challenge generation, BYOK embedding |
| `oauth_client_test.dart` | URL building, token exchange, callback parsing |
| `rpc_client_test.dart` | RPC methods and error handling |
| `session_test.dart` | Persistence, expiry, factory methods |
| `key_utils_test.dart` | nsec parsing, pubkey derivation |
| `exceptions_test.dart` | Typed exception behavior |

## Troubleshooting

**"User canceled login" / OAuth fails immediately.** `ASWebAuthenticationSession` can't match the callback URL.

- Universal Links require Apple Developer Team membership. The AASA file at `login.divine.video` is configured for Team ID `GZCZBKH7MY`; building with a different Team ID breaks the match.
- macOS HTTPS callbacks are unreliable. On iOS 17.4+ the completion handler fires correctly; on macOS 14.4+ it often does not, and the redirect is routed to the Universal Links handler instead. This is [known Apple platform behavior](https://stackoverflow.com/questions/61748589/does-aswebauthenticationsession-support-universal-links). Use iOS for testing, or contact the Keycast maintainers to have your app's bundle ID added to the AASA.

**Universal Links not working in the simulator.** Delete and reinstall the app; iOS caches AASA files, so wait a few minutes after a server deploy; confirm entitlements made it into the build with `codesign -d --entitlements - Runner.app`.

**"Invalid redirect_uri".** `redirectUri` must match the server registration exactly — no trailing slash: `https://login.divine.video/app/callback`.

**Token exchange fails.** Verify the stored `verifier` matches the one used to build the URL, that the authorization `code` hasn't expired (single-use, typically ~10 minutes), and that it isn't being reused.

## License

MIT

---

Part of [Divine](https://divine.video) — your playground for human creativity · [Brand guidelines](https://github.com/divinevideo/brand-guidelines)
