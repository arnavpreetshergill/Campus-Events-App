import 'dart:convert';

enum EventEncryptionMode { public, aes, rsaEnvelope }

extension EventEncryptionModeX on EventEncryptionMode {
  String get storageValue {
    switch (this) {
      case EventEncryptionMode.public:
        return 'public';
      case EventEncryptionMode.aes:
        return 'aes';
      case EventEncryptionMode.rsaEnvelope:
        return 'rsaEnvelope';
    }
  }

  String get label {
    switch (this) {
      case EventEncryptionMode.public:
        return 'Open';
      case EventEncryptionMode.aes:
        return 'Private';
      case EventEncryptionMode.rsaEnvelope:
        return 'Restricted';
    }
  }

  String get description {
    switch (this) {
      case EventEncryptionMode.public:
        return 'Visible to everyone';
      case EventEncryptionMode.aes:
        return 'Shared-access details';
      case EventEncryptionMode.rsaEnvelope:
        return 'Restricted admin details';
    }
  }

  static EventEncryptionMode fromStorage(String value) {
    return EventEncryptionMode.values.firstWhere(
      (mode) => mode.storageValue == value,
      orElse: () => EventEncryptionMode.public,
    );
  }
}

class CampusEvent {
  const CampusEvent({
    required this.id,
    required this.title,
    required this.organizer,
    required this.category,
    required this.location,
    required this.startsAt,
    required this.summary,
    required this.payload,
    required this.encryptionMode,
    required this.signature,
    required this.updatedAt,
    this.iv = '',
    this.wrappedKey,
    this.integrityVerified = true,
  });

  final String id;
  final String title;
  final String organizer;
  final String category;
  final String location;
  final DateTime startsAt;
  final String summary;
  final String payload;
  final EventEncryptionMode encryptionMode;
  final String signature;
  final DateTime updatedAt;
  final String iv;
  final String? wrappedKey;
  final bool integrityVerified;

  bool get isEncrypted => encryptionMode != EventEncryptionMode.public;

  String get previewCipher {
    if (payload.length <= 68) {
      return payload;
    }
    return '${payload.substring(0, 68)}...';
  }

  String canonicalPayload() {
    return jsonEncode(<String, Object?>{
      'id': id,
      'title': title,
      'organizer': organizer,
      'category': category,
      'location': location,
      'startsAt': startsAt.toUtc().toIso8601String(),
      'summary': summary,
      'payload': payload,
      'encryptionMode': encryptionMode.storageValue,
      'iv': iv,
      'wrappedKey': wrappedKey,
      'updatedAt': updatedAt.toUtc().toIso8601String(),
    });
  }

  CampusEvent copyWith({
    String? id,
    String? title,
    String? organizer,
    String? category,
    String? location,
    DateTime? startsAt,
    String? summary,
    String? payload,
    EventEncryptionMode? encryptionMode,
    String? signature,
    DateTime? updatedAt,
    String? iv,
    String? wrappedKey,
    bool? integrityVerified,
  }) {
    return CampusEvent(
      id: id ?? this.id,
      title: title ?? this.title,
      organizer: organizer ?? this.organizer,
      category: category ?? this.category,
      location: location ?? this.location,
      startsAt: startsAt ?? this.startsAt,
      summary: summary ?? this.summary,
      payload: payload ?? this.payload,
      encryptionMode: encryptionMode ?? this.encryptionMode,
      signature: signature ?? this.signature,
      updatedAt: updatedAt ?? this.updatedAt,
      iv: iv ?? this.iv,
      wrappedKey: wrappedKey ?? this.wrappedKey,
      integrityVerified: integrityVerified ?? this.integrityVerified,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'title': title,
      'organizer': organizer,
      'category': category,
      'location': location,
      'startsAt': startsAt.toUtc().toIso8601String(),
      'summary': summary,
      'payload': payload,
      'encryptionMode': encryptionMode.storageValue,
      'signature': signature,
      'updatedAt': updatedAt.toUtc().toIso8601String(),
      'iv': iv,
      'wrappedKey': wrappedKey,
    };
  }

  factory CampusEvent.fromJson(Map<String, dynamic> json) {
    return CampusEvent(
      id: json['id'] as String,
      title: json['title'] as String,
      organizer: json['organizer'] as String,
      category: json['category'] as String,
      location: json['location'] as String,
      startsAt: DateTime.parse(json['startsAt'] as String),
      summary: json['summary'] as String,
      payload: json['payload'] as String,
      encryptionMode: EventEncryptionModeX.fromStorage(
        json['encryptionMode'] as String? ?? 'public',
      ),
      signature: json['signature'] as String? ?? '',
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      iv: json['iv'] as String? ?? '',
      wrappedKey: json['wrappedKey'] as String?,
    );
  }
}

class EventDraft {
  const EventDraft({
    this.id,
    required this.title,
    required this.organizer,
    required this.category,
    required this.location,
    required this.startsAt,
    required this.summary,
    required this.details,
    required this.encryptionMode,
  });

  final String? id;
  final String title;
  final String organizer;
  final String category;
  final String location;
  final DateTime startsAt;
  final String summary;
  final String details;
  final EventEncryptionMode encryptionMode;
}
