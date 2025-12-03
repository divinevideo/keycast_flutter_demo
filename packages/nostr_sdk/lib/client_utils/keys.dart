// ABOUTME: Nostr key generation and validation utilities
// ABOUTME: Provides private key generation, public key derivation, and key validation

import 'dart:math';
import 'dart:typed_data';

bool keyIsValid(String key) {
  if (key.length != 64) return false;
  return RegExp(r'^[0-9a-fA-F]+$').hasMatch(key);
}

String generatePrivateKey() => getRandomHexString();

String getRandomHexString([int byteLength = 32]) {
  final Random random = Random.secure();
  var bytes = List<int>.generate(byteLength, (i) => random.nextInt(256));
  return _bytesToHex(Uint8List.fromList(bytes));
}

String _bytesToHex(Uint8List bytes) {
  const hexChars = '0123456789abcdef';
  final buffer = StringBuffer();
  for (var byte in bytes) {
    buffer.write(hexChars[(byte >> 4) & 0x0F]);
    buffer.write(hexChars[byte & 0x0F]);
  }
  return buffer.toString();
}

Uint8List _hexToBytes(String hex) {
  final result = Uint8List(hex.length ~/ 2);
  for (var i = 0; i < result.length; i++) {
    result[i] = int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16);
  }
  return result;
}

String getPublicKey(String privateKey) {
  if (!keyIsValid(privateKey)) {
    throw ArgumentError.value(privateKey, 'privateKey', 'Invalid key');
  }
  return _derivePublicKey(privateKey);
}

String _derivePublicKey(String privateKeyHex) {
  final privateKeyBytes = _hexToBytes(privateKeyHex);
  final publicKeyBytes = _secp256k1GetPublicKey(privateKeyBytes);
  return _bytesToHex(publicKeyBytes);
}

Uint8List _secp256k1GetPublicKey(Uint8List privateKey) {
  final p = _secp256k1P;
  final n = _secp256k1N;
  final gx = _secp256k1Gx;
  final gy = _secp256k1Gy;

  BigInt d = _bytesToBigInt(privateKey);
  if (d <= BigInt.zero || d >= n) {
    throw ArgumentError('Invalid private key');
  }

  final point = _pointMultiply(gx, gy, d, p, n);
  final xBytes = _bigIntToBytes(point.$1, 32);
  return xBytes;
}

final BigInt _secp256k1P = BigInt.parse(
    'fffffffffffffffffffffffffffffffffffffffffffffffffffffffefffffc2f',
    radix: 16);
final BigInt _secp256k1N = BigInt.parse(
    'fffffffffffffffffffffffffffffffebaaedce6af48a03bbfd25e8cd0364141',
    radix: 16);
final BigInt _secp256k1Gx = BigInt.parse(
    '79be667ef9dcbbac55a06295ce870b07029bfcdb2dce28d959f2815b16f81798',
    radix: 16);
final BigInt _secp256k1Gy = BigInt.parse(
    '483ada7726a3c4655da4fbfc0e1108a8fd17b448a68554199c47d08ffb10d4b8',
    radix: 16);

BigInt _bytesToBigInt(Uint8List bytes) {
  BigInt result = BigInt.zero;
  for (var byte in bytes) {
    result = (result << 8) | BigInt.from(byte);
  }
  return result;
}

Uint8List _bigIntToBytes(BigInt n, int length) {
  final result = Uint8List(length);
  var value = n;
  for (var i = length - 1; i >= 0; i--) {
    result[i] = (value & BigInt.from(0xff)).toInt();
    value = value >> 8;
  }
  return result;
}

BigInt _modInverse(BigInt a, BigInt m) {
  if (a < BigInt.zero) {
    a = a % m + m;
  }
  BigInt g = a.gcd(m);
  if (g != BigInt.one) {
    throw ArgumentError('Modular inverse does not exist');
  }
  return a.modPow(m - BigInt.two, m);
}

(BigInt, BigInt) _pointAdd(
    BigInt x1, BigInt y1, BigInt x2, BigInt y2, BigInt p) {
  if (x1 == x2 && y1 == y2) {
    return _pointDouble(x1, y1, p);
  }

  BigInt s = ((y2 - y1) * _modInverse(x2 - x1, p)) % p;
  BigInt x3 = (s * s - x1 - x2) % p;
  BigInt y3 = (s * (x1 - x3) - y1) % p;

  if (x3 < BigInt.zero) x3 += p;
  if (y3 < BigInt.zero) y3 += p;

  return (x3, y3);
}

(BigInt, BigInt) _pointDouble(BigInt x, BigInt y, BigInt p) {
  BigInt s = ((BigInt.from(3) * x * x) * _modInverse(BigInt.two * y, p)) % p;
  BigInt x3 = (s * s - BigInt.two * x) % p;
  BigInt y3 = (s * (x - x3) - y) % p;

  if (x3 < BigInt.zero) x3 += p;
  if (y3 < BigInt.zero) y3 += p;

  return (x3, y3);
}

(BigInt, BigInt) _pointMultiply(
    BigInt x, BigInt y, BigInt k, BigInt p, BigInt n) {
  BigInt rx = BigInt.zero;
  BigInt ry = BigInt.zero;
  bool isZero = true;

  BigInt px = x;
  BigInt py = y;

  while (k > BigInt.zero) {
    if (k.isOdd) {
      if (isZero) {
        rx = px;
        ry = py;
        isZero = false;
      } else {
        final result = _pointAdd(rx, ry, px, py, p);
        rx = result.$1;
        ry = result.$2;
      }
    }
    final doubled = _pointDouble(px, py, p);
    px = doubled.$1;
    py = doubled.$2;
    k = k >> 1;
  }

  return (rx, ry);
}
