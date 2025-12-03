// ABOUTME: NIP-19 bech32 encoding/decoding for Nostr identifiers
// ABOUTME: Handles npub, nsec, note encodings between hex and bech32 formats

import 'package:bech32/bech32.dart';
import 'dart:typed_data';

import 'hrps.dart';

class Nip19 {
  static const String _hexChars = '0123456789abcdef';

  static bool isKey(String hrp, String str) {
    return str.startsWith(hrp);
  }

  static bool isPubkey(String str) {
    return isKey(Hrps.PUBLIC_KEY, str);
  }

  static bool isPrivateKey(String str) {
    return isKey(Hrps.PRIVATE_KEY, str);
  }

  static bool isNoteId(String str) {
    return isKey(Hrps.NOTE_ID, str);
  }

  static String encodePubKey(String pubkey) {
    return _encodeKey(Hrps.PUBLIC_KEY, pubkey);
  }

  static String encodePrivateKey(String privateKey) {
    return _encodeKey(Hrps.PRIVATE_KEY, privateKey);
  }

  static String encodeNoteId(String id) {
    return _encodeKey(Hrps.NOTE_ID, id);
  }

  static String decode(String bech32String) {
    try {
      var decoder = Bech32Decoder();
      var bech32Result = decoder.convert(bech32String);
      var data = _convertBits(bech32Result.data, 5, 8, false);
      return _bytesToHex(Uint8List.fromList(data));
    } catch (e) {
      return "";
    }
  }

  static String _encodeKey(String hrp, String key) {
    var data = _hexToBytes(key);
    var converted = _convertBits(data.toList(), 8, 5, true);

    var encoder = Bech32Encoder();
    Bech32 input = Bech32(hrp, converted);
    return encoder.convert(input);
  }

  static Uint8List _hexToBytes(String hex) {
    final result = Uint8List(hex.length ~/ 2);
    for (var i = 0; i < result.length; i++) {
      result[i] = int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16);
    }
    return result;
  }

  static String _bytesToHex(Uint8List bytes) {
    final buffer = StringBuffer();
    for (var byte in bytes) {
      buffer.write(_hexChars[(byte >> 4) & 0x0F]);
      buffer.write(_hexChars[byte & 0x0F]);
    }
    return buffer.toString();
  }

  static List<int> _convertBits(List<int> data, int from, int to, bool pad) {
    var acc = 0;
    var bits = 0;
    var result = <int>[];
    var maxv = (1 << to) - 1;

    for (var v in data) {
      if (v < 0 || (v >> from) != 0) {
        throw Exception('Invalid value');
      }
      acc = (acc << from) | v;
      bits += from;
      while (bits >= to) {
        bits -= to;
        result.add((acc >> bits) & maxv);
      }
    }

    if (pad) {
      if (bits > 0) {
        result.add((acc << (to - bits)) & maxv);
      }
    } else if (bits >= from) {
      throw InvalidPadding('illegal zero padding');
    } else if (((acc << (to - bits)) & maxv) != 0) {
      throw InvalidPadding('non zero');
    }

    return result;
  }
}
