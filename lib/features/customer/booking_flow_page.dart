import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/async_view.dart';
import '../../core/formatters.dart';
import '../../data/booking_repository.dart';
import '../../data/catalog_repository.dart';
import '../../data/slots_provider.dart';
import '../../models/service.dart';
import '../../models/shop.dart';
import '../../models/staff_member.dart';

class BookingFlowPage extends ConsumerStatefulWidget {
  const BookingFlowPage({super.key, required this.shop, required this.service});

  final Shop shop;
  final Service service;

  @override
  ConsumerState<BookingFlowPage> createState() => _BookingFlowPageState();
}

class _BookingFlowPageState extends ConsumerState<BookingFlowPage> {
  static const _daysAhead = 14;

  String? _staffId;
  late DateTime _day = DateUtils.dateOnly(DateTime.now());
  DateTime? _slot;
  bool _booking = false;

  /// Resolved from whatever the barber list currently holds, so the confirm
  /// handler never needs a copy of the selection kept in sync by hand.
  StaffMember? get _selectedStaff {
    final list = ref.read(staffForServiceProvider(widget.service.id)).value;
    if (list == null || list.isEmpty) return null;
    return list.firstWhere((s) => s.id == _staffId, orElse: () => list.first);
  }

  @override
  Widget build(BuildContext context) {
    final staff = ref.watch(staffForServiceProvider(widget.service.id));

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.service.name),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(20),
          child: Padding(
            padding: const EdgeInsets.only(left: 16, bottom: 12),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '${widget.shop.name} · ${duration(widget.service.durationMinutes)} · '
                '${money(widget.service.priceCents)}',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ),
      ),
      body: AsyncView(
        value: staff,
        onRetry: () =>
            ref.invalidate(staffForServiceProvider(widget.service.id)),
        data: (list) {
          if (list.isEmpty) {
            return const EmptyState(
              icon: Icons.person_off_outlined,
              title: 'Nobody offers this yet',
              message: 'The shop has not assigned a barber to this service.',
            );
          }

          final selected = list.firstWhere(
            (s) => s.id == _staffId,
            orElse: () => list.first,
          );

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
            children: [
              const _SectionLabel('Barber'),
              _StaffPicker(
                staff: list,
                selected: selected,
                onChanged: (s) => setState(() {
                  _staffId = s.id;
                  _slot = null;
                }),
              ),
              const SizedBox(height: 24),
              const _SectionLabel('Date'),
              _DayStrip(
                days: _daysAhead,
                selected: _day,
                onChanged: (d) => setState(() {
                  _day = d;
                  _slot = null;
                }),
              ),
              const SizedBox(height: 24),
              const _SectionLabel('Time'),
              _SlotGrid(
                query: (
                  staffId: selected.id,
                  day: _day,
                  serviceMinutes: widget.service.durationMinutes,
                  stepMinutes: widget.shop.slotIntervalMinutes,
                ),
                selected: _slot,
                onChanged: (t) => setState(() => _slot = t),
              ),
            ],
          );
        },
      ),
      bottomSheet: _slot == null
          ? null
          : _ConfirmBar(
              label: '${relativeDay(_slot!)} at ${clock(_slot!)}',
              price: money(widget.service.priceCents),
              busy: _booking,
              onConfirm: _confirm,
            ),
    );
  }

  Future<void> _confirm() async {
    final slot = _slot;
    final staff = _selectedStaff;
    if (slot == null || staff == null) return;

    setState(() => _booking = true);
    try {
      await ref.read(bookingRepositoryProvider).create(
            staffId: staff.id,
            serviceId: widget.service.id,
            startsAt: slot,
          );
      ref.invalidate(myBookingsProvider);
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Booked with ${staff.name}, ${relativeDay(slot)} at ${clock(slot)}',
          ),
        ),
      );
    } on BookingException catch (e) {
      // the slot list is stale if someone else just took it — refetch
      ref.invalidate(busyRangesProvider((staffId: staff.id, day: _day)));
      if (!mounted) return;
      setState(() => _slot = null);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _booking = false);
    }
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
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

class _StaffPicker extends StatelessWidget {
  const _StaffPicker({
    required this.staff,
    required this.selected,
    required this.onChanged,
  });

  final List<StaffMember> staff;
  final StaffMember selected;
  final ValueChanged<StaffMember> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: 96,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: staff.length,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (_, i) {
          final s = staff[i];
          final active = s.id == selected.id;
          return GestureDetector(
            onTap: () => onChanged(s),
            child: SizedBox(
              width: 72,
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 26,
                    backgroundColor:
                        active ? scheme.primary : scheme.surfaceContainerHighest,
                    child: Text(
                      s.initials,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: active ? scheme.onPrimary : scheme.onSurface,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    s.name.split(' ').first,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                      color: active ? scheme.primary : scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _DayStrip extends StatelessWidget {
  const _DayStrip({
    required this.days,
    required this.selected,
    required this.onChanged,
  });

  final int days;
  final DateTime selected;
  final ValueChanged<DateTime> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final today = DateUtils.dateOnly(DateTime.now());

    return SizedBox(
      height: 72,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: days,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (_, i) {
          final day = today.add(Duration(days: i));
          final active = DateUtils.isSameDay(day, selected);
          return GestureDetector(
            onTap: () => onChanged(day),
            child: Container(
              width: 62,
              decoration: BoxDecoration(
                color: active ? scheme.primary : scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    dayLabel(day).split(',').first,
                    style: TextStyle(
                      fontSize: 12,
                      color: active ? scheme.onPrimary : scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${day.day}',
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w600,
                      color: active ? scheme.onPrimary : scheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _SlotGrid extends ConsumerWidget {
  const _SlotGrid({
    required this.query,
    required this.selected,
    required this.onChanged,
  });

  final SlotQuery query;
  final DateTime? selected;
  final ValueChanged<DateTime> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final slots = ref.watch(slotsProvider(query));
    final scheme = Theme.of(context).colorScheme;

    return slots.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 40),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => ErrorState(
        message: '$e',
        onRetry: () => ref.invalidate(slotsProvider(query)),
      ),
      data: (times) {
        if (times.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 32),
            child: EmptyState(
              icon: Icons.event_busy_outlined,
              title: 'Fully booked',
              message: 'Nothing free on this day. Try another date.',
            ),
          );
        }

        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final t in times)
              _SlotChip(
                time: t,
                active: selected != null && selected!.isAtSameMomentAs(t),
                scheme: scheme,
                onTap: () => onChanged(t),
              ),
          ],
        );
      },
    );
  }
}

class _SlotChip extends StatelessWidget {
  const _SlotChip({
    required this.time,
    required this.active,
    required this.scheme,
    required this.onTap,
  });

  final DateTime time;
  final bool active;
  final ColorScheme scheme;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
        decoration: BoxDecoration(
          color: active ? scheme.primary : scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: active ? scheme.primary : scheme.outlineVariant,
          ),
        ),
        child: Text(
          clock(time),
          style: TextStyle(
            fontWeight: active ? FontWeight.w600 : FontWeight.w500,
            color: active ? scheme.onPrimary : scheme.onSurface,
          ),
        ),
      ),
    );
  }
}

class _ConfirmBar extends StatelessWidget {
  const _ConfirmBar({
    required this.label,
    required this.price,
    required this.busy,
    required this.onConfirm,
  });

  final String label;
  final String price;
  final bool busy;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      color: scheme.surfaceContainerLow,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(label,
                      style: Theme.of(context).textTheme.titleSmall),
                  Text(price,
                      style: TextStyle(color: scheme.onSurfaceVariant)),
                ],
              ),
            ),
            const SizedBox(width: 16),
            SizedBox(
              width: 150,
              child: FilledButton(
                onPressed: busy ? null : onConfirm,
                child: busy
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Confirm'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
