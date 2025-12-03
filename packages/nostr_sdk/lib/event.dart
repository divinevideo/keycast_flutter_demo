// ABOUTME: Nostr Event model as defined in NIP-01
// ABOUTME: Handles event creation, JSON serialization, and ID computation

import 'dart:convert';
import 'package:crypto/crypto.dart';

import 'client_utils/keys.dart';

class Event {
  Event(this.pubkey, this.kind, this.tags, this.content, {int? createdAt}) {
    if (!keyIsValid(pubkey)) {
      throw ArgumentError.value(pubkey, 'pubkey', 'Invalid key');
    }
    if (createdAt != null) {
      this.createdAt = createdAt;
    } else {
      this.createdAt = _secondsSinceEpoch();
    }
    id = _getId(pubkey, this.createdAt, kind, tags, content);
  }

  Event._(this.id, this.pubkey, this.createdAt, this.kind, this.tags,
      this.content, this.sig);

  factory Event.fromJson(Map<String, dynamic> data) {
    final id = data['id'] as String;
    final pubkey = data['pubkey'] as String;
    final createdAt = data['created_at'] as int;
    final kind = data['kind'] as int;
    final tags = data['tags'];
    final content = data['content'] as String;
    final sig = data['sig'] == null ? "" : data['sig'] as String;

    return Event._(id, pubkey, createdAt, kind, tags, content, sig);
  }

  String id = '';
  final String pubkey;
  late int createdAt;
  final int kind;
  List<dynamic> tags;
  String content;
  String sig = '';

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'pubkey': pubkey,
      'created_at': createdAt,
      'kind': kind,
      'tags': tags,
      'content': content,
      'sig': sig
    };
  }

  bool get isValid {
    if (id != _getId(pubkey, createdAt, kind, tags, content)) {
      return false;
    }
    return true;
  }

  bool get isSigned => sig.isNotEmpty;

  @override
  bool operator ==(other) => other is Event && id == other.id;

  @override
  int get hashCode => id.hashCode;

  static int _secondsSinceEpoch() {
    final now = DateTime.now();
    final secondsSinceEpoch = now.millisecondsSinceEpoch ~/ 1000;
    return secondsSinceEpoch;
  }

  static String _getId(String publicKey, int createdAt, int kind,
      List<dynamic> tags, String content) {
    final jsonData =
        json.encode([0, publicKey, createdAt, kind, tags, content]);
    final bytes = utf8.encode(jsonData);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }
}
