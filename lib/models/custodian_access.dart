enum CustodianKeyType { guest, admin }

class CustodianAccessSnapshot {
  const CustodianAccessSnapshot({this.aesPassphrase});

  final String? aesPassphrase;

  bool get hasAesAccess => aesPassphrase != null && aesPassphrase!.isNotEmpty;
  bool get isAdmin => hasAesAccess;

  CustodianKeyType get keyType {
    if (hasAesAccess) {
      return CustodianKeyType.admin;
    }
    return CustodianKeyType.guest;
  }

  String get modeLabel {
    switch (keyType) {
      case CustodianKeyType.guest:
        return 'Standard';
      case CustodianKeyType.admin:
        return 'Admin';
    }
  }
}
