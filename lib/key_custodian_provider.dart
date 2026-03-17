import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'crypto_utils.dart';
import 'models/campus_event.dart';
import 'models/custodian_access.dart';

class UnlockAttemptResult {
  const UnlockAttemptResult({
    required this.aesAccepted,
    required this.rsaAccepted,
    required this.invalidInputs,
    required this.message,
  });

  final bool aesAccepted;
  final bool rsaAccepted;
  final List<String> invalidInputs;
  final String message;
}

class KeyCustodianProvider extends ChangeNotifier {
  KeyCustodianProvider({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage() {
    _loadSecrets();
  }

  static const String _aesStorageKey = 'custodian_aes_secret';
  static const String _rsaStorageKey = 'custodian_rsa_secret';

  final FlutterSecureStorage _storage;

  String? _aesPassphrase;
  String? _rsaPrivateKeyPem;
  bool _initialized = false;

  bool get isReady => _initialized;
  bool get hasAesAccess => snapshot.hasAesAccess;
  bool get hasRsaAccess => snapshot.hasRsaAccess;
  bool get isAdmin => snapshot.isAdmin;
  String get modeLabel => snapshot.modeLabel;

  CustodianAccessSnapshot get snapshot => CustodianAccessSnapshot(
    aesPassphrase: _aesPassphrase,
    rsaPrivateKeyPem: _rsaPrivateKeyPem,
  );

  Future<void> _loadSecrets() async {
    final storedAes = await _storage.read(key: _aesStorageKey);
    final storedRsa = await _storage.read(key: _rsaStorageKey);

    if (storedAes != null && CryptoUtils.isValidDemoAesPassphrase(storedAes)) {
      _aesPassphrase = DemoCustodianKeys.adminAesPassphrase;
    }

    if (storedRsa != null && CryptoUtils.isValidDemoRsaPrivateKey(storedRsa)) {
      _rsaPrivateKeyPem = DemoCustodianKeys.rsaPrivateKeyPem;
    }

    _initialized = true;
    notifyListeners();
  }

  bool canReadEvent(CampusEvent event) {
    switch (event.encryptionMode) {
      case EventEncryptionMode.public:
        return true;
      case EventEncryptionMode.aes:
        return hasAesAccess;
      case EventEncryptionMode.rsaEnvelope:
        return hasRsaAccess;
    }
  }

  String? revealDetails(CampusEvent event) {
    return CryptoUtils.tryDecryptEvent(event, snapshot);
  }

  Future<UnlockAttemptResult> storeSecrets({
    required String aesPassphrase,
    required String rsaPrivateKeyPem,
  }) async {
    final invalidInputs = <String>[];
    var aesAccepted = false;
    var rsaAccepted = false;

    final normalizedAes = aesPassphrase.trim();
    final normalizedRsa = CryptoUtils.normalizePem(rsaPrivateKeyPem);

    if (normalizedAes.isNotEmpty) {
      if (CryptoUtils.isValidDemoAesPassphrase(normalizedAes)) {
        _aesPassphrase = DemoCustodianKeys.adminAesPassphrase;
        await _storage.write(key: _aesStorageKey, value: _aesPassphrase);
        aesAccepted = true;
      } else {
        invalidInputs.add('AES passphrase');
      }
    }

    if (normalizedRsa.isNotEmpty) {
      if (CryptoUtils.isValidDemoRsaPrivateKey(normalizedRsa)) {
        _rsaPrivateKeyPem = DemoCustodianKeys.rsaPrivateKeyPem;
        await _storage.write(key: _rsaStorageKey, value: _rsaPrivateKeyPem);
        rsaAccepted = true;
      } else {
        invalidInputs.add('RSA private key');
      }
    }

    if (aesAccepted || rsaAccepted) {
      notifyListeners();
    }

    if (aesAccepted || rsaAccepted) {
      final warning = invalidInputs.isEmpty
          ? ''
          : ' Ignored invalid input for ${invalidInputs.join(' and ')}.';

      return UnlockAttemptResult(
        aesAccepted: aesAccepted,
        rsaAccepted: rsaAccepted,
        invalidInputs: invalidInputs,
        message: 'Admin access saved.$warning',
      );
    }

    return UnlockAttemptResult(
      aesAccepted: false,
      rsaAccepted: false,
      invalidInputs: invalidInputs,
      message: invalidInputs.isEmpty
          ? 'Enter a valid passphrase or private key.'
          : 'No valid access credential was detected.',
    );
  }

  Future<void> clearAllSecrets() async {
    await _storage.delete(key: _aesStorageKey);
    await _storage.delete(key: _rsaStorageKey);
    _aesPassphrase = null;
    _rsaPrivateKeyPem = null;
    notifyListeners();
  }
}
