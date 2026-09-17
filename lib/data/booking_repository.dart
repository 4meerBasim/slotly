import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/booking.dart';
import '../scheduling/availability.dart';
import 'auth_repository.dart';

const _bookingJoin =
    '*, shops(name), staff(name), services(name), '
    'profiles!bookings_customer_id_fkey(full_name)';

/// Raised for the named errors thrown by `create_booking()`.
class BookingException implements Exception {
  BookingException(this.code);

  final String code;

  String get message => switch (code) {
        'slot_taken' => 'Someone just took that time. Pick another slot.',
        'slot_in_past' => 'That time has already passed.',
        'outside_working_hours' => 'The barber is not working then.',
        'staff_unavailable' => 'The barber is away at that time.',
        'staff_cannot_perform_service' =>
          'That barber does not offer this service.',
        'service_not_found' => 'This service is no longer offered.',
        'staff_not_found' => 'This barber is no longer available.',
        'not_authenticated' => 'Please sign in again.',
        _ => 'Could not complete the booking. Please try again.',
      };

  @override
  String toString() => message;
}

final bookingRepositoryProvider = Provider<BookingRepository>(
  (ref) => BookingRepository(ref.watch(supabaseProvider)),
);

final myBookingsProvider = FutureProvider<List<Booking>>((ref) async {
  final profile = await ref.watch(profileProvider.future);
  if (profile == null) return const [];
  return ref.watch(bookingRepositoryProvider).forCustomer(profile.id);
});

typedef ShopDay = ({String shopId, DateTime day});

final shopDayBookingsProvider =
    FutureProvider.family<List<Booking>, ShopDay>((ref, arg) =>
        ref.watch(bookingRepositoryProvider).forShopOnDay(arg.shopId, arg.day));

typedef StaffDay = ({String staffId, DateTime day});

final busyRangesProvider =
    FutureProvider.family<List<TimeRange>, StaffDay>((ref, arg) =>
        ref.watch(bookingRepositoryProvider).busyRanges(arg.staffId, arg.day));

class BookingRepository {
  BookingRepository(this._client);

  final SupabaseClient _client;

  Future<Booking> create({
    required String staffId,
    required String serviceId,
    required DateTime startsAt,
    String? notes,
  }) async {
    try {
      final row = await _client.rpc('create_booking', params: {
        'p_staff_id': staffId,
        'p_service_id': serviceId,
        'p_starts_at': startsAt.toUtc().toIso8601String(),
        'p_notes': notes,
      });
      return Booking.fromJson(Map<String, dynamic>.from(row as Map));
    } on PostgrestException catch (e) {
      throw BookingException(e.message.trim());
    }
  }

  Future<List<Booking>> forCustomer(String customerId) async {
    final rows = await _client
        .from('bookings')
        .select(_bookingJoin)
        .eq('customer_id', customerId)
        .order('starts_at', ascending: false);
    return rows.map(Booking.fromJson).toList();
  }

  Future<List<Booking>> forShopOnDay(String shopId, DateTime day) async {
    final start = DateTime(day.year, day.month, day.day);
    final end = start.add(const Duration(days: 1));
    final rows = await _client
        .from('bookings')
        .select(_bookingJoin)
        .eq('shop_id', shopId)
        .gte('starts_at', start.toUtc().toIso8601String())
        .lt('starts_at', end.toUtc().toIso8601String())
        .order('starts_at');
    return rows.map(Booking.fromJson).toList();
  }

  /// Everything that makes a barber unavailable on [day]: live bookings plus
  /// any time off. Fed straight into [Availability.slots].
  Future<List<TimeRange>> busyRanges(String staffId, DateTime day) async {
    final start = DateTime(day.year, day.month, day.day);
    final end = start.add(const Duration(days: 1));
    final from = start.toUtc().toIso8601String();
    final to = end.toUtc().toIso8601String();

    final bookings = await _client
        .from('bookings')
        .select('starts_at, ends_at')
        .eq('staff_id', staffId)
        .inFilter('status', ['pending', 'confirmed'])
        .lt('starts_at', to)
        .gt('ends_at', from);

    final away = await _client
        .from('time_off')
        .select('starts_at, ends_at')
        .eq('staff_id', staffId)
        .lt('starts_at', to)
        .gt('ends_at', from);

    TimeRange toRange(Map<String, dynamic> r) => TimeRange(
          DateTime.parse(r['starts_at'] as String).toLocal(),
          DateTime.parse(r['ends_at'] as String).toLocal(),
        );

    return [...bookings.map(toRange), ...away.map(toRange)];
  }

  Future<void> setStatus(String bookingId, BookingStatus status) => _client
      .from('bookings')
      .update({'status': status.wire}).eq('id', bookingId);

  Future<void> addTimeOff({
    required String staffId,
    required DateTime startsAt,
    required DateTime endsAt,
    String? reason,
  }) =>
      _client.from('time_off').insert({
        'staff_id': staffId,
        'starts_at': startsAt.toUtc().toIso8601String(),
        'ends_at': endsAt.toUtc().toIso8601String(),
        'reason': reason,
      });
}
