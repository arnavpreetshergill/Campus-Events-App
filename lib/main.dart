import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:provider/provider.dart';

import 'crypto_utils.dart';
import 'event_feed_provider.dart';
import 'key_custodian_provider.dart';
import 'models/campus_event.dart';
import 'models/custodian_access.dart';
import 'services/local_event_repository.dart';
import 'theme/app_theme.dart';
import 'widgets/aurora_background.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const DecentralizedCampusApp());
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

  @override
  Widget build(BuildContext context) {
    final access = context.watch<KeyCustodianProvider>();

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
                ),
                Expanded(
                  child: _FeedScreen(
                    key: const ValueKey<String>('feed'),
                    onCompose: _openComposer,
                    onOpenEvent: _showEventDetails,
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
  const _TopBar({required this.onOpenConsole, required this.isAdmin});

  final VoidCallback onOpenConsole;
  final bool isAdmin;

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
                      'See what is happening around campus.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: const Color(0xFF8EA8C0),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (isAdmin) ...<Widget>[
              const SizedBox(width: 12),
              _ModeBadge(modeLabel: 'Admin'),
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

class _FeedScreen extends StatelessWidget {
  const _FeedScreen({
    super.key,
    required this.onCompose,
    required this.onOpenEvent,
  });

  final Future<void> Function([CampusEvent? event]) onCompose;
  final ValueChanged<CampusEvent> onOpenEvent;

  @override
  Widget build(BuildContext context) {
    final feed = context.watch<EventFeedProvider>();
    final access = context.watch<KeyCustodianProvider>();

    return RefreshIndicator(
      onRefresh: feed.refresh,
      color: AppTheme.coral,
      child: CustomScrollView(
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
                    access.isAdmin
                        ? 'You can manage events and view protected details on this device.'
                        : 'Browse public updates and open event details.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 16),
                  _FilterRail(filter: feed.filter, onChanged: feed.setFilter),
                  const SizedBox(height: 10),
                ],
              ),
            ),
          ),
          if (feed.isLoading)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(child: CircularProgressIndicator()),
            )
          else if (feed.errorMessage != null)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(feed.errorMessage!),
                ),
              ),
            )
          else if (feed.filteredEvents.isEmpty)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Text('No events available for the current filter.'),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
              sliver: SliverList.builder(
                itemCount: feed.filteredEvents.length,
                itemBuilder: (context, index) {
                  final event = feed.filteredEvents[index];
                  return _DelayedReveal(
                    delay: Duration(milliseconds: 70 * index),
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: _EventCard(
                        event: event,
                        access: access.snapshot,
                        onOpen: () => onOpenEvent(event),
                        onEdit:
                            access.isAdmin &&
                                (!event.isEncrypted ||
                                    access.canReadEvent(event))
                            ? () => onCompose(event)
                            : null,
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _FilterRail extends StatelessWidget {
  const _FilterRail({required this.filter, required this.onChanged});

  final EventFeedFilter filter;
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
        _FilterChipButton(
          label: 'Encrypted',
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

class _EventCard extends StatelessWidget {
  const _EventCard({
    required this.event,
    required this.access,
    required this.onOpen,
    this.onEdit,
  });

  final CampusEvent event;
  final CustodianAccessSnapshot access;
  final VoidCallback onOpen;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final decryptedDetails = CryptoUtils.tryDecryptEvent(event, access);
    final isReadable = decryptedDetails != null;

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
                      ],
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
              Row(
                children: <Widget>[
                  Text(
                    event.organizer,
                    style: Theme.of(
                      context,
                    ).textTheme.labelLarge?.copyWith(color: AppTheme.gold),
                  ),
                  const Spacer(),
                  Text(
                    isReadable ? 'Details available' : 'Private details',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: const Color(0xFF8EA8C0),
                    ),
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
  late final TextEditingController _rsaController = TextEditingController();

  @override
  void dispose() {
    _aesController.dispose();
    _rsaController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final provider = context.read<KeyCustodianProvider>();
    final result = await provider.storeSecrets(
      aesPassphrase: _aesController.text,
      rsaPrivateKeyPem: _rsaController.text,
    );

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(result.message)));
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<KeyCustodianProvider>();
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
                    'Store admin credentials on this device to unlock private event details and event management.',
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
                      hintText: 'Enter the shared admin passphrase',
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _rsaController,
                    minLines: 4,
                    maxLines: 10,
                    decoration: const InputDecoration(
                      labelText: 'Private key',
                      hintText: 'Paste the admin private key',
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
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Access cleared from this device.',
                                ),
                              ),
                            );
                          },
                          child: const Text('Clear Access'),
                        ),
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

  late DateTime _startsAt;
  late EventEncryptionMode _mode;

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
    _startsAt = event?.startsAt ?? DateTime.now().add(const Duration(days: 1));
    _mode = _resolveInitialMode(access.snapshot, event?.encryptionMode);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _organizerController.dispose();
    _categoryController.dispose();
    _locationController.dispose();
    _summaryController.dispose();
    _detailsController.dispose();
    super.dispose();
  }

  EventEncryptionMode _resolveInitialMode(
    CustodianAccessSnapshot access,
    EventEncryptionMode? candidate,
  ) {
    if (candidate == EventEncryptionMode.aes && !access.hasAesAccess) {
      return EventEncryptionMode.public;
    }
    if (candidate == EventEncryptionMode.rsaEnvelope && !access.hasRsaAccess) {
      return EventEncryptionMode.public;
    }
    return candidate ?? EventEncryptionMode.public;
  }

  Future<void> _pickDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _startsAt,
      firstDate: DateTime(2025),
      lastDate: DateTime(2032),
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

  Future<void> _save() async {
    final access = context.read<KeyCustodianProvider>().snapshot;
    final feed = context.read<EventFeedProvider>();

    if (_titleController.text.trim().isEmpty ||
        _organizerController.text.trim().isEmpty ||
        _categoryController.text.trim().isEmpty ||
        _locationController.text.trim().isEmpty ||
        _summaryController.text.trim().isEmpty ||
        _detailsController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Fill in all event fields first.')),
      );
      return;
    }

    try {
      await feed.saveEvent(
        EventDraft(
          id: widget.initialEvent?.id,
          title: _titleController.text,
          organizer: _organizerController.text,
          category: _categoryController.text,
          location: _locationController.text,
          startsAt: _startsAt,
          summary: _summaryController.text,
          details: _detailsController.text,
          encryptionMode: _mode,
        ),
        access,
      );

      if (!mounted) {
        return;
      }

      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.initialEvent == null
                ? 'Event published to the feed.'
                : 'Event updated successfully.',
          ),
        ),
      );
    } catch (error) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    final access = context.watch<KeyCustodianProvider>().snapshot;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    final modes = <EventEncryptionMode>[
      EventEncryptionMode.public,
      if (access.hasAesAccess) EventEncryptionMode.aes,
      if (access.hasRsaAccess) EventEncryptionMode.rsaEnvelope,
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
                    'Choose how event details should be shared before publishing.',
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

class _EventDetailsSheet extends StatelessWidget {
  const _EventDetailsSheet({required this.event});

  final CampusEvent event;

  @override
  Widget build(BuildContext context) {
    final access = context.watch<KeyCustodianProvider>().snapshot;
    final details = CryptoUtils.tryDecryptEvent(event, access);

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF0C1422),
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
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
                event.title,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: <Widget>[
                  _MetaBadge(label: event.category, color: AppTheme.gold),
                  _MetaBadge(
                    label: event.encryptionMode.description,
                    color: event.isEncrypted ? AppTheme.coral : AppTheme.cyan,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(event.summary, style: Theme.of(context).textTheme.bodyLarge),
              const SizedBox(height: 16),
              Text(
                details ?? 'Private details are hidden on this device.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: details == null
                      ? const Color(0xFF91A3BA)
                      : AppTheme.mist,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                '${event.organizer} | ${_formatDate(event.startsAt)} | ${event.location}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
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
