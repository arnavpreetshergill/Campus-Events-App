import 'package:flutter/foundation.dart';

import 'models/campus_event.dart';
import 'models/custodian_access.dart';
import 'services/local_event_repository.dart';

enum EventFeedFilter { all, publicOnly, secureOnly }

class EventFeedProvider extends ChangeNotifier {
  EventFeedProvider({required LocalEventRepository repository})
    : _repository = repository {
    loadEvents();
  }

  final LocalEventRepository _repository;

  List<CampusEvent> _events = const <CampusEvent>[];
  EventFeedFilter _filter = EventFeedFilter.all;
  bool _isLoading = true;
  String? _errorMessage;

  List<CampusEvent> get events => _events;
  EventFeedFilter get filter => _filter;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  List<String> get categories {
    final values = _events.map((event) => event.category).toSet().toList()
      ..sort();
    return values;
  }

  List<CampusEvent> filteredEventsFor(
    CustodianAccessSnapshot access, {
    EventFeedFilter? filter,
  }) {
    final effectiveFilter = filter ?? _filter;
    final visibleEvents = access.isAdmin
        ? _events
        : _events.where((event) => !event.isEncrypted).toList();

    switch (effectiveFilter) {
      case EventFeedFilter.all:
        return visibleEvents;
      case EventFeedFilter.publicOnly:
        return visibleEvents.where((event) => !event.isEncrypted).toList();
      case EventFeedFilter.secureOnly:
        return access.isAdmin
            ? visibleEvents.where((event) => event.isEncrypted).toList()
            : visibleEvents;
    }
  }

  int get publicCount => _events.where((event) => !event.isEncrypted).length;
  int get secureCount => _events.where((event) => event.isEncrypted).length;
  int get integrityIssueCount =>
      _events.where((event) => !event.integrityVerified).length;

  Future<void> loadEvents() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _events = await _repository.fetchEvents();
    } catch (error) {
      _errorMessage = error.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refresh() async {
    try {
      _events = await _repository.fetchEvents();
      _errorMessage = null;
      notifyListeners();
    } catch (error) {
      _errorMessage = error.toString();
      notifyListeners();
    }
  }

  Future<void> saveEvent(
    EventDraft draft,
    CustodianAccessSnapshot access,
  ) async {
    _events = await _repository.upsertEvent(draft, access);
    _errorMessage = null;
    notifyListeners();
  }

  Future<void> resetFeed() async {
    _events = await _repository.resetDemoFeed();
    _errorMessage = null;
    notifyListeners();
  }

  void setFilter(EventFeedFilter value) {
    if (_filter == value) {
      return;
    }
    _filter = value;
    notifyListeners();
  }
}
