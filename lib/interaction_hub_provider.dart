import 'package:flutter/foundation.dart';

import 'models/campus_event.dart';
import 'models/event_interactions.dart';
import 'services/local_interaction_repository.dart';

class InteractionHubProvider extends ChangeNotifier {
  InteractionHubProvider({required LocalInteractionRepository repository})
    : _repository = repository {
    _loadState();
  }

  final LocalInteractionRepository _repository;

  bool _isReady = false;
  Set<String> _bookmarkedIds = <String>{};
  Map<String, EventRsvpState> _rsvpStates = <String, EventRsvpState>{};
  Set<String> _waitlistedIds = <String>{};
  Set<String> _checkedInIds = <String>{};
  Map<String, String> _privateNotes = <String, String>{};
  Map<String, Set<ReminderPreset>> _reminders = <String, Set<ReminderPreset>>{};
  Map<String, Set<ReactionKind>> _reactions = <String, Set<ReactionKind>>{};
  Map<String, List<EventComment>> _comments = <String, List<EventComment>>{};
  Map<String, String> _pollSelections = <String, String>{};
  Map<String, Set<String>> _volunteerSelections = <String, Set<String>>{};
  Map<String, EventAccessRequest> _accessRequests =
      <String, EventAccessRequest>{};
  Set<String> _dismissedReminderKeys = <String>{};

  bool get isReady => _isReady;
  int get bookmarkCount => _bookmarkedIds.length;
  int get trackedEventCount => trackedEventIds.length;
  int get reminderEventCount => _reminders.length;
  int get checkedInCount => _checkedInIds.length;

  List<EventAccessRequest> get accessRequests {
    final requests = _accessRequests.values.toList()
      ..sort((left, right) => right.createdAt.compareTo(left.createdAt));
    return requests;
  }

  List<EventAccessRequest> get pendingAccessRequests => accessRequests
      .where((request) => request.status == AccessRequestStatus.pending)
      .toList();

  Set<String> get trackedEventIds => <String>{
    ..._bookmarkedIds,
    ..._rsvpStates.entries
        .where((entry) => entry.value != EventRsvpState.none)
        .map((entry) => entry.key),
    ..._waitlistedIds,
    ..._checkedInIds,
    ..._reminders.keys,
    ..._volunteerSelections.keys,
  };

  Future<void> _loadState() async {
    final raw = await _repository.loadState();

    _bookmarkedIds = Set<String>.from(
      raw['bookmarkedIds'] as List? ?? const [],
    );
    _waitlistedIds = Set<String>.from(
      raw['waitlistedIds'] as List? ?? const [],
    );
    _checkedInIds = Set<String>.from(raw['checkedInIds'] as List? ?? const []);
    _dismissedReminderKeys = Set<String>.from(
      raw['dismissedReminderKeys'] as List? ?? const [],
    );
    _privateNotes = Map<String, String>.from(
      raw['privateNotes'] as Map? ?? const <String, String>{},
    );
    _pollSelections = Map<String, String>.from(
      raw['pollSelections'] as Map? ?? const <String, String>{},
    );

    final rawRsvps = Map<String, dynamic>.from(
      raw['rsvpStates'] as Map? ?? const <String, dynamic>{},
    );
    _rsvpStates = rawRsvps.map(
      (eventId, value) => MapEntry(
        eventId,
        EventRsvpStateX.fromStorage(value as String? ?? 'none'),
      ),
    );
    for (final eventId in _rsvpStates.keys.toList()) {
      if (_rsvpStates[eventId] == EventRsvpState.interested &&
          !_waitlistedIds.contains(eventId)) {
        _rsvpStates[eventId] = EventRsvpState.going;
      }
    }

    final rawReminders = Map<String, dynamic>.from(
      raw['reminders'] as Map? ?? const <String, dynamic>{},
    );
    _reminders = rawReminders.map(
      (eventId, value) => MapEntry(
        eventId,
        (value as List<dynamic>)
            .map((item) => ReminderPresetX.fromStorage(item as String))
            .toSet(),
      ),
    );

    final rawReactions = Map<String, dynamic>.from(
      raw['reactions'] as Map? ?? const <String, dynamic>{},
    );
    _reactions = rawReactions.map(
      (eventId, value) => MapEntry(
        eventId,
        (value as List<dynamic>)
            .map((item) => ReactionKindX.fromStorage(item as String))
            .toSet(),
      ),
    );

    final rawComments = Map<String, dynamic>.from(
      raw['comments'] as Map? ?? const <String, dynamic>{},
    );
    _comments = rawComments.map(
      (eventId, value) => MapEntry(
        eventId,
        (value as List<dynamic>)
            .map(
              (item) =>
                  EventComment.fromJson(Map<String, dynamic>.from(item as Map)),
            )
            .toList()
          ..sort((left, right) => left.createdAt.compareTo(right.createdAt)),
      ),
    );

    final rawVolunteer = Map<String, dynamic>.from(
      raw['volunteerSelections'] as Map? ?? const <String, dynamic>{},
    );
    _volunteerSelections = rawVolunteer.map(
      (eventId, value) =>
          MapEntry(eventId, Set<String>.from(value as List<dynamic>)),
    );

    final rawAccessRequests = Map<String, dynamic>.from(
      raw['accessRequests'] as Map? ?? const <String, dynamic>{},
    );
    _accessRequests = rawAccessRequests.map(
      (eventId, value) => MapEntry(
        eventId,
        EventAccessRequest.fromJson(Map<String, dynamic>.from(value as Map)),
      ),
    );

    _isReady = true;
    notifyListeners();
  }

  bool isBookmarked(String eventId) => _bookmarkedIds.contains(eventId);

  bool isSignedUp(String eventId) =>
      (_rsvpStates[eventId] ?? EventRsvpState.none) != EventRsvpState.none ||
      _waitlistedIds.contains(eventId);

  EventRsvpState rsvpFor(String eventId) =>
      _rsvpStates[eventId] ?? EventRsvpState.none;

  bool isWaitlisted(String eventId) => _waitlistedIds.contains(eventId);

  bool hasCheckedIn(String eventId) => _checkedInIds.contains(eventId);

  String noteFor(String eventId) => _privateNotes[eventId] ?? '';

  Set<ReminderPreset> remindersFor(String eventId) =>
      Set<ReminderPreset>.unmodifiable(
        _reminders[eventId] ?? const <ReminderPreset>{},
      );

  Set<ReactionKind> reactionsFor(String eventId) =>
      Set<ReactionKind>.unmodifiable(
        _reactions[eventId] ?? const <ReactionKind>{},
      );

  String? selectedPollOption(String eventId) => _pollSelections[eventId];

  Set<String> volunteerSelectionsFor(String eventId) =>
      Set<String>.unmodifiable(
        _volunteerSelections[eventId] ?? const <String>{},
      );

  EventAccessRequest? accessRequestFor(String eventId) =>
      _accessRequests[eventId];

  List<EventComment> commentsFor(String eventId) =>
      List<EventComment>.unmodifiable(
        _comments[eventId] ?? const <EventComment>[],
      );

  bool isTrackingEvent(String eventId) =>
      _bookmarkedIds.contains(eventId) ||
      (_rsvpStates[eventId] ?? EventRsvpState.none) != EventRsvpState.none ||
      _waitlistedIds.contains(eventId) ||
      _checkedInIds.contains(eventId) ||
      (_reminders[eventId]?.isNotEmpty ?? false) ||
      (_volunteerSelections[eventId]?.isNotEmpty ?? false);

  int attendeeCountFor(CampusEvent event) {
    return event.baseAttendeeCount +
        (rsvpFor(event.id) == EventRsvpState.going ? 1 : 0);
  }

  int waitlistCountFor(CampusEvent event) {
    return event.baseWaitlistCount + (isWaitlisted(event.id) ? 1 : 0);
  }

  bool isEventFull(CampusEvent event) {
    final capacity = event.capacity;
    if (capacity == null) {
      return false;
    }
    final currentAttendeeCount =
        attendeeCountFor(event) -
        (rsvpFor(event.id) == EventRsvpState.going ? 1 : 0);
    return currentAttendeeCount >= capacity;
  }

  int reactionCountFor(CampusEvent event, ReactionKind kind) {
    final baseCount = event.reactionCounts[kind.storageValue] ?? 0;
    return baseCount + (reactionsFor(event.id).contains(kind) ? 1 : 0);
  }

  int pollVotesFor(CampusEvent event, EventPollOption option) {
    final currentSelection = selectedPollOption(event.id);
    return option.votes + (currentSelection == option.id ? 1 : 0);
  }

  int volunteerCountFor(CampusEvent event, VolunteerSlot slot) {
    return slot.filled +
        (volunteerSelectionsFor(event.id).contains(slot.id) ? 1 : 0);
  }

  Future<void> toggleBookmark(String eventId) async {
    if (_bookmarkedIds.contains(eventId)) {
      _bookmarkedIds.remove(eventId);
    } else {
      _bookmarkedIds.add(eventId);
    }
    await _commit();
  }

  Future<InteractionActionResult> setRsvp(
    CampusEvent event,
    EventRsvpState state,
  ) async {
    if (state == EventRsvpState.none) {
      _rsvpStates.remove(event.id);
      _waitlistedIds.remove(event.id);
      _checkedInIds.remove(event.id);
      await _commit();
      return const InteractionActionResult(
        accepted: true,
        message: 'You are no longer signed up for this event.',
      );
    }

    if (state == EventRsvpState.going && isEventFull(event)) {
      _rsvpStates[event.id] = EventRsvpState.interested;
      _waitlistedIds.add(event.id);
      await _commit();
      return const InteractionActionResult(
        accepted: true,
        message: 'That event is full, so you were added to the waitlist.',
      );
    }

    _rsvpStates[event.id] = state;
    if (state == EventRsvpState.going) {
      _waitlistedIds.remove(event.id);
    }
    if (state != EventRsvpState.going) {
      _checkedInIds.remove(event.id);
    }
    await _commit();
    switch (state) {
      case EventRsvpState.none:
        return const InteractionActionResult(
          accepted: true,
          message: 'You are no longer signed up for this event.',
        );
      case EventRsvpState.interested:
        return const InteractionActionResult(
          accepted: true,
          message: 'You are on the waitlist for this event.',
        );
      case EventRsvpState.going:
        return const InteractionActionResult(
          accepted: true,
          message: 'You are signed up for this event.',
        );
    }
  }

  Future<InteractionActionResult> toggleSignup(CampusEvent event) async {
    if (isSignedUp(event.id)) {
      return setRsvp(event, EventRsvpState.none);
    }
    return setRsvp(event, EventRsvpState.going);
  }

  Future<InteractionActionResult> joinWaitlist(CampusEvent event) async {
    if (rsvpFor(event.id) == EventRsvpState.going) {
      return const InteractionActionResult(
        accepted: false,
        message: 'You already have a confirmed spot for this event.',
      );
    }

    _rsvpStates[event.id] = EventRsvpState.interested;
    _waitlistedIds.add(event.id);
    await _commit();
    return const InteractionActionResult(
      accepted: true,
      message: 'You were added to the waitlist.',
    );
  }

  Future<void> leaveWaitlist(String eventId) async {
    _waitlistedIds.remove(eventId);
    if (rsvpFor(eventId) == EventRsvpState.interested) {
      _rsvpStates.remove(eventId);
    }
    await _commit();
  }

  Future<void> savePrivateNote(String eventId, String note) async {
    final trimmed = note.trim();
    if (trimmed.isEmpty) {
      _privateNotes.remove(eventId);
    } else {
      _privateNotes[eventId] = trimmed;
    }
    await _commit();
  }

  Future<void> toggleReminder(String eventId, ReminderPreset preset) async {
    final current = Set<ReminderPreset>.from(_reminders[eventId] ?? const {});
    if (current.contains(preset)) {
      current.remove(preset);
    } else {
      current.add(preset);
      _dismissedReminderKeys.removeWhere(
        (key) => key.startsWith('$eventId|${preset.storageValue}|'),
      );
    }

    if (current.isEmpty) {
      _reminders.remove(eventId);
    } else {
      _reminders[eventId] = current;
    }
    await _commit();
  }

  List<ReminderCue> dueReminders(List<CampusEvent> events) {
    final now = DateTime.now();
    final eventById = <String, CampusEvent>{
      for (final event in events) event.id: event,
    };
    final cues = <ReminderCue>[];

    for (final entry in _reminders.entries) {
      final event = eventById[entry.key];
      if (event == null) {
        continue;
      }

      final eventEnd = event.startsAt.toLocal().add(
        Duration(minutes: event.durationMinutes),
      );
      if (eventEnd.isBefore(now)) {
        continue;
      }

      for (final preset in entry.value) {
        final scheduledAt = event.startsAt.toLocal().subtract(preset.offset);
        final cue = ReminderCue(
          eventId: event.id,
          preset: preset,
          scheduledAt: scheduledAt,
        );
        if (!now.isBefore(scheduledAt) &&
            !_dismissedReminderKeys.contains(cue.storageKey)) {
          cues.add(cue);
        }
      }
    }

    cues.sort((left, right) => left.scheduledAt.compareTo(right.scheduledAt));
    return cues;
  }

  Future<void> dismissReminder(ReminderCue cue) async {
    _dismissedReminderKeys.add(cue.storageKey);
    await _commit();
  }

  Future<void> toggleReaction(String eventId, ReactionKind kind) async {
    final selected = Set<ReactionKind>.from(_reactions[eventId] ?? const {});
    if (selected.contains(kind)) {
      selected.remove(kind);
    } else {
      selected.add(kind);
    }

    if (selected.isEmpty) {
      _reactions.remove(eventId);
    } else {
      _reactions[eventId] = selected;
    }
    await _commit();
  }

  Future<InteractionActionResult> addComment({
    required String eventId,
    required String authorLabel,
    required String message,
    bool isAdminReply = false,
    String? replyToId,
  }) async {
    final trimmed = message.trim();
    if (trimmed.isEmpty) {
      return const InteractionActionResult(
        accepted: false,
        message: 'Write a comment first.',
      );
    }

    final comments = List<EventComment>.from(_comments[eventId] ?? const []);
    comments.add(
      EventComment(
        id: '$eventId-${DateTime.now().microsecondsSinceEpoch}',
        authorLabel: authorLabel,
        message: trimmed,
        createdAt: DateTime.now().toUtc(),
        isAdminReply: isAdminReply,
        replyToId: replyToId,
      ),
    );
    _comments[eventId] = comments;
    await _commit();
    return const InteractionActionResult(
      accepted: true,
      message: 'Comment posted.',
    );
  }

  Future<InteractionActionResult> voteOnPoll(
    CampusEvent event,
    String optionId,
  ) async {
    if (event.poll == null) {
      return const InteractionActionResult(
        accepted: false,
        message: 'This event does not have a poll yet.',
      );
    }

    _pollSelections[event.id] = optionId;
    await _commit();
    return const InteractionActionResult(
      accepted: true,
      message: 'Your vote was recorded.',
    );
  }

  Future<InteractionActionResult> toggleVolunteerSlot(
    CampusEvent event,
    VolunteerSlot slot,
  ) async {
    final selected = Set<String>.from(
      _volunteerSelections[event.id] ?? const <String>{},
    );
    if (selected.contains(slot.id)) {
      selected.remove(slot.id);
      if (selected.isEmpty) {
        _volunteerSelections.remove(event.id);
      } else {
        _volunteerSelections[event.id] = selected;
      }
      await _commit();
      return const InteractionActionResult(
        accepted: true,
        message: 'Volunteer slot released.',
      );
    }

    if (volunteerCountFor(event, slot) >= slot.capacity) {
      return const InteractionActionResult(
        accepted: false,
        message: 'That volunteer slot is already full.',
      );
    }

    selected.add(slot.id);
    _volunteerSelections[event.id] = selected;
    await _commit();
    return const InteractionActionResult(
      accepted: true,
      message: 'Volunteer slot reserved.',
    );
  }

  Future<InteractionActionResult> submitAccessRequest({
    required String eventId,
    required String requestText,
  }) async {
    final trimmed = requestText.trim();
    if (trimmed.isEmpty) {
      return const InteractionActionResult(
        accepted: false,
        message: 'Add a short reason before sending the request.',
      );
    }

    _accessRequests[eventId] = EventAccessRequest(
      eventId: eventId,
      requestText: trimmed,
      createdAt: DateTime.now().toUtc(),
    );
    await _commit();
    return const InteractionActionResult(
      accepted: true,
      message: 'Access request sent for admin review.',
    );
  }

  Future<void> resolveAccessRequest({
    required String eventId,
    required AccessRequestStatus status,
    String? note,
  }) async {
    final request = _accessRequests[eventId];
    if (request == null) {
      return;
    }

    _accessRequests[eventId] = request.copyWith(
      status: status,
      resolutionNote: note?.trim().isEmpty ?? true ? null : note!.trim(),
    );
    await _commit();
  }

  Future<InteractionActionResult> toggleCheckIn(CampusEvent event) async {
    final rsvp = rsvpFor(event.id);
    if (rsvp != EventRsvpState.going) {
      return const InteractionActionResult(
        accepted: false,
        message: 'Sign up before checking in.',
      );
    }

    if (_checkedInIds.contains(event.id)) {
      _checkedInIds.remove(event.id);
      await _commit();
      return const InteractionActionResult(
        accepted: true,
        message: 'Check-in removed.',
      );
    }

    _checkedInIds.add(event.id);
    await _commit();
    return const InteractionActionResult(
      accepted: true,
      message: 'You are checked in for this event.',
    );
  }

  Future<void> clearAll() async {
    _bookmarkedIds = <String>{};
    _rsvpStates = <String, EventRsvpState>{};
    _waitlistedIds = <String>{};
    _checkedInIds = <String>{};
    _privateNotes = <String, String>{};
    _reminders = <String, Set<ReminderPreset>>{};
    _reactions = <String, Set<ReactionKind>>{};
    _comments = <String, List<EventComment>>{};
    _pollSelections = <String, String>{};
    _volunteerSelections = <String, Set<String>>{};
    _accessRequests = <String, EventAccessRequest>{};
    _dismissedReminderKeys = <String>{};
    await _repository.clear();
    notifyListeners();
  }

  Future<void> _commit() async {
    notifyListeners();
    await _repository.saveState(<String, dynamic>{
      'bookmarkedIds': _bookmarkedIds.toList()..sort(),
      'rsvpStates': _rsvpStates.map(
        (eventId, state) => MapEntry(eventId, state.storageValue),
      ),
      'waitlistedIds': _waitlistedIds.toList()..sort(),
      'checkedInIds': _checkedInIds.toList()..sort(),
      'privateNotes': _privateNotes,
      'reminders': _reminders.map(
        (eventId, presets) => MapEntry(
          eventId,
          presets.map((preset) => preset.storageValue).toList()..sort(),
        ),
      ),
      'reactions': _reactions.map(
        (eventId, reactions) => MapEntry(
          eventId,
          reactions.map((reaction) => reaction.storageValue).toList()..sort(),
        ),
      ),
      'comments': _comments.map(
        (eventId, comments) => MapEntry(
          eventId,
          comments.map((comment) => comment.toJson()).toList(),
        ),
      ),
      'pollSelections': _pollSelections,
      'volunteerSelections': _volunteerSelections.map(
        (eventId, selections) => MapEntry(eventId, selections.toList()..sort()),
      ),
      'accessRequests': _accessRequests.map(
        (eventId, request) => MapEntry(eventId, request.toJson()),
      ),
      'dismissedReminderKeys': _dismissedReminderKeys.toList()..sort(),
    });
  }
}
