import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/async_view.dart';
import '../../core/formatters.dart';
import '../../data/booking_repository.dart';
import '../../models/booking.dart';
import '../../models/shop.dart';
import '../customer/my_bookings_page.dart' show StatusPill;

class SchedulePage extends ConsumerStatefulWidget {
  const SchedulePage({super.key, required this.shop});

  final Shop shop;

  @override
  ConsumerState<SchedulePage> createState() => _SchedulePageState();
}

class _SchedulePageState extends ConsumerState<SchedulePage> {
  late DateTime _day = DateUtils.dateOnly(DateTime.now());

  ShopDay get _key => (shopId: widget.shop.id, day: _day);

  void _shift(int days) =>
      setState(() => _day = _day.add(Duration(days: days)));

  Future<void> _pickDay() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _day,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _day = DateUtils.dateOnly(picked));
  }

  Future<void> _setStatus(Booking b, BookingStatus status) async {
    await ref.read(bookingRepositoryProvider).setStatus(b.id, status);
    ref.invalidate(shopDayBookingsProvider(_key));
    ref.invalidate(busyRangesProvider((staffId: b.staffId, day: _day)));
  }

  @override
  Widget build(BuildContext context) {
    final bookings = ref.watch(shopDayBookingsProvider(_key));
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text(widget.shop.name)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: () => _shift(-1),
                ),
                Expanded(
                  child: TextButton(
                    onPressed: _pickDay,
                    child: Column(
                      children: [
                        Text(
                          relativeDay(_day),
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        Text(
                          fullDate(_day),
                          style: TextStyle(
                            fontSize: 12,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: () => _shift(1),
                ),
              ],
            ),
          ),
          Expanded(
            child: AsyncView(
              value: bookings,
              onRetry: () => ref.invalidate(shopDayBookingsProvider(_key)),
              data: (list) {
                if (list.isEmpty) {
                  return const EmptyState(
                    icon: Icons.event_available_outlined,
                    title: 'Nothing booked',
                    message: 'This day is completely free.',
                  );
                }

                final live = list.where((b) => b.status.isLive).toList();
                final revenue = live.fold(0, (sum, b) => sum + b.priceCents);

                return RefreshIndicator(
                  onRefresh: () async =>
                      ref.invalidate(shopDayBookingsProvider(_key)),
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
                    children: [
                      _DaySummary(count: live.length, revenueCents: revenue),
                      const SizedBox(height: 16),
                      for (final b in list) ...[
                        _AppointmentCard(
                          booking: b,
                          onStatus: (s) => _setStatus(b, s),
                        ),
                        const SizedBox(height: 12),
                      ],
                    ],
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

class _DaySummary extends StatelessWidget {
  const _DaySummary({required this.count, required this.revenueCents});

  final int count;
  final int revenueCents;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          _Stat(
            label: 'Appointments',
            value: '$count',
            color: scheme.onPrimaryContainer,
          ),
          Container(
            width: 1,
            height: 34,
            color: scheme.onPrimaryContainer.withValues(alpha: 0.2),
          ),
          _Stat(
            label: 'Expected',
            value: money(revenueCents),
            color: scheme.onPrimaryContainer,
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: color.withValues(alpha: 0.8),
              ),
            ),
          ],
        ),
      );
}

class _AppointmentCard extends StatelessWidget {
  const _AppointmentCard({required this.booking, required this.onStatus});

  final Booking booking;
  final ValueChanged<BookingStatus> onStatus;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 74,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        clock(booking.startsAt),
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      Text(
                        clock(booking.endsAt),
                        style: TextStyle(
                          fontSize: 12,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        booking.customerName ?? 'Customer',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${booking.serviceName ?? ''} · ${booking.staffName ?? ''}',
                        style: TextStyle(color: scheme.onSurfaceVariant),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        money(booking.priceCents),
                        style: TextStyle(color: scheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                StatusPill(status: booking.status),
              ],
            ),
            if (booking.status.isLive) ...[
              const Divider(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => onStatus(BookingStatus.noShow),
                    style: TextButton.styleFrom(foregroundColor: scheme.error),
                    child: const Text('No-show'),
                  ),
                  const SizedBox(width: 4),
                  TextButton(
                    onPressed: () => onStatus(BookingStatus.cancelled),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 4),
                  FilledButton.tonal(
                    onPressed: () => onStatus(BookingStatus.completed),
                    child: const Text('Done'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
