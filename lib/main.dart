import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:provider/provider.dart';

import 'crypto_utils.dart';
import 'event_feed_provider.dart';
import 'interaction_hub_provider.dart';
import 'key_custodian_provider.dart';
import 'models/campus_event.dart';
import 'models/custodian_access.dart';
import 'models/event_interactions.dart';
import 'services/local_event_repository.dart';
import 'services/local_interaction_repository.dart';
import 'theme/app_theme.dart';
import 'widgets/aurora_background.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const DecentralizedCampusApp());
}

enum DashboardSection { feed, schedule, myEvents }

extension DashboardSectionX on DashboardSection {
  String get label {
    switch (this) {
      case DashboardSection.feed:
        return 'Feed';
      case DashboardSection.schedule:
        return 'Schedule';
      case DashboardSection.myEvents:
        return 'My events';
    }
  }
}

enum EventDateWindow { all, today, thisWeek, thisMonth }

extension EventDateWindowX on EventDateWindow {
  String get label {
    switch (this) {
      case EventDateWindow.all:
        return 'All dates';
      case EventDateWindow.today:
        return 'Today';
      case EventDateWindow.thisWeek:
        return 'This week';
      case EventDateWindow.thisMonth:
        return 'This month';
    }
  }
}

class DecentralizedCampusApp extends StatelessWidget {
  const DecentralizedCampusApp({super.key, this.storage});

  final FlutterSecureStorage? storage;

  @override
  Widget build(BuildContext context) {
    final secureStorage = storage ?? const FlutterSecureStorage();

    return MultiProvider(
      providers: [
        Provider<FlutterSecureStorage>.value(value: secureStorage),
        ChangeNotifierProvider<KeyCustodianProvider>(
          create: (_) => KeyCustodianProvider(storage: secureStorage),
        ),
        Provider<LocalEventRepository>(
          create: (_) => LocalEventRepository(storage: secureStorage),
        ),
        ChangeNotifierProvider<EventFeedProvider>(
          create: (context) => EventFeedProvider(
            repository: context.read<LocalEventRepository>(),
          ),
        ),
        Provider<LocalInteractionRepository>(
          create: (_) => LocalInteractionRepository(storage: secureStorage),
        ),
        ChangeNotifierProvider<InteractionHubProvider>(
          create: (context) => InteractionHubProvider(
            repository: context.read<LocalInteractionRepository>(),
          ),
        ),
      ],
      child: MaterialApp(
        title: 'Campus Events',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme,
        home: const CampusControlShell(),
      ),
    );
  }
}

class CampusControlShell extends StatefulWidget {
  const CampusControlShell({super.key});

  @override
  State<CampusControlShell> createState() => _CampusControlShellState();
}

class _CampusControlShellState extends State<CampusControlShell> {
  final TextEditingController _searchController = TextEditingController();

  DashboardSection _section = DashboardSection.feed;
  EventDateWindow _dateWindow = EventDateWindow.all;
  String? _categoryFilter;
  bool _bookmarkedOnly = false;
  bool _signedUpOnly = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _openAccessConsole() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const _AccessConsoleSheet(),
    );
  }

  Future<void> _openComposer([CampusEvent? event]) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _EventComposerSheet(initialEvent: event),
    );
  }

  void _showEventDetails(CampusEvent event) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _EventDetailsSheet(event: event),
    );
  }

  List<CampusEvent> _applyInteractiveFilters(
    List<CampusEvent> events,
    InteractionHubProvider interactions,
  ) {
    final query = _searchController.text.trim().toLowerCase();
    final now = DateTime.now();

    return events.where((event) {
      if (_categoryFilter != null && event.category != _categoryFilter) {
        return false;
      }

      if (_bookmarkedOnly && !interactions.isBookmarked(event.id)) {
        return false;
      }

      if (_signedUpOnly && !interactions.isSignedUp(event.id)) {
        return false;
      }

      if (!_matchesDateWindow(event, now)) {
        return false;
      }

      if (query.isEmpty) {
        return true;
      }

      final haystack = <String>[
        event.title,
        event.organizer,
        event.category,
        event.location,
        event.summary,
      ].join(' ').toLowerCase();
      return haystack.contains(query);
    }).toList();
  }

  bool _matchesDateWindow(CampusEvent event, DateTime now) {
    final localStart = event.startsAt.toLocal();
    final today = DateTime(now.year, now.month, now.day);

    switch (_dateWindow) {
      case EventDateWindow.all:
        return true;
      case EventDateWindow.today:
        return localStart.year == now.year &&
            localStart.month == now.month &&
            localStart.day == now.day;
      case EventDateWindow.thisWeek:
        final lastDay = today.add(const Duration(days: 7));
        return !localStart.isBefore(today) && localStart.isBefore(lastDay);
      case EventDateWindow.thisMonth:
        return localStart.year == now.year && localStart.month == now.month;
    }
  }

  @override
  Widget build(BuildContext context) {
    final access = context.watch<KeyCustodianProvider>();
    final feed = context.watch<EventFeedProvider>();
    final interactions = context.watch<InteractionHubProvider>();

    final effectiveFilter =
        !access.isAdmin && feed.filter == EventFeedFilter.secureOnly
        ? EventFeedFilter.all
        : feed.filter;
    final visibleEvents = _applyInteractiveFilters(
      feed.filteredEventsFor(access.snapshot, filter: effectiveFilter),
      interactions,
    );
    final trackedEvents = visibleEvents
        .where((event) => interactions.isTrackingEvent(event.id))
        .toList();
    final dueReminders = interactions.dueReminders(feed.events);
    final accessibleCategories = feed.filteredEventsFor(
      access.snapshot,
      filter: EventFeedFilter.all,
    );
    final categories =
        accessibleCategories.map((event) => event.category).toSet().toList()
          ..sort();
    final eventLookup = <String, CampusEvent>{
      for (final event in feed.events) event.id: event,
    };

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: access.isAdmin
          ? FloatingActionButton.extended(
              onPressed: _openComposer,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Create Event'),
            )
          : null,
      body: Stack(
        children: <Widget>[
          const Positioned.fill(child: AuroraBackground()),
          SafeArea(
            child: Column(
              children: <Widget>[
                _TopBar(
                  onOpenConsole: _openAccessConsole,
                  isAdmin: access.isAdmin,
                  trackedCount: interactions.trackedEventCount,
                  reminderCount: dueReminders.length,
                ),
                _DashboardControls(
                  controller: _searchController,
                  section: _section,
                  onSectionChanged: (value) => setState(() => _section = value),
                  dateWindow: _dateWindow,
                  onDateWindowChanged: (value) =>
                      setState(() => _dateWindow = value),
                  categories: categories,
                  selectedCategory: _categoryFilter,
                  onCategoryChanged: (value) =>
                      setState(() => _categoryFilter = value),
                  bookmarkedOnly: _bookmarkedOnly,
                  onBookmarkedOnlyChanged: () =>
                      setState(() => _bookmarkedOnly = !_bookmarkedOnly),
                  signedUpOnly: _signedUpOnly,
                  onSignedUpOnlyChanged: () =>
                      setState(() => _signedUpOnly = !_signedUpOnly),
                  onSearchChanged: (_) => setState(() {}),
                  onClearSearch: () {
                    _searchController.clear();
                    setState(() {});
                  },
                  onResetFilters: () {
                    setState(() {
                      _section = DashboardSection.feed;
                      _dateWindow = EventDateWindow.all;
                      _categoryFilter = null;
                      _bookmarkedOnly = false;
                      _signedUpOnly = false;
                    });
                  },
                ),
                Expanded(
                  child: Builder(
                    builder: (context) {
                      if (feed.isLoading) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      if (feed.errorMessage != null) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(feed.errorMessage!),
                          ),
                        );
                      }

                      switch (_section) {
                        case DashboardSection.feed:
                          return _FeedSection(
                            events: visibleEvents,
                            dueReminders: dueReminders,
                            eventLookup: eventLookup,
                            isAdmin: access.isAdmin,
                            filter: effectiveFilter,
                            onFilterChanged: feed.setFilter,
                            onRefresh: feed.refresh,
                            onOpenEvent: _showEventDetails,
                            onEditEvent: _openComposer,
                          );
                        case DashboardSection.schedule:
                          return _ScheduleSection(
                            events: visibleEvents,
                            dueReminders: dueReminders,
                            eventLookup: eventLookup,
                            onRefresh: feed.refresh,
                            onOpenEvent: _showEventDetails,
                          );
                        case DashboardSection.myEvents:
                          return _MyEventsSection(
                            trackedEvents: trackedEvents,
                            dueReminders: dueReminders,
                            eventLookup: eventLookup,
                            isAdmin: access.isAdmin,
                            onRefresh: feed.refresh,
                            onOpenEvent: _showEventDetails,
                            onEditEvent: _openComposer,
                          );
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.onOpenConsole,
    required this.isAdmin,
    required this.trackedCount,
    required this.reminderCount,
  });

  final VoidCallback onOpenConsole;
  final bool isAdmin;
  final int trackedCount;
  final int reminderCount;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        decoration: BoxDecoration(
          color: const Color(0x82102039),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 20,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        child: Row(
          children: <Widget>[
            Expanded(
              child: GestureDetector(
                onLongPress: onOpenConsole,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Campus Events',
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Search, plan, react, and manage the live campus schedule.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: const Color(0xFF8EA8C0),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (trackedCount > 0) ...<Widget>[
              const SizedBox(width: 12),
              _ModeBadge(modeLabel: '$trackedCount tracked'),
            ],
            if (reminderCount > 0) ...<Widget>[
              const SizedBox(width: 12),
              _ModeBadge(modeLabel: '$reminderCount alerts'),
            ],
            if (isAdmin) ...<Widget>[
              const SizedBox(width: 12),
              const _ModeBadge(modeLabel: 'Admin'),
            ],
            const SizedBox(width: 12),
            IconButton(
              onPressed: onOpenConsole,
              tooltip: 'Access settings',
              style: IconButton.styleFrom(
                backgroundColor: Colors.white.withValues(alpha: 0.06),
                foregroundColor: AppTheme.mist,
              ),
              icon: const Icon(Icons.tune_rounded),
            ),
          ],
        ),
      ),
    );
  }
}

class _DashboardControls extends StatefulWidget {
  const _DashboardControls({
    required this.controller,
    required this.section,
    required this.onSectionChanged,
    required this.dateWindow,
    required this.onDateWindowChanged,
    required this.categories,
    required this.selectedCategory,
    required this.onCategoryChanged,
    required this.bookmarkedOnly,
    required this.onBookmarkedOnlyChanged,
    required this.signedUpOnly,
    required this.onSignedUpOnlyChanged,
    required this.onSearchChanged,
    required this.onClearSearch,
    required this.onResetFilters,
  });

  final TextEditingController controller;
  final DashboardSection section;
  final ValueChanged<DashboardSection> onSectionChanged;
  final EventDateWindow dateWindow;
  final ValueChanged<EventDateWindow> onDateWindowChanged;
  final List<String> categories;
  final String? selectedCategory;
  final ValueChanged<String?> onCategoryChanged;
  final bool bookmarkedOnly;
  final VoidCallback onBookmarkedOnlyChanged;
  final bool signedUpOnly;
  final VoidCallback onSignedUpOnlyChanged;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onClearSearch;
  final VoidCallback onResetFilters;

  @override
  State<_DashboardControls> createState() => _DashboardControlsState();
}

class _DashboardControlsState extends State<_DashboardControls> {
  bool _expanded = false;

  int get _activeFilterCount {
    var count = 0;
    if (widget.section != DashboardSection.feed) {
      count += 1;
    }
    if (widget.dateWindow != EventDateWindow.all) {
      count += 1;
    }
    if (widget.selectedCategory != null) {
      count += 1;
    }
    if (widget.bookmarkedOnly) {
      count += 1;
    }
    if (widget.signedUpOnly) {
      count += 1;
    }
    return count;
  }

  @override
  Widget build(BuildContext context) {
    final activeCount = _activeFilterCount;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xA912213B),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: TextField(
                    controller: widget.controller,
                    onChanged: widget.onSearchChanged,
                    decoration: InputDecoration(
                      hintText: 'Search events, locations, organizers',
                      prefixIcon: const Icon(Icons.search_rounded),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 16),
                      suffixIcon: widget.controller.text.isEmpty
                          ? null
                          : IconButton(
                              tooltip: 'Clear search',
                              onPressed: widget.onClearSearch,
                              icon: const Icon(Icons.close_rounded),
                            ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Stack(
                  clipBehavior: Clip.none,
                  children: <Widget>[
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => setState(() => _expanded = !_expanded),
                        borderRadius: BorderRadius.circular(18),
                        child: Ink(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: _expanded
                                ? AppTheme.cyan.withValues(alpha: 0.16)
                                : Colors.white.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: _expanded
                                  ? AppTheme.cyan.withValues(alpha: 0.3)
                                  : Colors.white.withValues(alpha: 0.08),
                            ),
                          ),
                          child: Center(
                            child: AnimatedRotation(
                              turns: _expanded ? 0.5 : 0,
                              duration: const Duration(milliseconds: 220),
                              child: Icon(
                                Icons.tune_rounded,
                                color: _expanded
                                    ? AppTheme.cyan
                                    : const Color(0xFFD7E4EF),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (activeCount > 0)
                      Positioned(
                        right: -4,
                        top: -4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.coral,
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: const Color(0xFF0C1422),
                              width: 2,
                            ),
                          ),
                          child: Text(
                            '$activeCount',
                            style: Theme.of(context).textTheme.labelLarge
                                ?.copyWith(fontSize: 10, color: AppTheme.ink),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
            ClipRect(
              child: AnimatedSize(
                duration: const Duration(milliseconds: 240),
                curve: Curves.easeOutCubic,
                child: _expanded
                    ? Padding(
                        padding: const EdgeInsets.only(top: 14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Row(
                              children: <Widget>[
                                Text(
                                  'Filters',
                                  style: Theme.of(
                                    context,
                                  ).textTheme.titleMedium,
                                ),
                                const SizedBox(width: 10),
                                if (activeCount > 0)
                                  Text(
                                    '$activeCount active',
                                    style: Theme.of(context).textTheme.bodySmall
                                        ?.copyWith(color: AppTheme.cyan),
                                  ),
                                const Spacer(),
                                if (activeCount > 0)
                                  TextButton(
                                    onPressed: widget.onResetFilters,
                                    child: const Text('Reset'),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              children: DashboardSection.values
                                  .map(
                                    (value) => _FilterChipButton(
                                      label: value.label,
                                      selected: widget.section == value,
                                      onTap: () =>
                                          widget.onSectionChanged(value),
                                    ),
                                  )
                                  .toList(),
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              children: EventDateWindow.values
                                  .map(
                                    (value) => _FilterChipButton(
                                      label: value.label,
                                      selected: widget.dateWindow == value,
                                      onTap: () =>
                                          widget.onDateWindowChanged(value),
                                    ),
                                  )
                                  .toList(),
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              children: <Widget>[
                                _FilterChipButton(
                                  label: 'Bookmarked',
                                  selected: widget.bookmarkedOnly,
                                  onTap: widget.onBookmarkedOnlyChanged,
                                ),
                                _FilterChipButton(
                                  label: 'Signed up',
                                  selected: widget.signedUpOnly,
                                  onTap: widget.onSignedUpOnlyChanged,
                                ),
                              ],
                            ),
                            if (widget.categories.isNotEmpty) ...<Widget>[
                              const SizedBox(height: 12),
                              SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Row(
                                  children: <Widget>[
                                    _FilterChipButton(
                                      label: 'All categories',
                                      selected: widget.selectedCategory == null,
                                      onTap: () =>
                                          widget.onCategoryChanged(null),
                                    ),
                                    for (final category in widget.categories)
                                      Padding(
                                        padding: const EdgeInsets.only(
                                          left: 10,
                                        ),
                                        child: _FilterChipButton(
                                          label: category,
                                          selected:
                                              widget.selectedCategory ==
                                              category,
                                          onTap: () => widget.onCategoryChanged(
                                            category,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FeedSection extends StatelessWidget {
  const _FeedSection({
    required this.events,
    required this.dueReminders,
    required this.eventLookup,
    required this.isAdmin,
    required this.filter,
    required this.onFilterChanged,
    required this.onRefresh,
    required this.onOpenEvent,
    required this.onEditEvent,
  });

  final List<CampusEvent> events;
  final List<ReminderCue> dueReminders;
  final Map<String, CampusEvent> eventLookup;
  final bool isAdmin;
  final EventFeedFilter filter;
  final ValueChanged<EventFeedFilter> onFilterChanged;
  final Future<void> Function() onRefresh;
  final ValueChanged<CampusEvent> onOpenEvent;
  final Future<void> Function([CampusEvent? event]) onEditEvent;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      color: AppTheme.coral,
      child: CustomScrollView(
        cacheExtent: 2000,
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        slivers: <Widget>[
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Upcoming events',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    isAdmin
                        ? 'You can manage live status, private logistics, and attendee workflows on this device.'
                        : 'Browse public updates, save plans, and react to what is happening around campus.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 16),
                  _FilterRail(
                    filter: filter,
                    isAdmin: isAdmin,
                    onChanged: onFilterChanged,
                  ),
                ],
              ),
            ),
          ),
          if (dueReminders.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                child: _ReminderCenterCard(
                  cues: dueReminders,
                  eventLookup: eventLookup,
                  onOpenEvent: onOpenEvent,
                ),
              ),
            ),
          if (events.isEmpty)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Text('No events available for the current filters.'),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate((context, index) {
                  final event = events[index];
                  return _DelayedReveal(
                    delay: Duration(milliseconds: 60 * index),
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: _EventCard(
                        event: event,
                        onOpen: () => onOpenEvent(event),
                        onEdit: isAdmin ? () => onEditEvent(event) : null,
                      ),
                    ),
                  );
                }, childCount: events.length),
              ),
            ),
        ],
      ),
    );
  }
}

class _ScheduleSection extends StatelessWidget {
  const _ScheduleSection({
    required this.events,
    required this.dueReminders,
    required this.eventLookup,
    required this.onRefresh,
    required this.onOpenEvent,
  });

  final List<CampusEvent> events;
  final List<ReminderCue> dueReminders;
  final Map<String, CampusEvent> eventLookup;
  final Future<void> Function() onRefresh;
  final ValueChanged<CampusEvent> onOpenEvent;

  @override
  Widget build(BuildContext context) {
    final grouped = <DateTime, List<CampusEvent>>{};
    for (final event in events) {
      final local = event.startsAt.toLocal();
      final dayKey = DateTime(local.year, local.month, local.day);
      grouped.putIfAbsent(dayKey, () => <CampusEvent>[]).add(event);
    }

    final orderedDays = grouped.keys.toList()..sort();

    return RefreshIndicator(
      onRefresh: onRefresh,
      color: AppTheme.coral,
      child: ListView(
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
        children: <Widget>[
          Text(
            'Interactive schedule',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 6),
          Text(
            'Use the timeline to jump across dates, save stops, and track what you plan to attend.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          if (dueReminders.isNotEmpty) ...<Widget>[
            const SizedBox(height: 16),
            _ReminderCenterCard(
              cues: dueReminders,
              eventLookup: eventLookup,
              onOpenEvent: onOpenEvent,
            ),
          ],
          if (orderedDays.isEmpty) ...<Widget>[
            const SizedBox(height: 36),
            const Center(child: Text('No events match your schedule filters.')),
          ] else
            for (final day in orderedDays) ...<Widget>[
              const SizedBox(height: 20),
              Text(
                _formatScheduleDay(day),
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 10),
              for (final event in grouped[day]!) ...<Widget>[
                _ScheduleEventTile(
                  event: event,
                  onOpen: () => onOpenEvent(event),
                ),
                const SizedBox(height: 12),
              ],
            ],
        ],
      ),
    );
  }
}

class _MyEventsSection extends StatelessWidget {
  const _MyEventsSection({
    required this.trackedEvents,
    required this.dueReminders,
    required this.eventLookup,
    required this.isAdmin,
    required this.onRefresh,
    required this.onOpenEvent,
    required this.onEditEvent,
  });

  final List<CampusEvent> trackedEvents;
  final List<ReminderCue> dueReminders;
  final Map<String, CampusEvent> eventLookup;
  final bool isAdmin;
  final Future<void> Function() onRefresh;
  final ValueChanged<CampusEvent> onOpenEvent;
  final Future<void> Function([CampusEvent? event]) onEditEvent;

  @override
  Widget build(BuildContext context) {
    final interactions = context.watch<InteractionHubProvider>();

    return RefreshIndicator(
      onRefresh: onRefresh,
      color: AppTheme.coral,
      child: ListView(
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
        children: <Widget>[
          Text('My events', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 6),
          Text(
            'Everything you bookmarked, signed up for, volunteered for, waitlisted, or set reminders for lives here.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: <Widget>[
              _ActivityStat(
                label: 'Bookmarks',
                value: '${interactions.bookmarkCount}',
                color: AppTheme.cyan,
              ),
              _ActivityStat(
                label: 'Tracked',
                value: '${interactions.trackedEventCount}',
                color: AppTheme.gold,
              ),
              _ActivityStat(
                label: 'Alerts',
                value: '${dueReminders.length}',
                color: AppTheme.coral,
              ),
              _ActivityStat(
                label: 'Check-ins',
                value: '${interactions.checkedInCount}',
                color: AppTheme.mist,
              ),
            ],
          ),
          if (dueReminders.isNotEmpty) ...<Widget>[
            const SizedBox(height: 16),
            _ReminderCenterCard(
              cues: dueReminders,
              eventLookup: eventLookup,
              onOpenEvent: onOpenEvent,
            ),
          ],
          if (trackedEvents.isNotEmpty) ...<Widget>[
            const SizedBox(height: 20),
            Text('Tracked list', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 10),
            for (final event in trackedEvents) ...<Widget>[
              _EventCard(
                event: event,
                onOpen: () => onOpenEvent(event),
                onEdit: isAdmin ? () => onEditEvent(event) : null,
              ),
              const SizedBox(height: 16),
            ],
          ],
          if (trackedEvents.isEmpty) ...<Widget>[
            const SizedBox(height: 36),
            const Center(
              child: Text(
                'Start bookmarking or signing up to build your list.',
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ActivityStat extends StatelessWidget {
  const _ActivityStat({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(color: color),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}

class _ReminderCenterCard extends StatelessWidget {
  const _ReminderCenterCard({
    required this.cues,
    required this.eventLookup,
    required this.onOpenEvent,
  });

  final List<ReminderCue> cues;
  final Map<String, CampusEvent> eventLookup;
  final ValueChanged<CampusEvent> onOpenEvent;

  @override
  Widget build(BuildContext context) {
    final interactions = context.read<InteractionHubProvider>();

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.coral.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.coral.withValues(alpha: 0.28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(
                Icons.notifications_active_rounded,
                color: AppTheme.coral,
              ),
              const SizedBox(width: 10),
              Text(
                'Reminder center',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'These reminder checkpoints are active on this device.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 14),
          for (final cue in cues.take(3)) ...<Widget>[
            if (eventLookup[cue.eventId] case final event?)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        event.title,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${cue.preset.label} | ${_formatDate(event.startsAt)}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: <Widget>[
                          FilledButton.tonalIcon(
                            onPressed: () => onOpenEvent(event),
                            icon: const Icon(Icons.open_in_new_rounded),
                            label: const Text('Open'),
                          ),
                          OutlinedButton.icon(
                            onPressed: () async {
                              await interactions.dismissReminder(cue);
                              if (!context.mounted) {
                                return;
                              }
                              _showAppSnackBar(
                                context,
                                'Reminder dismissed for ${event.title}.',
                              );
                            },
                            icon: const Icon(Icons.visibility_off_rounded),
                            label: const Text('Dismiss'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _ScheduleEventTile extends StatelessWidget {
  const _ScheduleEventTile({required this.event, required this.onOpen});

  final CampusEvent event;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final interactions = context.watch<InteractionHubProvider>();
    final bookmarked = interactions.isBookmarked(event.id);
    final rsvp = interactions.rsvpFor(event.id);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Container(
          width: 78,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xCC12233B),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: Column(
            children: <Widget>[
              Text(
                _formatTimeOnly(event.startsAt),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 4),
              Text(
                _countdownLabel(event),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onOpen,
              borderRadius: BorderRadius.circular(22),
              child: Ink(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xC5122037),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: event.isEncrypted
                        ? AppTheme.coral.withValues(alpha: 0.22)
                        : AppTheme.cyan.withValues(alpha: 0.18),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            event.title,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                        if (bookmarked)
                          const Icon(
                            Icons.bookmark_rounded,
                            color: AppTheme.gold,
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${event.location} | ${_statusLabelFor(event, interactions)}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: _statusColorFor(event, interactions),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: <Widget>[
                        _MetaBadge(label: event.category, color: AppTheme.gold),
                        if (interactions.isSignedUp(event.id))
                          _MetaBadge(
                            label: interactions.isWaitlisted(event.id)
                                ? 'Waitlisted'
                                : 'Signed up',
                            color: rsvp == EventRsvpState.going
                                ? AppTheme.cyan
                                : AppTheme.coral,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _EventCard extends StatelessWidget {
  const _EventCard({required this.event, required this.onOpen, this.onEdit});

  final CampusEvent event;
  final VoidCallback onOpen;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final access = context.watch<KeyCustodianProvider>().snapshot;
    final interactions = context.watch<InteractionHubProvider>();
    final decryptedDetails = CryptoUtils.tryDecryptEvent(event, access);
    final isReadable = decryptedDetails != null;
    final bookmarked = interactions.isBookmarked(event.id);
    final reminders = interactions.remindersFor(event.id);
    final checkedIn = interactions.hasCheckedIn(event.id);
    final attendeeCount = interactions.attendeeCountFor(event);
    final waitlistCount = interactions.waitlistCountFor(event);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(30),
        child: Ink(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xC5122037),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(
              color: event.isEncrypted
                  ? AppTheme.coral.withValues(alpha: 0.24)
                  : AppTheme.cyan.withValues(alpha: 0.18),
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 18,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: <Widget>[
                            _MetaBadge(
                              label: event.category,
                              color: AppTheme.gold,
                            ),
                            _MetaBadge(
                              label: event.encryptionMode.label,
                              color: event.isEncrypted
                                  ? AppTheme.coral
                                  : AppTheme.cyan,
                            ),
                            _MetaBadge(
                              label: _statusLabelFor(event, interactions),
                              color: _statusColorFor(event, interactions),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Text(
                          event.title,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${_formatDate(event.startsAt)} | ${event.location}',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _countdownLabel(event),
                          style: Theme.of(
                            context,
                          ).textTheme.bodySmall?.copyWith(color: AppTheme.cyan),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      if (bookmarked)
                        const Padding(
                          padding: EdgeInsets.only(right: 4),
                          child: Icon(
                            Icons.bookmark_rounded,
                            color: AppTheme.gold,
                          ),
                        ),
                      if (onEdit != null)
                        IconButton(
                          tooltip: 'Edit event',
                          onPressed: onEdit,
                          icon: const Icon(Icons.edit_outlined),
                        ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(event.summary, style: Theme.of(context).textTheme.bodyLarge),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                ),
                child: Text(
                  isReadable
                      ? decryptedDetails
                      : 'Private details are hidden on this device.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: isReadable ? AppTheme.mist : const Color(0xFF91A3BA),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: <Widget>[
                  _MetaBadge(label: event.organizer, color: AppTheme.gold),
                  if (event.capacity != null)
                    _MetaBadge(
                      label: '$attendeeCount/${event.capacity} attending',
                      color: AppTheme.cyan,
                    ),
                  if (waitlistCount > 0)
                    _MetaBadge(
                      label: '$waitlistCount waitlisted',
                      color: AppTheme.coral,
                    ),
                  if (reminders.isNotEmpty)
                    _MetaBadge(
                      label: '${reminders.length} reminders',
                      color: AppTheme.mist,
                    ),
                  if (checkedIn)
                    const _MetaBadge(label: 'Checked in', color: AppTheme.cyan),
                ],
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: <Widget>[
                  FilterChip(
                    avatar: Icon(
                      bookmarked
                          ? Icons.bookmark_rounded
                          : Icons.bookmark_border_rounded,
                      size: 18,
                    ),
                    label: Text(bookmarked ? 'Bookmarked' : 'Bookmark'),
                    selected: bookmarked,
                    onSelected: (_) async {
                      await interactions.toggleBookmark(event.id);
                      if (!context.mounted) {
                        return;
                      }
                      _showAppSnackBar(
                        context,
                        bookmarked
                            ? 'Removed ${event.title} from your bookmarks.'
                            : 'Bookmarked ${event.title}.',
                      );
                    },
                  ),
                  ChoiceChip(
                    avatar: Icon(
                      _signupActionIcon(event, interactions),
                      size: 18,
                    ),
                    label: Text(_signupActionLabel(event, interactions)),
                    selected: interactions.isSignedUp(event.id),
                    onSelected: (_) async {
                      final result = await interactions.toggleSignup(event);
                      if (!context.mounted) {
                        return;
                      }
                      _showAppSnackBar(context, result.message);
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FilterRail extends StatelessWidget {
  const _FilterRail({
    required this.filter,
    required this.isAdmin,
    required this.onChanged,
  });

  final EventFeedFilter filter;
  final bool isAdmin;
  final ValueChanged<EventFeedFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: <Widget>[
        _FilterChipButton(
          label: 'All',
          selected: filter == EventFeedFilter.all,
          onTap: () => onChanged(EventFeedFilter.all),
        ),
        _FilterChipButton(
          label: 'Public',
          selected: filter == EventFeedFilter.publicOnly,
          onTap: () => onChanged(EventFeedFilter.publicOnly),
        ),
        if (isAdmin)
          _FilterChipButton(
            label: 'Private',
            selected: filter == EventFeedFilter.secureOnly,
            onTap: () => onChanged(EventFeedFilter.secureOnly),
          ),
      ],
    );
  }
}

class _FilterChipButton extends StatelessWidget {
  const _FilterChipButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: selected
              ? AppTheme.cyan.withValues(alpha: 0.18)
              : Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected
                ? AppTheme.cyan.withValues(alpha: 0.34)
                : Colors.white.withValues(alpha: 0.08),
          ),
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: selected ? AppTheme.cyan : const Color(0xFFD7E4EF),
          ),
        ),
      ),
    );
  }
}

class _ModeBadge extends StatelessWidget {
  const _ModeBadge({required this.modeLabel});

  final String modeLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.cyan.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.cyan.withValues(alpha: 0.26)),
      ),
      child: Text(
        modeLabel,
        style: Theme.of(
          context,
        ).textTheme.labelLarge?.copyWith(fontSize: 12, color: AppTheme.cyan),
      ),
    );
  }
}

class _MetaBadge extends StatelessWidget {
  const _MetaBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(
          context,
        ).textTheme.labelLarge?.copyWith(color: color, fontSize: 11),
      ),
    );
  }
}

class _AccessConsoleSheet extends StatefulWidget {
  const _AccessConsoleSheet();

  @override
  State<_AccessConsoleSheet> createState() => _AccessConsoleSheetState();
}

class _AccessConsoleSheetState extends State<_AccessConsoleSheet> {
  late final TextEditingController _aesController = TextEditingController();

  @override
  void dispose() {
    _aesController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final provider = context.read<KeyCustodianProvider>();
    final result = await provider.storePassphrase(
      aesPassphrase: _aesController.text,
    );

    if (!mounted) {
      return;
    }

    _showAppSnackBar(context, result.message);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<KeyCustodianProvider>();
    final feed = context.watch<EventFeedProvider>();
    final interactions = context.watch<InteractionHubProvider>();
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        decoration: const BoxDecoration(
          color: Color(0xFF0C1422),
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 22),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Center(
                    child: Container(
                      width: 54,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Access settings',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Store the admin passphrase for this device here.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 18),
                  _MetaBadge(
                    label: provider.modeLabel,
                    color: provider.isAdmin ? AppTheme.cyan : AppTheme.gold,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _aesController,
                    decoration: const InputDecoration(
                      labelText: 'Admin passphrase',
                      hintText: 'Enter the admin passphrase',
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: FilledButton(
                          onPressed: _save,
                          child: const Text('Save Access'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () async {
                            await provider.clearAllSecrets();
                            if (!context.mounted) {
                              return;
                            }
                            _showAppSnackBar(
                              context,
                              'Access cleared from this device.',
                            );
                          },
                          child: const Text('Clear Access'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Activity snapshot',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: <Widget>[
                      _ActivityStat(
                        label: 'Public',
                        value: '${feed.publicCount}',
                        color: AppTheme.cyan,
                      ),
                      _ActivityStat(
                        label: 'Private',
                        value: '${feed.secureCount}',
                        color: AppTheme.coral,
                      ),
                      _ActivityStat(
                        label: 'Tracked',
                        value: '${interactions.trackedEventCount}',
                        color: AppTheme.gold,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _EventComposerSheet extends StatefulWidget {
  const _EventComposerSheet({this.initialEvent});

  final CampusEvent? initialEvent;

  @override
  State<_EventComposerSheet> createState() => _EventComposerSheetState();
}

class _EventComposerSheetState extends State<_EventComposerSheet> {
  late final TextEditingController _titleController;
  late final TextEditingController _organizerController;
  late final TextEditingController _categoryController;
  late final TextEditingController _locationController;
  late final TextEditingController _summaryController;
  late final TextEditingController _detailsController;
  late final TextEditingController _durationController;
  late final TextEditingController _capacityController;
  late final TextEditingController _attendeeCountController;
  late final TextEditingController _waitlistCountController;
  late final TextEditingController _pollQuestionController;
  late final TextEditingController _pollOptionsController;
  late final TextEditingController _volunteerSlotsController;

  late DateTime _startsAt;
  late EventEncryptionMode _mode;
  late EventStatus _status;

  @override
  void initState() {
    super.initState();
    final access = context.read<KeyCustodianProvider>();
    final event = widget.initialEvent;

    _titleController = TextEditingController(text: event?.title ?? '');
    _organizerController = TextEditingController(text: event?.organizer ?? '');
    _categoryController = TextEditingController(text: event?.category ?? '');
    _locationController = TextEditingController(text: event?.location ?? '');
    _summaryController = TextEditingController(text: event?.summary ?? '');
    _detailsController = TextEditingController(
      text: event == null ? '' : access.revealDetails(event) ?? event.summary,
    );
    _durationController = TextEditingController(
      text: '${event?.durationMinutes ?? 120}',
    );
    _capacityController = TextEditingController(
      text: event?.capacity?.toString() ?? '',
    );
    _attendeeCountController = TextEditingController(
      text: '${event?.baseAttendeeCount ?? 0}',
    );
    _waitlistCountController = TextEditingController(
      text: '${event?.baseWaitlistCount ?? 0}',
    );
    _pollQuestionController = TextEditingController(
      text: event?.poll?.question ?? '',
    );
    _pollOptionsController = TextEditingController(
      text: event?.poll?.options.map((option) => option.label).join(', ') ?? '',
    );
    _volunteerSlotsController = TextEditingController(
      text:
          event?.volunteerSlots
              .map((slot) => '${slot.label}:${slot.capacity}')
              .join(', ') ??
          '',
    );
    _startsAt = event?.startsAt ?? DateTime.now().add(const Duration(days: 1));
    _mode = _resolveInitialMode(access.snapshot, event?.encryptionMode);
    _status = event?.status ?? EventStatus.scheduled;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _organizerController.dispose();
    _categoryController.dispose();
    _locationController.dispose();
    _summaryController.dispose();
    _detailsController.dispose();
    _durationController.dispose();
    _capacityController.dispose();
    _attendeeCountController.dispose();
    _waitlistCountController.dispose();
    _pollQuestionController.dispose();
    _pollOptionsController.dispose();
    _volunteerSlotsController.dispose();
    super.dispose();
  }

  EventEncryptionMode _resolveInitialMode(
    CustodianAccessSnapshot access,
    EventEncryptionMode? candidate,
  ) {
    if (candidate == EventEncryptionMode.aes && !access.hasAesAccess) {
      return EventEncryptionMode.public;
    }
    return candidate ?? EventEncryptionMode.public;
  }

  Future<void> _pickDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _startsAt,
      firstDate: DateTime(2025),
      lastDate: DateTime(2035),
    );
    if (date == null || !mounted) {
      return;
    }

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_startsAt),
    );
    if (time == null) {
      return;
    }

    setState(() {
      _startsAt = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  EventPoll? _buildPoll(EventPoll? existingPoll) {
    final question = _pollQuestionController.text.trim();
    final optionLabels = _pollOptionsController.text
        .split(',')
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toList();

    if (question.isEmpty && optionLabels.isEmpty) {
      return null;
    }

    if (question.isEmpty || optionLabels.length < 2) {
      throw StateError('Add a poll question and at least two options.');
    }

    final existingByLabel = <String, EventPollOption>{
      for (final option in existingPoll?.options ?? const <EventPollOption>[])
        option.label.toLowerCase(): option,
    };

    return EventPoll(
      question: question,
      options: optionLabels.map((label) {
        final existing = existingByLabel[label.toLowerCase()];
        return EventPollOption(
          id: existing?.id ?? _slugify('$question-$label'),
          label: label,
          votes: existing?.votes ?? 0,
        );
      }).toList(),
    );
  }

  List<VolunteerSlot> _buildVolunteerSlots(List<VolunteerSlot> existingSlots) {
    final raw = _volunteerSlotsController.text.trim();
    if (raw.isEmpty) {
      return const <VolunteerSlot>[];
    }

    final existingByLabel = <String, VolunteerSlot>{
      for (final slot in existingSlots) slot.label.toLowerCase(): slot,
    };

    return raw.split(',').map((entry) {
      final parts = entry.split(':');
      if (parts.length != 2) {
        throw StateError(
          'Volunteer slots must use the format Name:capacity, Name:capacity.',
        );
      }

      final label = parts.first.trim();
      final capacity = int.tryParse(parts.last.trim());
      if (label.isEmpty || capacity == null || capacity <= 0) {
        throw StateError(
          'Volunteer slots must use a positive capacity, for example Check-in desk:4.',
        );
      }

      final existing = existingByLabel[label.toLowerCase()];
      return VolunteerSlot(
        id: existing?.id ?? _slugify(label),
        label: label,
        capacity: capacity,
        filled: existing?.filled ?? 0,
      );
    }).toList();
  }

  Future<void> _save() async {
    final access = context.read<KeyCustodianProvider>().snapshot;
    final feed = context.read<EventFeedProvider>();
    final event = widget.initialEvent;

    if (_titleController.text.trim().isEmpty ||
        _organizerController.text.trim().isEmpty ||
        _categoryController.text.trim().isEmpty ||
        _locationController.text.trim().isEmpty ||
        _summaryController.text.trim().isEmpty ||
        _detailsController.text.trim().isEmpty) {
      _showAppSnackBar(context, 'Fill in all event fields first.');
      return;
    }

    final duration = int.tryParse(_durationController.text.trim()) ?? 120;
    final capacityText = _capacityController.text.trim();
    final capacity = capacityText.isEmpty ? null : int.tryParse(capacityText);
    final attendeeCount =
        int.tryParse(_attendeeCountController.text.trim()) ?? 0;
    final waitlistCount =
        int.tryParse(_waitlistCountController.text.trim()) ?? 0;

    if (duration <= 0) {
      _showAppSnackBar(context, 'Duration must be greater than zero.');
      return;
    }

    if (capacity != null && capacity <= 0) {
      _showAppSnackBar(context, 'Capacity must be a positive number.');
      return;
    }

    try {
      await feed.saveEvent(
        EventDraft(
          id: event?.id,
          title: _titleController.text,
          organizer: _organizerController.text,
          category: _categoryController.text,
          location: _locationController.text,
          startsAt: _startsAt,
          summary: _summaryController.text,
          details: _detailsController.text,
          encryptionMode: _mode,
          durationMinutes: duration,
          capacity: capacity,
          baseAttendeeCount: attendeeCount,
          baseWaitlistCount: waitlistCount,
          status: _status,
          reactionCounts: event?.reactionCounts ?? const <String, int>{},
          poll: _buildPoll(event?.poll),
          volunteerSlots: _buildVolunteerSlots(
            event?.volunteerSlots ?? const [],
          ),
        ),
        access,
      );

      if (!mounted) {
        return;
      }

      Navigator.of(context).pop();
      _showAppSnackBar(
        context,
        widget.initialEvent == null
            ? 'Event published to the feed.'
            : 'Event updated successfully.',
      );
    } catch (error) {
      _showAppSnackBar(context, error.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final access = context.watch<KeyCustodianProvider>().snapshot;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    final modes = <EventEncryptionMode>[
      EventEncryptionMode.public,
      if (access.hasAesAccess) EventEncryptionMode.aes,
    ];

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        decoration: const BoxDecoration(
          color: Color(0xFF0C1422),
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    widget.initialEvent == null ? 'Create Event' : 'Edit Event',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Configure the event, attendance settings, live status, poll, and volunteer workflow before publishing.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 18),
                  TextField(
                    controller: _titleController,
                    decoration: const InputDecoration(labelText: 'Title'),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _organizerController,
                    decoration: const InputDecoration(labelText: 'Organizer'),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _categoryController,
                    decoration: const InputDecoration(labelText: 'Category'),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _locationController,
                    decoration: const InputDecoration(labelText: 'Location'),
                  ),
                  const SizedBox(height: 14),
                  InkWell(
                    borderRadius: BorderRadius.circular(18),
                    onTap: _pickDateTime,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xCC12233B),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.1),
                        ),
                      ),
                      child: Text(
                        'Starts at ${_formatDate(_startsAt)}',
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: modes
                        .map(
                          (mode) => ChoiceChip(
                            label: Text(mode.label),
                            selected: _mode == mode,
                            onSelected: (_) => setState(() => _mode = mode),
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: EventStatus.values
                        .map(
                          (status) => ChoiceChip(
                            label: Text(status.label),
                            selected: _status == status,
                            onSelected: (_) => setState(() => _status = status),
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _summaryController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Public Summary',
                      hintText: 'Visible to every user in the feed',
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _detailsController,
                    minLines: 4,
                    maxLines: 8,
                    decoration: InputDecoration(
                      labelText: _mode == EventEncryptionMode.public
                          ? 'Details'
                          : 'Private Details',
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _durationController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Duration in minutes',
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _capacityController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Capacity (optional)',
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _attendeeCountController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Current confirmed attendees',
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _waitlistCountController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Current waitlist count',
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _pollQuestionController,
                    decoration: const InputDecoration(
                      labelText: 'Poll question (optional)',
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _pollOptionsController,
                    decoration: const InputDecoration(
                      labelText: 'Poll options (comma separated)',
                      hintText:
                          'AI for campus life, Sustainability systems, Mobility',
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _volunteerSlotsController,
                    decoration: const InputDecoration(
                      labelText: 'Volunteer slots',
                      hintText: 'Check-in desk:4, Stage runner:2',
                    ),
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _save,
                      icon: const Icon(Icons.publish_rounded),
                      label: Text(
                        widget.initialEvent == null
                            ? 'Publish Event'
                            : 'Save Changes',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _EventDetailsSheet extends StatefulWidget {
  const _EventDetailsSheet({required this.event});

  final CampusEvent event;

  @override
  State<_EventDetailsSheet> createState() => _EventDetailsSheetState();
}

class _EventDetailsSheetState extends State<_EventDetailsSheet> {
  late final TextEditingController _noteController;
  late final TextEditingController _commentController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final note = context.read<InteractionHubProvider>().noteFor(
      widget.event.id,
    );
    _noteController = TextEditingController(text: note);
  }

  @override
  void dispose() {
    _noteController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final access = context.watch<KeyCustodianProvider>().snapshot;
    final interactions = context.watch<InteractionHubProvider>();
    final details = CryptoUtils.tryDecryptEvent(widget.event, access);
    final reminders = interactions.remindersFor(widget.event.id);
    final reactions = interactions.reactionsFor(widget.event.id);
    final attendeeCount = interactions.attendeeCountFor(widget.event);
    final waitlistCount = interactions.waitlistCountFor(widget.event);
    final comments = interactions.commentsFor(widget.event.id);
    final checkedIn = interactions.hasCheckedIn(widget.event.id);

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF0C1422),
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Center(
                  child: Container(
                    width: 54,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  widget.event.title,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: <Widget>[
                    _MetaBadge(
                      label: widget.event.category,
                      color: AppTheme.gold,
                    ),
                    _MetaBadge(
                      label: widget.event.encryptionMode.description,
                      color: widget.event.isEncrypted
                          ? AppTheme.coral
                          : AppTheme.cyan,
                    ),
                    _MetaBadge(
                      label: _statusLabelFor(widget.event, interactions),
                      color: _statusColorFor(widget.event, interactions),
                    ),
                    if (checkedIn)
                      const _MetaBadge(
                        label: 'Checked in',
                        color: AppTheme.cyan,
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  '${widget.event.organizer} | ${_formatDate(widget.event.startsAt)} | ${widget.event.location}',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 6),
                Text(
                  _countdownLabel(widget.event),
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: AppTheme.cyan),
                ),
                const SizedBox(height: 18),
                Text(
                  widget.event.summary,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xCC12233B),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.08),
                    ),
                  ),
                  child: Text(
                    details ?? 'Private details are hidden on this device.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: details == null
                          ? const Color(0xFF91A3BA)
                          : AppTheme.mist,
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: <Widget>[
                    FilterChip(
                      avatar: Icon(
                        interactions.isBookmarked(widget.event.id)
                            ? Icons.bookmark_rounded
                            : Icons.bookmark_border_rounded,
                        size: 18,
                      ),
                      label: Text(
                        interactions.isBookmarked(widget.event.id)
                            ? 'Bookmarked'
                            : 'Bookmark',
                      ),
                      selected: interactions.isBookmarked(widget.event.id),
                      onSelected: (_) async {
                        final saved = interactions.isBookmarked(
                          widget.event.id,
                        );
                        await interactions.toggleBookmark(widget.event.id);
                        if (!context.mounted) {
                          return;
                        }
                        _showAppSnackBar(
                          context,
                          saved
                              ? 'Removed ${widget.event.title} from your bookmarks.'
                              : 'Bookmarked ${widget.event.title}.',
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                Text(
                  'Attendance',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 10),
                if (widget.event.capacity != null) ...<Widget>[
                  LinearProgressIndicator(
                    value: (attendeeCount / widget.event.capacity!).clamp(0, 1),
                    minHeight: 10,
                    backgroundColor: Colors.white.withValues(alpha: 0.08),
                    color: AppTheme.cyan,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '$attendeeCount of ${widget.event.capacity} confirmed | $waitlistCount waitlisted',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 14),
                ],
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: <Widget>[
                    ChoiceChip(
                      avatar: Icon(
                        _signupActionIcon(widget.event, interactions),
                        size: 18,
                      ),
                      label: Text(
                        _signupActionLabel(widget.event, interactions),
                      ),
                      selected: interactions.isSignedUp(widget.event.id),
                      onSelected: (_) async {
                        final result = await interactions.toggleSignup(
                          widget.event,
                        );
                        if (!context.mounted) {
                          return;
                        }
                        _showAppSnackBar(context, result.message);
                      },
                    ),
                  ],
                ),
                if (interactions.isWaitlisted(widget.event.id)) ...<Widget>[
                  const SizedBox(height: 10),
                  Text(
                    'You are currently on the waitlist for this event.',
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: AppTheme.coral),
                  ),
                ],
                const SizedBox(height: 16),
                TextField(
                  controller: _noteController,
                  minLines: 2,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: access.isAdmin
                        ? 'Private admin note'
                        : 'Private note on this device',
                  ),
                ),
                const SizedBox(height: 10),
                FilledButton.tonal(
                  onPressed: () async {
                    await interactions.savePrivateNote(
                      widget.event.id,
                      _noteController.text,
                    );
                    if (!context.mounted) {
                      return;
                    }
                    _showAppSnackBar(context, 'Private note updated.');
                  },
                  child: const Text('Save note'),
                ),
                const SizedBox(height: 18),
                Text(
                  'Reminders',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: ReminderPreset.values
                      .map(
                        (preset) => FilterChip(
                          label: Text(preset.label),
                          selected: reminders.contains(preset),
                          onSelected: (_) async {
                            await interactions.toggleReminder(
                              widget.event.id,
                              preset,
                            );
                            if (!context.mounted) {
                              return;
                            }
                            _showAppSnackBar(
                              context,
                              reminders.contains(preset)
                                  ? 'Reminder removed.'
                                  : 'Reminder saved for ${preset.label.toLowerCase()}.',
                            );
                          },
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 22),
                Text(
                  'Reactions',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: ReactionKind.values
                      .map(
                        (kind) => FilterChip(
                          label: Text(
                            '${kind.label} ${interactions.reactionCountFor(widget.event, kind)}',
                          ),
                          selected: reactions.contains(kind),
                          avatar: Icon(_reactionIcon(kind), size: 18),
                          onSelected: (_) async {
                            await interactions.toggleReaction(
                              widget.event.id,
                              kind,
                            );
                          },
                        ),
                      )
                      .toList(),
                ),
                if (widget.event.poll != null) ...<Widget>[
                  const SizedBox(height: 22),
                  Text('Poll', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 10),
                  Text(
                    widget.event.poll!.question,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 12),
                  for (final option in widget.event.poll!.options) ...<Widget>[
                    InkWell(
                      borderRadius: BorderRadius.circular(18),
                      onTap: () async {
                        final result = await interactions.voteOnPoll(
                          widget.event,
                          option.id,
                        );
                        if (!context.mounted) {
                          return;
                        }
                        _showAppSnackBar(context, result.message);
                      },
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        margin: const EdgeInsets.only(bottom: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xCC12233B),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color:
                                interactions.selectedPollOption(
                                      widget.event.id,
                                    ) ==
                                    option.id
                                ? AppTheme.cyan
                                : Colors.white.withValues(alpha: 0.08),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              option.label,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 8),
                            LinearProgressIndicator(
                              value: _pollProgress(
                                widget.event,
                                option,
                                interactions,
                              ),
                              minHeight: 8,
                              backgroundColor: Colors.white.withValues(
                                alpha: 0.08,
                              ),
                              color: AppTheme.cyan,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '${interactions.pollVotesFor(widget.event, option)} votes',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
                if (widget.event.volunteerSlots.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 22),
                  Text(
                    'Volunteer slots',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 10),
                  for (final slot in widget.event.volunteerSlots) ...<Widget>[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      margin: const EdgeInsets.only(bottom: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xCC12233B),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.08),
                        ),
                      ),
                      child: Row(
                        children: <Widget>[
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  slot.label,
                                  style: Theme.of(
                                    context,
                                  ).textTheme.titleMedium,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${interactions.volunteerCountFor(widget.event, slot)}/${slot.capacity} filled',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                          FilledButton.tonal(
                            onPressed: () async {
                              final result = await interactions
                                  .toggleVolunteerSlot(widget.event, slot);
                              if (!context.mounted) {
                                return;
                              }
                              _showAppSnackBar(context, result.message);
                            },
                            child: Text(
                              interactions
                                      .volunteerSelectionsFor(widget.event.id)
                                      .contains(slot.id)
                                  ? 'Leave'
                                  : 'Join',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
                const SizedBox(height: 22),
                Text(
                  'Comments and Q&A',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 10),
                if (comments.isEmpty)
                  const Text('No comments yet. Start the thread.')
                else
                  for (final comment in comments) ...<Widget>[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      margin: const EdgeInsets.only(bottom: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xCC12233B),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: comment.isAdminReply
                              ? AppTheme.cyan.withValues(alpha: 0.24)
                              : Colors.white.withValues(alpha: 0.08),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            comment.authorLabel,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            comment.message,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _formatCommentTimestamp(comment.createdAt),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                TextField(
                  controller: _commentController,
                  minLines: 2,
                  maxLines: 4,
                  decoration: InputDecoration(
                    labelText: access.isAdmin
                        ? 'Reply as organizer'
                        : 'Ask a question or leave a comment',
                  ),
                ),
                const SizedBox(height: 10),
                FilledButton.tonal(
                  onPressed: () async {
                    final result = await interactions.addComment(
                      eventId: widget.event.id,
                      authorLabel: access.isAdmin ? 'Organizer' : 'You',
                      message: _commentController.text,
                      isAdminReply: access.isAdmin,
                    );
                    if (!context.mounted) {
                      return;
                    }
                    _showAppSnackBar(context, result.message);
                    if (result.accepted) {
                      _commentController.clear();
                    }
                  },
                  child: Text(access.isAdmin ? 'Post reply' : 'Post comment'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DelayedReveal extends StatefulWidget {
  const _DelayedReveal({required this.child, required this.delay});

  final Widget child;
  final Duration delay;

  @override
  State<_DelayedReveal> createState() => _DelayedRevealState();
}

class _DelayedRevealState extends State<_DelayedReveal> {
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    Future<void>.delayed(widget.delay, () {
      if (mounted) {
        setState(() => _visible = true);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSlide(
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
      offset: _visible ? Offset.zero : const Offset(0, 0.08),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOutCubic,
        opacity: _visible ? 1 : 0,
        child: widget.child,
      ),
    );
  }
}

double _pollProgress(
  CampusEvent event,
  EventPollOption option,
  InteractionHubProvider interactions,
) {
  final poll = event.poll;
  if (poll == null || poll.options.isEmpty) {
    return 0;
  }

  var total = 0;
  for (final entry in poll.options) {
    total += interactions.pollVotesFor(event, entry);
  }
  if (total == 0) {
    return 0;
  }
  return interactions.pollVotesFor(event, option) / total;
}

Color _statusColorFor(CampusEvent event, InteractionHubProvider interactions) {
  final status = _statusLabelFor(event, interactions);
  switch (status) {
    case 'Delayed':
    case 'Full':
      return AppTheme.coral;
    case 'Live':
    case 'Starting soon':
      return AppTheme.cyan;
    case 'Venue moved':
      return AppTheme.gold;
    case 'Completed':
    case 'Ended':
      return const Color(0xFF9AAFC3);
    default:
      return AppTheme.mist;
  }
}

String _statusLabelFor(CampusEvent event, InteractionHubProvider interactions) {
  final now = DateTime.now();
  final localStart = event.startsAt.toLocal();
  final localEnd = localStart.add(Duration(minutes: event.durationMinutes));

  if (event.status == EventStatus.completed) {
    return 'Completed';
  }
  if (event.status == EventStatus.delayed) {
    return 'Delayed';
  }
  if (event.status == EventStatus.moved) {
    return 'Venue moved';
  }
  if (event.status == EventStatus.live) {
    return 'Live';
  }
  if (event.capacity != null &&
      interactions.attendeeCountFor(event) >= event.capacity! &&
      interactions.rsvpFor(event.id) != EventRsvpState.going) {
    return 'Full';
  }
  if (now.isAfter(localEnd)) {
    return 'Ended';
  }
  if (!now.isBefore(localStart.subtract(const Duration(minutes: 15))) &&
      now.isBefore(localEnd)) {
    return 'Live';
  }
  if (!now.isBefore(localStart.subtract(const Duration(hours: 4))) &&
      now.isBefore(localStart)) {
    return 'Starting soon';
  }
  return event.status.label;
}

String _signupActionLabel(
  CampusEvent event,
  InteractionHubProvider interactions,
) {
  if (interactions.isWaitlisted(event.id)) {
    return 'Waitlisted';
  }
  if (interactions.rsvpFor(event.id) == EventRsvpState.going) {
    return 'Signed up';
  }
  if (interactions.isEventFull(event)) {
    return 'Join waitlist';
  }
  return 'Sign up';
}

IconData _signupActionIcon(
  CampusEvent event,
  InteractionHubProvider interactions,
) {
  if (interactions.isWaitlisted(event.id)) {
    return Icons.hourglass_top_rounded;
  }
  if (interactions.rsvpFor(event.id) == EventRsvpState.going) {
    return Icons.check_circle_rounded;
  }
  if (interactions.isEventFull(event)) {
    return Icons.schedule_rounded;
  }
  return Icons.app_registration_rounded;
}

String _countdownLabel(CampusEvent event) {
  final now = DateTime.now();
  final localStart = event.startsAt.toLocal();
  final localEnd = localStart.add(Duration(minutes: event.durationMinutes));
  if (now.isAfter(localEnd)) {
    return 'Ended';
  }
  if (now.isAfter(localStart)) {
    return 'Live now';
  }

  final diff = localStart.difference(now);
  if (diff.inDays >= 1) {
    final hours = diff.inHours % 24;
    return 'Starts in ${diff.inDays}d ${hours}h';
  }
  if (diff.inHours >= 1) {
    final minutes = diff.inMinutes % 60;
    return 'Starts in ${diff.inHours}h ${minutes}m';
  }
  return 'Starts in ${diff.inMinutes.clamp(0, 59)}m';
}

String _formatDate(DateTime value) {
  const months = <String>[
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  final local = value.toLocal();
  final month = months[local.month - 1];
  final hour = local.hour == 0
      ? 12
      : (local.hour > 12 ? local.hour - 12 : local.hour);
  final minute = local.minute.toString().padLeft(2, '0');
  final suffix = local.hour >= 12 ? 'PM' : 'AM';

  return '$month ${local.day}, ${local.year} | $hour:$minute $suffix';
}

String _formatTimeOnly(DateTime value) {
  final local = value.toLocal();
  final hour = local.hour == 0
      ? 12
      : (local.hour > 12 ? local.hour - 12 : local.hour);
  final minute = local.minute.toString().padLeft(2, '0');
  final suffix = local.hour >= 12 ? 'PM' : 'AM';
  return '$hour:$minute\n$suffix';
}

String _formatScheduleDay(DateTime value) {
  const months = <String>[
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];
  return '${months[value.month - 1]} ${value.day}, ${value.year}';
}

String _formatCommentTimestamp(DateTime value) {
  final local = value.toLocal();
  return '${_formatScheduleDay(DateTime(local.year, local.month, local.day))} at ${_formatTimeOnly(local).replaceAll('\n', ' ')}';
}

IconData _reactionIcon(ReactionKind kind) {
  switch (kind) {
    case ReactionKind.clap:
      return Icons.celebration_rounded;
    case ReactionKind.fire:
      return Icons.local_fire_department_rounded;
    case ReactionKind.star:
      return Icons.star_rounded;
  }
}

void _showAppSnackBar(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}

String _slugify(String value) {
  return value
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'-+'), '-')
      .replaceAll(RegExp(r'^-|-$'), '');
}
