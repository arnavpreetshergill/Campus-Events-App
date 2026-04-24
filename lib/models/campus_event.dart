import 'dart:convert';

enum EventEncryptionMode { public, aes }

extension EventEncryptionModeX on EventEncryptionMode {
  String get storageValue {
    switch (this) {
      case EventEncryptionMode.public:
        return 'public';
      case EventEncryptionMode.aes:
        return 'aes';
    }
  }

  String get label {
    switch (this) {
      case EventEncryptionMode.public:
        return 'Open';
      case EventEncryptionMode.aes:
        return 'Private';
    }
  }

  String get description {
    switch (this) {
      case EventEncryptionMode.public:
        return 'Visible to everyone';
      case EventEncryptionMode.aes:
        return 'Admin-only details';
    }
  }

  static EventEncryptionMode fromStorage(String value) {
    return EventEncryptionMode.values.firstWhere(
      (mode) => mode.storageValue == value,
      orElse: () => EventEncryptionMode.public,
    );
  }
}

enum EventStatus { scheduled, delayed, moved, live, completed }

extension EventStatusX on EventStatus {
  String get storageValue {
    switch (this) {
      case EventStatus.scheduled:
        return 'scheduled';
      case EventStatus.delayed:
        return 'delayed';
      case EventStatus.moved:
        return 'moved';
      case EventStatus.live:
        return 'live';
      case EventStatus.completed:
        return 'completed';
    }
  }

  String get label {
    switch (this) {
      case EventStatus.scheduled:
        return 'Scheduled';
      case EventStatus.delayed:
        return 'Delayed';
      case EventStatus.moved:
        return 'Venue moved';
      case EventStatus.live:
        return 'Live';
      case EventStatus.completed:
        return 'Completed';
    }
  }

  static EventStatus fromStorage(String value) {
    return EventStatus.values.firstWhere(
      (status) => status.storageValue == value,
      orElse: () => EventStatus.scheduled,
    );
  }
}

class EventPollOption {
  const EventPollOption({
    required this.id,
    required this.label,
    this.votes = 0,
  });

  final String id;
  final String label;
  final int votes;

  EventPollOption copyWith({String? id, String? label, int? votes}) {
    return EventPollOption(
      id: id ?? this.id,
      label: label ?? this.label,
      votes: votes ?? this.votes,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{'id': id, 'label': label, 'votes': votes};
  }

  factory EventPollOption.fromJson(Map<String, dynamic> json) {
    return EventPollOption(
      id: json['id'] as String,
      label: json['label'] as String,
      votes: (json['votes'] as num?)?.toInt() ?? 0,
    );
  }
}

class EventPoll {
  const EventPoll({required this.question, required this.options});

  final String question;
  final List<EventPollOption> options;

  EventPoll copyWith({String? question, List<EventPollOption>? options}) {
    return EventPoll(
      question: question ?? this.question,
      options: options ?? this.options,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'question': question,
      'options': options.map((option) => option.toJson()).toList(),
    };
  }

  factory EventPoll.fromJson(Map<String, dynamic> json) {
    final rawOptions = (json['options'] as List<dynamic>? ?? const <dynamic>[]);
    return EventPoll(
      question: json['question'] as String,
      options: rawOptions
          .map(
            (value) => EventPollOption.fromJson(
              Map<String, dynamic>.from(value as Map),
            ),
          )
          .toList(),
    );
  }
}

class VolunteerSlot {
  const VolunteerSlot({
    required this.id,
    required this.label,
    required this.capacity,
    this.filled = 0,
  });

  final String id;
  final String label;
  final int capacity;
  final int filled;

  VolunteerSlot copyWith({
    String? id,
    String? label,
    int? capacity,
    int? filled,
  }) {
    return VolunteerSlot(
      id: id ?? this.id,
      label: label ?? this.label,
      capacity: capacity ?? this.capacity,
      filled: filled ?? this.filled,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'label': label,
      'capacity': capacity,
      'filled': filled,
    };
  }

  factory VolunteerSlot.fromJson(Map<String, dynamic> json) {
    return VolunteerSlot(
      id: json['id'] as String,
      label: json['label'] as String,
      capacity: (json['capacity'] as num?)?.toInt() ?? 0,
      filled: (json['filled'] as num?)?.toInt() ?? 0,
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
    this.durationMinutes = 120,
    this.capacity,
    this.baseAttendeeCount = 0,
    this.baseWaitlistCount = 0,
    this.status = EventStatus.scheduled,
    this.reactionCounts = const <String, int>{},
    this.poll,
    this.volunteerSlots = const <VolunteerSlot>[],
    this.iv = '',
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
  final int durationMinutes;
  final int? capacity;
  final int baseAttendeeCount;
  final int baseWaitlistCount;
  final EventStatus status;
  final Map<String, int> reactionCounts;
  final EventPoll? poll;
  final List<VolunteerSlot> volunteerSlots;
  final String iv;
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
      'durationMinutes': durationMinutes,
      'capacity': capacity,
      'baseAttendeeCount': baseAttendeeCount,
      'baseWaitlistCount': baseWaitlistCount,
      'status': status.storageValue,
      'reactionCounts': _canonicalReactionCounts(),
      'poll': poll?.toJson(),
      'volunteerSlots': volunteerSlots
          .map((slot) => slot.toJson())
          .toList(growable: false),
      'iv': iv,
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
    int? durationMinutes,
    int? capacity,
    int? baseAttendeeCount,
    int? baseWaitlistCount,
    EventStatus? status,
    Map<String, int>? reactionCounts,
    EventPoll? poll,
    List<VolunteerSlot>? volunteerSlots,
    String? iv,
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
      durationMinutes: durationMinutes ?? this.durationMinutes,
      capacity: capacity ?? this.capacity,
      baseAttendeeCount: baseAttendeeCount ?? this.baseAttendeeCount,
      baseWaitlistCount: baseWaitlistCount ?? this.baseWaitlistCount,
      status: status ?? this.status,
      reactionCounts: reactionCounts ?? this.reactionCounts,
      poll: poll ?? this.poll,
      volunteerSlots: volunteerSlots ?? this.volunteerSlots,
      iv: iv ?? this.iv,
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
      'durationMinutes': durationMinutes,
      'capacity': capacity,
      'baseAttendeeCount': baseAttendeeCount,
      'baseWaitlistCount': baseWaitlistCount,
      'status': status.storageValue,
      'reactionCounts': _canonicalReactionCounts(),
      'poll': poll?.toJson(),
      'volunteerSlots': volunteerSlots.map((slot) => slot.toJson()).toList(),
      'iv': iv,
    };
  }

  factory CampusEvent.fromJson(Map<String, dynamic> json) {
    final reactionSource = Map<String, dynamic>.from(
      json['reactionCounts'] as Map? ?? const <String, dynamic>{},
    );
    final rawVolunteerSlots =
        json['volunteerSlots'] as List<dynamic>? ?? const <dynamic>[];

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
      durationMinutes: (json['durationMinutes'] as num?)?.toInt() ?? 120,
      capacity: (json['capacity'] as num?)?.toInt(),
      baseAttendeeCount: (json['baseAttendeeCount'] as num?)?.toInt() ?? 0,
      baseWaitlistCount: (json['baseWaitlistCount'] as num?)?.toInt() ?? 0,
      status: EventStatusX.fromStorage(
        json['status'] as String? ?? 'scheduled',
      ),
      reactionCounts: reactionSource.map(
        (key, value) => MapEntry(key, (value as num?)?.toInt() ?? 0),
      ),
      poll: json['poll'] == null
          ? null
          : EventPoll.fromJson(Map<String, dynamic>.from(json['poll'] as Map)),
      volunteerSlots: rawVolunteerSlots
          .map(
            (value) =>
                VolunteerSlot.fromJson(Map<String, dynamic>.from(value as Map)),
          )
          .toList(),
      iv: json['iv'] as String? ?? '',
    );
  }

  Map<String, int> _canonicalReactionCounts() {
    final keys = reactionCounts.keys.toList()..sort();
    return <String, int>{for (final key in keys) key: reactionCounts[key] ?? 0};
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
    this.durationMinutes = 120,
    this.capacity,
    this.baseAttendeeCount = 0,
    this.baseWaitlistCount = 0,
    this.status = EventStatus.scheduled,
    this.reactionCounts = const <String, int>{},
    this.poll,
    this.volunteerSlots = const <VolunteerSlot>[],
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
  final int durationMinutes;
  final int? capacity;
  final int baseAttendeeCount;
  final int baseWaitlistCount;
  final EventStatus status;
  final Map<String, int> reactionCounts;
  final EventPoll? poll;
  final List<VolunteerSlot> volunteerSlots;
}
