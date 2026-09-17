import '../models/working_hours.dart';

class TimeRange {
  const TimeRange(this.start, this.end);

  final DateTime start;
  final DateTime end;

  bool overlaps(TimeRange other) =>
      start.isBefore(other.end) && other.start.isBefore(end);

  @override
  String toString() => '$start → $end';
}

/// Works out which start times a customer can actually pick.
///
/// Pure and synchronous on purpose: every rule that decides whether a chair is
/// free lives here, so it can be unit-tested without a database or a widget.
/// The server re-checks all of it in `create_booking()` — this exists to keep
/// impossible times off the screen, not to be the source of truth.
class Availability {
  const Availability._();

  /// [day] is any instant on the target calendar day, in local time.
  /// [hours] may contain every weekday; only the matching ones are used.
  /// [busy] holds existing bookings and time off, already in local time.
  /// [leadTimeMinutes] blocks the next N minutes — nobody books a haircut
  /// starting ninety seconds from now.
  static List<DateTime> slots({
    required DateTime day,
    required List<WorkingHours> hours,
    required List<TimeRange> busy,
    required int serviceMinutes,
    required int stepMinutes,
    DateTime? now,
    int leadTimeMinutes = 0,
  }) {
    assert(serviceMinutes > 0 && stepMinutes > 0);

    // Dart weekdays run 1=Mon..7=Sun; Postgres `extract(dow)` runs 0=Sun..6=Sat.
    final dow = day.weekday % 7;
    final windows = hours.where((h) => h.weekday == dow);
    if (windows.isEmpty) return const [];

    final floor = (now ?? DateTime.now())
        .add(Duration(minutes: leadTimeMinutes));
    final found = <DateTime>{};

    for (final window in windows) {
      for (var m = window.startMinutes;
          m + serviceMinutes <= window.endMinutes;
          m += stepMinutes) {
        final start = _at(day, m);
        if (start.isBefore(floor)) continue;

        final slot = TimeRange(start, _at(day, m + serviceMinutes));
        if (busy.any(slot.overlaps)) continue;

        found.add(start);
      }
    }

    return found.toList()..sort();
  }

  /// Builds a wall-clock time on [day] rather than adding a Duration, so a
  /// daylight-saving change does not shift every slot by an hour.
  static DateTime _at(DateTime day, int minutes) =>
      DateTime(day.year, day.month, day.day, minutes ~/ 60, minutes % 60);
}
