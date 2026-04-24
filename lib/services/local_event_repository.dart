import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../crypto_utils.dart';
import '../models/campus_event.dart';
import '../models/custodian_access.dart';

class LocalEventRepository {
  LocalEventRepository({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const String _storageKey = 'campus_event_feed_v3';

  final FlutterSecureStorage _storage;

  Future<List<CampusEvent>> fetchEvents() async {
    final raw = await _storage.read(key: _storageKey);
    if (raw == null || raw.isEmpty) {
      final seededEvents = _buildSeededEvents();
      await _persist(seededEvents);
      return seededEvents;
    }

    final decodedJson = (jsonDecode(raw) as List<dynamic>)
        .map((value) => Map<String, dynamic>.from(value as Map))
        .toList();
    final decoded = <CampusEvent>[];
    var migratedLegacyRsaPayloads = false;

    for (final item in decodedJson) {
      final encryptionMode = item['encryptionMode'] as String? ?? 'public';
      if (encryptionMode == 'rsaEnvelope') {
        decoded.add(_withIntegrityFlag(_migrateLegacyRsaEvent(item)));
        migratedLegacyRsaPayloads = true;
        continue;
      }

      decoded.add(_withIntegrityFlag(CampusEvent.fromJson(item)));
    }

    decoded.sort(_sortByDate);
    if (migratedLegacyRsaPayloads) {
      await _persist(decoded);
    }
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
      durationMinutes: draft.durationMinutes,
      capacity: draft.capacity,
      baseAttendeeCount: draft.baseAttendeeCount,
      baseWaitlistCount: draft.baseWaitlistCount,
      status: draft.status,
      reactionCounts: draft.reactionCounts,
      poll: draft.poll,
      volunteerSlots: draft.volunteerSlots,
      iv: iv,
    );

    return unsignedEvent.copyWith(
      signature: CryptoUtils.signPayload(unsignedEvent.canonicalPayload()),
      integrityVerified: true,
    );
  }

  List<CampusEvent> _buildSeededEvents() {
    const demoAccess = CustodianAccessSnapshot(
      aesPassphrase: DemoCustodianKeys.adminAesPassphrase,
    );
    final now = DateTime.now().toUtc();

    final drafts = <EventDraft>[
      EventDraft(
        id: 'lecture-cryptography-101',
        title: 'Cryptography 101 Lecture',
        organizer: 'School of Computer Engineering',
        category: 'Lecture',
        location: 'Innovation Hall',
        startsAt: _seedTime(now, 0, now.hour + 3, 0),
        summary:
            'Open lecture on zero-trust routing, key custody, and lightweight campus systems.',
        details:
            'Speakers arrive 30 minutes early. The session closes with a live encrypted publishing demo and audience Q&A.',
        encryptionMode: EventEncryptionMode.public,
        durationMinutes: 90,
        capacity: 160,
        baseAttendeeCount: 74,
        status: EventStatus.scheduled,
        reactionCounts: const <String, int>{'clap': 18, 'fire': 7, 'star': 23},
        poll: const EventPoll(
          question: 'Which demo should close the lecture?',
          options: <EventPollOption>[
            EventPollOption(
              id: 'lecture-live-publish',
              label: 'Live encrypted publishing',
              votes: 18,
            ),
            EventPollOption(
              id: 'lecture-key-custody',
              label: 'Key custody walkthrough',
              votes: 9,
            ),
            EventPollOption(
              id: 'lecture-threat-model',
              label: 'Threat model teardown',
              votes: 12,
            ),
          ],
        ),
      ),
      EventDraft(
        id: 'ops-night-volunteers',
        title: 'Ops Night Volunteer Grid',
        organizer: 'Campus Events Cell',
        category: 'Operations',
        location: 'Media Lab 2',
        startsAt: _seedTime(now, 0, now.hour + 8, 30),
        summary:
            'Volunteer check-in remains public, but desk assignments and fallback contacts stay encrypted.',
        details:
            'Desk A: Nisha, Desk B: Farhan, Stage backup: Arnav. Use service gate 3 for late load-in.',
        encryptionMode: EventEncryptionMode.aes,
        durationMinutes: 180,
        capacity: 24,
        baseAttendeeCount: 16,
        status: EventStatus.scheduled,
        reactionCounts: const <String, int>{'clap': 4, 'fire': 6, 'star': 3},
        volunteerSlots: const <VolunteerSlot>[
          VolunteerSlot(
            id: 'ops-checkin-desk',
            label: 'Check-in desk',
            capacity: 4,
            filled: 2,
          ),
          VolunteerSlot(
            id: 'ops-stage-runner',
            label: 'Stage runner',
            capacity: 3,
            filled: 1,
          ),
          VolunteerSlot(
            id: 'ops-tech-fallback',
            label: 'Tech fallback',
            capacity: 2,
            filled: 1,
          ),
        ],
      ),
      EventDraft(
        id: 'hack-grid-open',
        title: 'Campus Hack Grid',
        organizer: 'MIT Builders Circle',
        category: 'Hackathon',
        location: 'Knowledge Park',
        startsAt: _seedTime(now, 1, 9, 0),
        summary:
            'Public registration remains open. Judges, tracks, and kickoff milestones are visible to all.',
        details:
            'Check-in begins at 08:15. Teams present prototypes the next day at 16:00 in Arena Bay.',
        encryptionMode: EventEncryptionMode.public,
        durationMinutes: 540,
        capacity: 320,
        baseAttendeeCount: 281,
        status: EventStatus.scheduled,
        reactionCounts: const <String, int>{'clap': 31, 'fire': 24, 'star': 27},
        poll: const EventPoll(
          question: 'Which hackathon track are you leaning toward?',
          options: <EventPollOption>[
            EventPollOption(
              id: 'hack-ai',
              label: 'AI for campus life',
              votes: 35,
            ),
            EventPollOption(
              id: 'hack-mobility',
              label: 'Mobility and routing',
              votes: 17,
            ),
            EventPollOption(
              id: 'hack-sustainability',
              label: 'Sustainability systems',
              votes: 22,
            ),
          ],
        ),
        volunteerSlots: const <VolunteerSlot>[
          VolunteerSlot(
            id: 'hack-mentor-host',
            label: 'Mentor hospitality',
            capacity: 3,
            filled: 2,
          ),
          VolunteerSlot(
            id: 'hack-stage-support',
            label: 'Demo stage support',
            capacity: 4,
            filled: 2,
          ),
        ],
      ),
      EventDraft(
        id: 'rsa-admin-briefing',
        title: 'Admin Briefing Capsule',
        organizer: 'Student Affairs Core',
        category: 'Private Brief',
        location: 'Dean Conference Pod',
        startsAt: _seedTime(now, 1, 16, 30),
        summary:
            'Private policy briefing for approved admins. Payload requires admin mode to unlock.',
        details:
            'Agenda: audit the key-custodian rollout, confirm the emergency override chain, and approve moderation policy.',
        encryptionMode: EventEncryptionMode.aes,
        durationMinutes: 70,
        capacity: 18,
        baseAttendeeCount: 9,
        status: EventStatus.scheduled,
        reactionCounts: const <String, int>{'clap': 2, 'fire': 1, 'star': 2},
      ),
      EventDraft(
        id: 'culture-late-show',
        title: 'Culture Night Showcase',
        organizer: 'Student Council',
        category: 'Showcase',
        location: 'Open Air Theatre',
        startsAt: _seedTime(now, 2, 19, 0),
        summary:
            'Public lineup, stage opening, and audience entry gates are readable without credentials.',
        details:
            'Gate entry begins at 18:15. The final set starts at 20:10, with a combined music and projection sequence.',
        encryptionMode: EventEncryptionMode.public,
        durationMinutes: 220,
        capacity: 500,
        baseAttendeeCount: 500,
        baseWaitlistCount: 18,
        status: EventStatus.scheduled,
        reactionCounts: const <String, int>{'clap': 52, 'fire': 40, 'star': 48},
        volunteerSlots: const <VolunteerSlot>[
          VolunteerSlot(
            id: 'culture-backstage',
            label: 'Backstage coordination',
            capacity: 5,
            filled: 5,
          ),
          VolunteerSlot(
            id: 'culture-audience-flow',
            label: 'Audience flow support',
            capacity: 6,
            filled: 4,
          ),
        ],
      ),
      EventDraft(
        id: 'sponsor-room-aes',
        title: 'Sponsor Room Routing',
        organizer: 'Innovation Office',
        category: 'Logistics',
        location: 'Block 5 War Room',
        startsAt: _seedTime(now, 3, 13, 30),
        summary:
            'Sponsor hospitality remains partially redacted for general users and unlocks with the AES route.',
        details:
            'Reserve cab slots for the 14:20 airport pickup. Backup host desk is moved to Studio Corridor C.',
        encryptionMode: EventEncryptionMode.aes,
        durationMinutes: 95,
        capacity: 40,
        baseAttendeeCount: 22,
        status: EventStatus.moved,
        reactionCounts: const <String, int>{'clap': 3, 'fire': 5, 'star': 4},
      ),
    ];

    final events = drafts
        .map((draft) => _sealDraft(draft, demoAccess))
        .map(_withIntegrityFlag)
        .toList();

    events.sort(_sortByDate);
    return events;
  }

  CampusEvent _migrateLegacyRsaEvent(Map<String, dynamic> json) {
    final decryptedDetails = CryptoUtils.decryptLegacyRsaPayload(
      cipherText: json['payload'] as String? ?? '',
      ivBase64: json['iv'] as String? ?? '',
      wrappedKey: json['wrappedKey'] as String? ?? '',
    );
    final migratedDetails =
        decryptedDetails ?? (json['summary'] as String? ?? '').trim();
    final sealed = CryptoUtils.encryptWithAesPassphrase(
      migratedDetails,
      DemoCustodianKeys.adminAesPassphrase,
    );
    final updatedAtValue = json['updatedAt'] as String?;
    final unsignedEvent = CampusEvent(
      id: json['id'] as String,
      title: json['title'] as String,
      organizer: json['organizer'] as String,
      category: json['category'] as String,
      location: json['location'] as String,
      startsAt: DateTime.parse(json['startsAt'] as String),
      summary: json['summary'] as String,
      payload: sealed.cipherText,
      encryptionMode: EventEncryptionMode.aes,
      signature: '',
      updatedAt: updatedAtValue == null
          ? DateTime.now().toUtc()
          : DateTime.parse(updatedAtValue),
      iv: sealed.iv,
    );

    return unsignedEvent.copyWith(
      signature: CryptoUtils.signPayload(unsignedEvent.canonicalPayload()),
      integrityVerified: true,
    );
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

  static DateTime _seedTime(
    DateTime anchor,
    int dayOffset,
    int hour,
    int minute,
  ) {
    final targetDay = anchor.add(Duration(days: dayOffset));
    final normalizedHour = hour % 24;
    final extraDays = hour ~/ 24;
    return DateTime.utc(
      targetDay.year,
      targetDay.month,
      targetDay.day + extraDays,
      normalizedHour,
      minute,
    );
  }
}
