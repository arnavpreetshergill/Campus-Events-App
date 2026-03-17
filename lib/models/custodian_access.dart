enum CustodianKeyType { guest, aes, rsa, hybrid }

class CustodianAccessSnapshot {
  const CustodianAccessSnapshot({this.aesPassphrase, this.rsaPrivateKeyPem});

  final String? aesPassphrase;
  final String? rsaPrivateKeyPem;

  bool get hasAesAccess => aesPassphrase != null && aesPassphrase!.isNotEmpty;
  bool get hasRsaAccess =>
      rsaPrivateKeyPem != null && rsaPrivateKeyPem!.isNotEmpty;
  bool get isAdmin => hasAesAccess || hasRsaAccess;

  CustodianKeyType get keyType {
    if (hasAesAccess && hasRsaAccess) {
      return CustodianKeyType.hybrid;
    }
    if (hasAesAccess) {
      return CustodianKeyType.aes;
    }
    if (hasRsaAccess) {
      return CustodianKeyType.rsa;
    }
    return CustodianKeyType.guest;
  }

  String get modeLabel {
    switch (keyType) {
      case CustodianKeyType.guest:
        return 'Standard';
      case CustodianKeyType.aes:
        return 'Shared access';
      case CustodianKeyType.rsa:
        return 'Admin key';
      case CustodianKeyType.hybrid:
        return 'Full access';
    }
  }
}
