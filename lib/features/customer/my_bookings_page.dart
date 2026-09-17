import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/async_view.dart';
import '../../core/formatters.dart';
import '../../data/booking_repository.dart';
import '../../models/booking.dart';

class MyBookingsPage extends ConsumerWidget {
  const MyBookingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookings = ref.watch(myBookingsProvider);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('My bookings'),
          bottom: const TabBar(
            tabs: [Tab(text: 'Upcoming'), Tab(text: 'Past')],
          ),
        ),
        body: AsyncView(
          value: bookings,
          onRetry: () => ref.invalidate(myBookingsProvider),
          data: (all) {
            final upcoming = all.where((b) => b.isUpcoming).toList()
              ..sort((a, b) => a.startsAt.compareTo(b.startsAt));
            final past = all.where((b) => !b.isUpcoming).toList();

            return TabBarView(
              children: [
                _BookingList(
                  bookings: upcoming,
                  emptyTitle: 'No appointments booked',
                  emptyMessage: 'Find a shop on the Browse tab to get started.',
                  onRefresh: () => ref.invalidate(myBookingsProvider),
                  cancellable: true,
                ),
                _BookingList(
                  bookings: past,
                  emptyTitle: 'Nothing here yet',
                  emptyMessage: 'Past and cancelled appointments show up here.',
                  onRefresh: () => ref.invalidate(myBookingsProvider),
                  cancellable: false,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _BookingList extends ConsumerWidget {
  const _BookingList({
    required this.bookings,
    required this.emptyTitle,
    required this.emptyMessage,
    required this.onRefresh,
    required this.cancellable,
  });

  final List<Booking> bookings;
  final String emptyTitle;
  final String emptyMessage;
  final VoidCallback onRefresh;
  final bool cancellable;

  Future<void> _cancel(BuildContext context, WidgetRef ref, Booking b) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel this appointment?'),
        content: Text(
          '${b.serviceName ?? 'Appointment'} with ${b.staffName ?? 'your barber'} '
          'on ${fullDate(b.startsAt)} at ${clock(b.startsAt)}.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep it'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Cancel booking'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await ref
        .read(bookingRepositoryProvider)
        .setStatus(b.id, BookingStatus.cancelled);
    onRefresh();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (bookings.isEmpty) {
      return EmptyState(
        icon: Icons.event_outlined,
        title: emptyTitle,
        message: emptyMessage,
      );
    }

    return RefreshIndicator(
      onRefresh: () async => onRefresh(),
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        itemCount: bookings.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (_, i) {
          final b = bookings[i];
          return _BookingCard(
            booking: b,
            onCancel: cancellable ? () => _cancel(context, ref, b) : null,
          );
        },
      ),
    );
  }
}

class _BookingCard extends StatelessWidget {
  const _BookingCard({required this.booking, this.onCancel});

  final Booking booking;
  final VoidCallback? onCancel;

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
              children: [
                Expanded(
                  child: Text(
                    booking.serviceName ?? 'Appointment',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
                StatusPill(status: booking.status),
              ],
            ),
            const SizedBox(height: 10),
            _Line(
              icon: Icons.storefront_outlined,
              text: booking.shopName ?? '',
            ),
            _Line(
              icon: Icons.person_outline,
              text: booking.staffName ?? '',
            ),
            _Line(
              icon: Icons.schedule,
              text: '${relativeDay(booking.startsAt)}, '
                  '${clock(booking.startsAt)} – ${clock(booking.endsAt)}',
            ),
            _Line(
              icon: Icons.payments_outlined,
              text: money(booking.priceCents),
            ),
            if (onCancel != null) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: onCancel,
                  style: TextButton.styleFrom(foregroundColor: scheme.error),
                  child: const Text('Cancel'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    if (text.isEmpty) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(
        children: [
          Icon(icon, size: 17, color: scheme.outline),
          const SizedBox(width: 9),
          Expanded(
            child: Text(text, style: TextStyle(color: scheme.onSurfaceVariant)),
          ),
        ],
      ),
    );
  }
}

class StatusPill extends StatelessWidget {
  const StatusPill({super.key, required this.status});

  final BookingStatus status;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (bg, fg) = switch (status) {
      BookingStatus.confirmed => (scheme.primaryContainer, scheme.onPrimaryContainer),
      BookingStatus.pending => (scheme.tertiaryContainer, scheme.onTertiaryContainer),
      BookingStatus.completed => (scheme.secondaryContainer, scheme.onSecondaryContainer),
      BookingStatus.cancelled => (scheme.surfaceContainerHighest, scheme.onSurfaceVariant),
      BookingStatus.noShow => (scheme.errorContainer, scheme.onErrorContainer),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status.label,
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: fg),
      ),
    );
  }
}
