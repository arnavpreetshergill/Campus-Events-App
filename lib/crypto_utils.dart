import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as enc;
import 'package:pointycastle/asymmetric/api.dart';

import 'models/campus_event.dart';
import 'models/custodian_access.dart';

class DemoCustodianKeys {
  static const String adminAesPassphrase = 'MIT-ZEROTRUST-AES-2026';
  static const String backendSigningSecret = 'atl-campus-grid-integrity-node';

  static const String legacyRsaPrivateKeyPem = '''
-----BEGIN PRIVATE KEY-----
MIICdgIBADANBgkqhkiG9w0BAQEFAASCAmAwggJcAgEAAoGBANWUAi39L13/pGnM
lsD0XCmNaE0vN7e14JftCriU3DKnqbNnCdBiS63wwEcgLeBAFyDuyR9dG8sUrxyI
8LxGzqtTtI+LFo4Cj5i9JrmGe+461qTLyKXhajZJxKDhu3do7LuByLlPpfKWLZv1
nioGawiRNsq8zWfzz3IuakaY2dvXAgMBAAECgYBfoDBFpQmzPYXAtRB+fipRlHWx
sUVyJKXVgBV/xW6942HQ6H51Zb1auONuNRM1R5zTavZz631JNQ6eaRXYRp+7NnNC
JfmuhkTWA3JqyJ1tTiiQ/phS4QfvvB/JmHGeG50y5RmbgyhX+z93jSINY0Df2E+v
JgcCvyvwMJTg7I/jSQJBAPG1mznuZlirfLMOtSIU8vqtIGD7inwR4sqPvVnGpOFX
HiMswC/Fh1U/cMHY5khSrHK9zbm5qVnBGfJTtNt9+sMCQQDiNJ8jgOmf9+BloF5m
ynmlBG/uT1uu0JXWMWkDKRFngsh07j0mlAbkSDTPsA9OZzOMiPVsn521jt6NDwbp
yQFdAkBAZvkjKGhQu/CP7R1KJXbQYAy+iodNo55gBoiXQRxxhjrbeHMEx4bVqf+r
RtWk85JLSFNmZxe+eHsnXDJWQWztAkBz68WV2y1eZhff3KQkByT5lOGLfa2dU5VF
tAJ9tSEPK61whtpdl8REXmB6Al6FrktzfIhRByc58KJKJWZEjladAkEAijJrr/ld
Wp36z6uWeADyqyJ8KzK3ox3ExbKuOEkwFXJmM0O4p3O8asTAShOPIDU4wHKL4eHB
QP9x5nDYscBD6A==
-----END PRIVATE KEY-----
''';
}

class SealedPayload {
  const SealedPayload({required this.cipherText, required this.iv});

  final String cipherText;
  final String iv;
}

class CryptoUtils {
  static String normalizePem(String value) {
    return value.trim().replaceAll('\r\n', '\n');
  }

  static bool isValidDemoAesPassphrase(String candidate) {
    return candidate.trim() == DemoCustodianKeys.adminAesPassphrase;
  }

  static String signPayload(String canonicalPayload) {
    final signer = Hmac(
      sha256,
      utf8.encode(DemoCustodianKeys.backendSigningSecret),
    );
    return signer.convert(utf8.encode(canonicalPayload)).toString();
  }

  static bool verifySignature(String canonicalPayload, String signature) {
    return signPayload(canonicalPayload) == signature;
  }

  static SealedPayload encryptWithAesPassphrase(
    String plainText,
    String passphrase,
  ) {
    final key = _deriveAesKey(passphrase);
    final iv = enc.IV.fromSecureRandom(16);
    final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));
    final encrypted = encrypter.encrypt(plainText, iv: iv);
    return SealedPayload(cipherText: encrypted.base64, iv: iv.base64);
  }

  static String? decryptAesPayload({
    required String cipherText,
    required String ivBase64,
    required String passphrase,
  }) {
    try {
      final key = _deriveAesKey(passphrase);
      final iv = enc.IV(base64Decode(ivBase64));
      final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));
      return encrypter.decrypt64(cipherText, iv: iv);
    } catch (_) {
      return null;
    }
  }

  static String? decryptLegacyRsaPayload({
    required String cipherText,
    required String ivBase64,
    required String wrappedKey,
  }) {
    try {
      final parser = enc.RSAKeyParser();
      final privateKey =
          parser.parse(normalizePem(DemoCustodianKeys.legacyRsaPrivateKeyPem))
              as RSAPrivateKey;
      final rsaEncrypter = enc.Encrypter(
        enc.RSA(privateKey: privateKey, encoding: enc.RSAEncoding.OAEP),
      );

      final encodedSessionKey = rsaEncrypter.decrypt64(wrappedKey);
      final sessionKeyBytes = Uint8List.fromList(
        base64Decode(encodedSessionKey),
      );
      final aesKey = enc.Key(sessionKeyBytes);
      final iv = enc.IV(base64Decode(ivBase64));
      final aesEncrypter = enc.Encrypter(
        enc.AES(aesKey, mode: enc.AESMode.cbc),
      );
      return aesEncrypter.decrypt64(cipherText, iv: iv);
    } catch (_) {
      return null;
    }
  }

  static String? tryDecryptEvent(
    CampusEvent event,
    CustodianAccessSnapshot access,
  ) {
    switch (event.encryptionMode) {
      case EventEncryptionMode.public:
        return event.payload;
      case EventEncryptionMode.aes:
        if (!access.hasAesAccess || event.iv.isEmpty) {
          return null;
        }
        return decryptAesPayload(
          cipherText: event.payload,
          ivBase64: event.iv,
          passphrase: access.aesPassphrase!,
        );
    }
  }

  static enc.Key _deriveAesKey(String secret) {
    final digest = sha256.convert(utf8.encode(secret.trim())).bytes;
    return enc.Key(Uint8List.fromList(digest));
  }
}
