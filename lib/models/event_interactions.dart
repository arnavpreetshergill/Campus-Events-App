enum EventRsvpState { none, interested, going }

extension EventRsvpStateX on EventRsvpState {
  String get storageValue {
    switch (this) {
      case EventRsvpState.none:
        return 'none';
      case EventRsvpState.interested:
        return 'interested';
      case EventRsvpState.going:
        return 'going';
    }
  }

  String get label {
    switch (this) {
      case EventRsvpState.none:
        return 'Not signed up';
      case EventRsvpState.interested:
        return 'Waitlisted';
      case EventRsvpState.going:
        return 'Signed up';
    }
  }

  static EventRsvpState fromStorage(String value) {
    return EventRsvpState.values.firstWhere(
      (state) => state.storageValue == value,
      orElse: () => EventRsvpState.none,
    );
  }
}

enum ReminderPreset { dayBefore, hourBefore, fifteenMinutes }

extension ReminderPresetX on ReminderPreset {
  String get storageValue {
    switch (this) {
      case ReminderPreset.dayBefore:
        return 'dayBefore';
      case ReminderPreset.hourBefore:
        return 'hourBefore';
      case ReminderPreset.fifteenMinutes:
        return 'fifteenMinutes';
    }
  }

  String get label {
    switch (this) {
      case ReminderPreset.dayBefore:
        return '1 day before';
      case ReminderPreset.hourBefore:
        return '1 hour before';
      case ReminderPreset.fifteenMinutes:
        return '15 minutes before';
    }
  }

  Duration get offset {
    switch (this) {
      case ReminderPreset.dayBefore:
        return const Duration(days: 1);
      case ReminderPreset.hourBefore:
        return const Duration(hours: 1);
      case ReminderPreset.fifteenMinutes:
        return const Duration(minutes: 15);
    }
  }

  static ReminderPreset fromStorage(String value) {
    return ReminderPreset.values.firstWhere(
      (preset) => preset.storageValue == value,
      orElse: () => ReminderPreset.hourBefore,
    );
  }
}

enum ReactionKind { clap, fire, star }

extension ReactionKindX on ReactionKind {
  String get storageValue {
    switch (this) {
      case ReactionKind.clap:
        return 'clap';
      case ReactionKind.fire:
        return 'fire';
      case ReactionKind.star:
        return 'star';
    }
  }

  String get label {
    switch (this) {
      case ReactionKind.clap:
        return 'Clap';
      case ReactionKind.fire:
        return 'Fire';
      case ReactionKind.star:
        return 'Star';
    }
  }

  static ReactionKind fromStorage(String value) {
    return ReactionKind.values.firstWhere(
      (kind) => kind.storageValue == value,
      orElse: () => ReactionKind.clap,
    );
  }
}

enum AccessRequestStatus { pending, approved, declined }

extension AccessRequestStatusX on AccessRequestStatus {
  String get storageValue {
    switch (this) {
      case AccessRequestStatus.pending:
        return 'pending';
      case AccessRequestStatus.approved:
        return 'approved';
      case AccessRequestStatus.declined:
        return 'declined';
    }
  }

  String get label {
    switch (this) {
      case AccessRequestStatus.pending:
        return 'Pending';
      case AccessRequestStatus.approved:
        return 'Approved';
      case AccessRequestStatus.declined:
        return 'Declined';
    }
  }

  static AccessRequestStatus fromStorage(String value) {
    return AccessRequestStatus.values.firstWhere(
      (status) => status.storageValue == value,
      orElse: () => AccessRequestStatus.pending,
    );
  }
}

class InteractionActionResult {
  const InteractionActionResult({
    required this.accepted,
    required this.message,
  });

  final bool accepted;
  final String message;
}

class EventComment {
  const EventComment({
    required this.id,
    required this.authorLabel,
    required this.message,
    required this.createdAt,
    this.isAdminReply = false,
    this.replyToId,
  });

  final String id;
  final String authorLabel;
  final String message;
  final DateTime createdAt;
  final bool isAdminReply;
  final String? replyToId;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'authorLabel': authorLabel,
      'message': message,
      'createdAt': createdAt.toUtc().toIso8601String(),
      'isAdminReply': isAdminReply,
      'replyToId': replyToId,
    };
  }

  factory EventComment.fromJson(Map<String, dynamic> json) {
    return EventComment(
      id: json['id'] as String,
      authorLabel: json['authorLabel'] as String,
      message: json['message'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      isAdminReply: json['isAdminReply'] as bool? ?? false,
      replyToId: json['replyToId'] as String?,
    );
  }
}

class EventAccessRequest {
  const EventAccessRequest({
    required this.eventId,
    required this.requestText,
    required this.createdAt,
    this.status = AccessRequestStatus.pending,
    this.resolutionNote,
  });

  final String eventId;
  final String requestText;
  final DateTime createdAt;
  final AccessRequestStatus status;
  final String? resolutionNote;

  EventAccessRequest copyWith({
    String? eventId,
    String? requestText,
    DateTime? createdAt,
    AccessRequestStatus? status,
    String? resolutionNote,
  }) {
    return EventAccessRequest(
      eventId: eventId ?? this.eventId,
      requestText: requestText ?? this.requestText,
      createdAt: createdAt ?? this.createdAt,
      status: status ?? this.status,
      resolutionNote: resolutionNote ?? this.resolutionNote,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'eventId': eventId,
      'requestText': requestText,
      'createdAt': createdAt.toUtc().toIso8601String(),
      'status': status.storageValue,
      'resolutionNote': resolutionNote,
    };
  }

  factory EventAccessRequest.fromJson(Map<String, dynamic> json) {
    return EventAccessRequest(
      eventId: json['eventId'] as String,
      requestText: json['requestText'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      status: AccessRequestStatusX.fromStorage(
        json['status'] as String? ?? 'pending',
      ),
      resolutionNote: json['resolutionNote'] as String?,
    );
  }
}

class ReminderCue {
  const ReminderCue({
    required this.eventId,
    required this.preset,
    required this.scheduledAt,
  });

  final String eventId;
  final ReminderPreset preset;
  final DateTime scheduledAt;

  String get storageKey =>
      '$eventId|${preset.storageValue}|${scheduledAt.toUtc().toIso8601String()}';
}
