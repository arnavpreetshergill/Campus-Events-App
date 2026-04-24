import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'crypto_utils.dart';
import 'models/campus_event.dart';
import 'models/custodian_access.dart';

class UnlockAttemptResult {
  const UnlockAttemptResult({required this.accepted, required this.message});

  final bool accepted;
  final String message;
}

class KeyCustodianProvider extends ChangeNotifier {
  KeyCustodianProvider({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage() {
    _loadSecrets();
  }

  static const String _aesStorageKey = 'custodian_aes_secret';
  static const String _legacyRsaStorageKey = 'custodian_rsa_secret';

  final FlutterSecureStorage _storage;

  String? _aesPassphrase;
  bool _initialized = false;

  bool get isReady => _initialized;
  bool get hasAesAccess => snapshot.hasAesAccess;
  bool get isAdmin => snapshot.isAdmin;
  String get modeLabel => snapshot.modeLabel;

  CustodianAccessSnapshot get snapshot =>
      CustodianAccessSnapshot(aesPassphrase: _aesPassphrase);

  Future<void> _loadSecrets() async {
    final storedAes = await _storage.read(key: _aesStorageKey);

    if (storedAes != null && CryptoUtils.isValidDemoAesPassphrase(storedAes)) {
      _aesPassphrase = DemoCustodianKeys.adminAesPassphrase;
    }

    await _storage.delete(key: _legacyRsaStorageKey);

    _initialized = true;
    notifyListeners();
  }

  bool canReadEvent(CampusEvent event) {
    switch (event.encryptionMode) {
      case EventEncryptionMode.public:
        return true;
      case EventEncryptionMode.aes:
        return hasAesAccess;
    }
  }

  String? revealDetails(CampusEvent event) {
    return CryptoUtils.tryDecryptEvent(event, snapshot);
  }

  Future<UnlockAttemptResult> storePassphrase({
    required String aesPassphrase,
  }) async {
    final normalizedAes = aesPassphrase.trim();
    if (normalizedAes.isEmpty) {
      return const UnlockAttemptResult(
        accepted: false,
        message: 'Enter the admin passphrase first.',
      );
    }

    if (!CryptoUtils.isValidDemoAesPassphrase(normalizedAes)) {
      return const UnlockAttemptResult(
        accepted: false,
        message: 'That passphrase is not valid.',
      );
    }

    _aesPassphrase = DemoCustodianKeys.adminAesPassphrase;
    await _storage.write(key: _aesStorageKey, value: _aesPassphrase);
    notifyListeners();

    return const UnlockAttemptResult(
      accepted: true,
      message: 'Admin mode enabled on this device.',
    );
  }

  Future<void> clearAllSecrets() async {
    await _storage.delete(key: _aesStorageKey);
    await _storage.delete(key: _legacyRsaStorageKey);
    _aesPassphrase = null;
    notifyListeners();
  }
}
