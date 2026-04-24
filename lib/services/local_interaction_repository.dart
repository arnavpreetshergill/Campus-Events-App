import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class LocalInteractionRepository {
  LocalInteractionRepository({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const String _storageKey = 'campus_event_interactions_v1';

  final FlutterSecureStorage _storage;

  Future<Map<String, dynamic>> loadState() async {
    final raw = await _storage.read(key: _storageKey);
    if (raw == null || raw.isEmpty) {
      return <String, dynamic>{};
    }

    return Map<String, dynamic>.from(jsonDecode(raw) as Map);
  }

  Future<void> saveState(Map<String, dynamic> state) async {
    await _storage.write(key: _storageKey, value: jsonEncode(state));
  }

  Future<void> clear() async {
    await _storage.delete(key: _storageKey);
  }
}
