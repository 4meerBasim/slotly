import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/async_view.dart';
import '../../data/catalog_repository.dart';
import '../../models/shop.dart';
import '../../models/staff_member.dart';
import '../../models/working_hours.dart';

const _weekdayNames = [
  'Sunday',
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
];

class StaffDetailPage extends ConsumerStatefulWidget {
  const StaffDetailPage({super.key, required this.shop, required this.staff});

  final Shop shop;
  final StaffMember staff;

  @override
  ConsumerState<StaffDetailPage> createState() => _StaffDetailPageState();
}

class _StaffDetailPageState extends ConsumerState<StaffDetailPage> {
  /// null means the barber is off that day. Index is the Postgres weekday.
  final List<({int start, int end})?> _week = List.filled(7, null);
  final Set<String> _serviceIds = {};
  bool _loaded = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final repo = ref.read(catalogRepositoryProvider);
    final hours = await repo.workingHours(widget.staff.id);
    final services = await repo.serviceIdsForStaff(widget.staff.id);
    if (!mounted) return;
    setState(() {
      for (final h in hours) {
        _week[h.weekday] = (start: h.startMinutes, end: h.endMinutes);
      }
      _serviceIds.addAll(services);
      _loaded = true;
    });
  }

  Future<void> _pickTime(int weekday, bool isStart) async {
    final current = _week[weekday]!;
    final minutes = isStart ? current.start : current.end;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60),
    );
    if (picked == null) return;

    final value = picked.hour * 60 + picked.minute;
    setState(() {
      _week[weekday] = isStart
          ? (start: value, end: current.end)
          : (start: current.start, end: value);
    });
  }

  Future<void> _save() async {
    final invalid = <String>[];
    for (var d = 0; d < 7; d++) {
      final w = _week[d];
      if (w != null && w.end <= w.start) invalid.add(_weekdayNames[d]);
    }
    if (invalid.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${invalid.join(', ')}: end time must be after start'),
        ),
      );
      return;
    }

    setState(() => _busy = true);
    try {
      final repo = ref.read(catalogRepositoryProvider);
      await repo.setWorkingHours(widget.staff.id, [
        for (var d = 0; d < 7; d++)
          if (_week[d] != null)
            WorkingHours(
              id: '',
              staffId: widget.staff.id,
              weekday: d,
              startMinutes: _week[d]!.start,
              endMinutes: _week[d]!.end,
            ),
      ]);
      await repo.setStaffServices(widget.staff.id, _serviceIds.toList());

      ref.invalidate(workingHoursProvider(widget.staff.id));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Saved')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Could not save: $e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _remove() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Remove ${widget.staff.name}?'),
        content: const Text(
          'They stop appearing to customers. Existing bookings are kept.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await ref.read(catalogRepositoryProvider).archiveStaff(widget.staff.id);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final services = ref.watch(servicesProvider(widget.shop.id));

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.staff.name),
        actions: [
          IconButton(
            tooltip: 'Remove',
            icon: const Icon(Icons.delete_outline),
            onPressed: _remove,
          ),
        ],
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
        child: FilledButton(
          onPressed: _busy || !_loaded ? null : _save,
          child: _busy
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Save'),
        ),
      ),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                const _Header('Services offered'),
                AsyncView(
                  value: services,
                  data: (list) => list.isEmpty
                      ? const Padding(
                          padding: EdgeInsets.symmetric(vertical: 20),
                          child: Text(
                            'Add services on the Services tab first.',
                          ),
                        )
                      : Column(
                          children: [
                            for (final s in list)
                              CheckboxListTile(
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                                title: Text(s.name),
                                value: _serviceIds.contains(s.id),
                                onChanged: (on) => setState(() {
                                  if (on == true) {
                                    _serviceIds.add(s.id);
                                  } else {
                                    _serviceIds.remove(s.id);
                                  }
                                }),
                              ),
                          ],
                        ),
                ),
                const SizedBox(height: 20),
                const _Header('Working hours'),
                for (var d = 0; d < 7; d++) _dayRow(d),
              ],
            ),
    );
  }

  Widget _dayRow(int weekday) {
    final hours = _week[weekday];
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 108,
            child: Row(
              children: [
                Switch(
                  value: hours != null,
                  onChanged: (on) => setState(() {
                    _week[weekday] =
                        on ? (start: 9 * 60, end: 17 * 60) : null;
                  }),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _weekdayNames[weekday].substring(0, 3),
                    style: TextStyle(
                      fontWeight:
                          hours != null ? FontWeight.w600 : FontWeight.w400,
                      color: hours != null
                          ? scheme.onSurface
                          : scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (hours == null)
            Expanded(
              child: Text(
                'Closed',
                style: TextStyle(color: scheme.onSurfaceVariant),
              ),
            )
          else ...[
            Expanded(
              child: OutlinedButton(
                onPressed: () => _pickTime(weekday, true),
                child: Text(_hhmm(hours.start)),
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Text('–'),
            ),
            Expanded(
              child: OutlinedButton(
                onPressed: () => _pickTime(weekday, false),
                child: Text(_hhmm(hours.end)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  static String _hhmm(int minutes) =>
      '${(minutes ~/ 60).toString().padLeft(2, '0')}:'
      '${(minutes % 60).toString().padLeft(2, '0')}';
}

class _Header extends StatelessWidget {
  const _Header(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          text.toUpperCase(),
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                letterSpacing: 0.8,
                fontWeight: FontWeight.w600,
              ),
        ),
      );
}
