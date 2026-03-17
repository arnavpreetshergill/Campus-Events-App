import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../crypto_utils.dart';
import '../models/campus_event.dart';
import '../models/custodian_access.dart';

class LocalEventRepository {
  LocalEventRepository({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const String _storageKey = 'campus_event_feed_v2';

  final FlutterSecureStorage _storage;

  Future<List<CampusEvent>> fetchEvents() async {
    final raw = await _storage.read(key: _storageKey);
    if (raw == null || raw.isEmpty) {
      final seededEvents = _buildSeededEvents();
      await _persist(seededEvents);
      return seededEvents;
    }

    final decoded = (jsonDecode(raw) as List<dynamic>)
        .map(
          (value) =>
              CampusEvent.fromJson(Map<String, dynamic>.from(value as Map)),
        )
        .map(_withIntegrityFlag)
        .toList();

    decoded.sort(_sortByDate);
    return decoded;
  }

  Future<List<CampusEvent>> resetDemoFeed() async {
    final seededEvents = _buildSeededEvents();
    await _persist(seededEvents);
    return seededEvents;
  }

  Future<List<CampusEvent>> upsertEvent(
    EventDraft draft,
    CustodianAccessSnapshot access,
  ) async {
    if (!access.isAdmin) {
      throw StateError('Administrative access is required.');
    }

    final event = _sealDraft(draft, access);
    if (!CryptoUtils.verifySignature(
      event.canonicalPayload(),
      event.signature,
    )) {
      throw StateError('Backend signature validation failed.');
    }

    final current = await fetchEvents();
    final index = current.indexWhere((item) => item.id == event.id);

    if (index == -1) {
      current.add(event);
    } else {
      current[index] = event;
    }

    current.sort(_sortByDate);
    await _persist(current);
    return current;
  }

  CampusEvent _sealDraft(EventDraft draft, CustodianAccessSnapshot access) {
    var payload = draft.details.trim();
    var iv = '';
    String? wrappedKey;

    switch (draft.encryptionMode) {
      case EventEncryptionMode.public:
        break;
      case EventEncryptionMode.aes:
        if (!access.hasAesAccess) {
          throw StateError('AES passphrase required for this route.');
        }
        final sealed = CryptoUtils.encryptWithAesPassphrase(
          payload,
          access.aesPassphrase!,
        );
        payload = sealed.cipherText;
        iv = sealed.iv;
        break;
      case EventEncryptionMode.rsaEnvelope:
        if (!access.hasRsaAccess) {
          throw StateError('RSA private key required for this route.');
        }
        final sealed = CryptoUtils.encryptWithRsaEnvelope(payload);
        payload = sealed.cipherText;
        iv = sealed.iv;
        wrappedKey = sealed.wrappedKey;
        break;
    }

    final unsignedEvent = CampusEvent(
      id: draft.id ?? _buildEventId(draft.title, draft.startsAt),
      title: draft.title.trim(),
      organizer: draft.organizer.trim(),
      category: draft.category.trim(),
      location: draft.location.trim(),
      startsAt: draft.startsAt,
      summary: draft.summary.trim(),
      payload: payload,
      encryptionMode: draft.encryptionMode,
      signature: '',
      updatedAt: DateTime.now().toUtc(),
      iv: iv,
      wrappedKey: wrappedKey,
    );

    return unsignedEvent.copyWith(
      signature: CryptoUtils.signPayload(unsignedEvent.canonicalPayload()),
      integrityVerified: true,
    );
  }

  List<CampusEvent> _buildSeededEvents() {
    const demoAccess = CustodianAccessSnapshot(
      aesPassphrase: DemoCustodianKeys.adminAesPassphrase,
      rsaPrivateKeyPem: DemoCustodianKeys.rsaPrivateKeyPem,
    );

    final drafts = <EventDraft>[
      EventDraft(
        id: 'lecture-cryptography-101',
        title: 'Cryptography 101 Lecture',
        organizer: 'School of Computer Engineering',
        category: 'Lecture',
        location: 'Innovation Hall',
        startsAt: DateTime.utc(2026, 3, 19, 11, 0),
        summary:
            'Open lecture on zero-trust routing, key custody, and lightweight campus systems.',
        details:
            'Speakers arrive at 10:30. Audience Q&A opens after the live demo of encrypted event publishing.',
        encryptionMode: EventEncryptionMode.public,
      ),
      EventDraft(
        id: 'ops-night-volunteers',
        title: 'Ops Night Volunteer Grid',
        organizer: 'Campus Events Cell',
        category: 'Operations',
        location: 'Media Lab 2',
        startsAt: DateTime.utc(2026, 3, 19, 18, 30),
        summary:
            'Volunteer check-in remains public, but desk assignments and fallback contacts stay encrypted.',
        details:
            'Desk A: Nisha, Desk B: Farhan, Stage backup: Arnav. Use service gate 3 for late load-in.',
        encryptionMode: EventEncryptionMode.aes,
      ),
      EventDraft(
        id: 'hack-grid-open',
        title: 'Campus Hack Grid',
        organizer: 'MIT Builders Circle',
        category: 'Hackathon',
        location: 'Knowledge Park',
        startsAt: DateTime.utc(2026, 3, 20, 9, 0),
        summary:
            'Public registration remains open. Judges, tracks, and kickoff milestones are visible to all.',
        details:
            'Check-in begins at 08:15. Teams present their prototypes on March 21 at 16:00 in Arena Bay.',
        encryptionMode: EventEncryptionMode.public,
      ),
      EventDraft(
        id: 'rsa-admin-briefing',
        title: 'Admin Briefing Capsule',
        organizer: 'Student Affairs Core',
        category: 'Private Brief',
        location: 'Dean Conference Pod',
        startsAt: DateTime.utc(2026, 3, 20, 15, 45),
        summary:
            'Private policy briefing for approved custodians. Payload requires the RSA route to unlock.',
        details:
            'Agenda: audit the key-custodian rollout, confirm emergency override chain, and approve event moderation policy.',
        encryptionMode: EventEncryptionMode.rsaEnvelope,
      ),
      EventDraft(
        id: 'culture-late-show',
        title: 'Culture Night Showcase',
        organizer: 'Student Council',
        category: 'Showcase',
        location: 'Open Air Theatre',
        startsAt: DateTime.utc(2026, 3, 21, 19, 0),
        summary:
            'Public lineup, stage opening, and audience entry gates are readable without credentials.',
        details:
            'Gate entry begins at 18:15. The final set starts at 20:10, with a combined music and projection sequence.',
        encryptionMode: EventEncryptionMode.public,
      ),
      EventDraft(
        id: 'sponsor-room-aes',
        title: 'Sponsor Room Routing',
        organizer: 'Innovation Office',
        category: 'Logistics',
        location: 'Block 5 War Room',
        startsAt: DateTime.utc(2026, 3, 22, 13, 30),
        summary:
            'Sponsor hospitality remains partially redacted for general users and unlocks with the AES route.',
        details:
            'Reserve cab slots for the 14:20 airport pickup. Backup host desk is moved to Studio Corridor C.',
        encryptionMode: EventEncryptionMode.aes,
      ),
    ];

    final events = drafts
        .map((draft) => _sealDraft(draft, demoAccess))
        .map(_withIntegrityFlag)
        .toList();

    events.sort(_sortByDate);
    return events;
  }

  CampusEvent _withIntegrityFlag(CampusEvent event) {
    return event.copyWith(
      integrityVerified: CryptoUtils.verifySignature(
        event.canonicalPayload(),
        event.signature,
      ),
    );
  }

  Future<void> _persist(List<CampusEvent> events) async {
    final encoded = jsonEncode(events.map((event) => event.toJson()).toList());
    await _storage.write(key: _storageKey, value: encoded);
  }

  static int _sortByDate(CampusEvent left, CampusEvent right) {
    return left.startsAt.compareTo(right.startsAt);
  }

  static String _buildEventId(String title, DateTime startsAt) {
    final slug = title
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'-+'), '-')
        .replaceAll(RegExp(r'^-|-$'), '');
    return '$slug-${startsAt.millisecondsSinceEpoch}';
  }
}
