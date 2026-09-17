import 'package:flutter_test/flutter_test.dart';
import 'package:slotly/models/working_hours.dart';
import 'package:slotly/scheduling/availability.dart';

WorkingHours hours(int weekday, String from, String to) {
  int m(String s) =>
      int.parse(s.split(':')[0]) * 60 + int.parse(s.split(':')[1]);
  return WorkingHours(
    id: '$weekday-$from',
    staffId: 'staff-1',
    weekday: weekday,
    startMinutes: m(from),
    endMinutes: m(to),
  );
}

TimeRange busy(DateTime day, String from, String to) {
  DateTime at(String s) => DateTime(day.year, day.month, day.day,
      int.parse(s.split(':')[0]), int.parse(s.split(':')[1]));
  return TimeRange(at(from), at(to));
}

List<String> labels(List<DateTime> slots) => slots
    .map((s) =>
        '${s.hour.toString().padLeft(2, '0')}:${s.minute.toString().padLeft(2, '0')}')
    .toList();

void main() {
  // Wednesday 2026-10-14. Postgres dow for Wednesday is 3.
  final wed = DateTime(2026, 10, 14);
  final wayEarlier = DateTime(2026, 10, 1);

  test('walks the working window in step increments', () {
    final slots = Availability.slots(
      day: wed,
      hours: [hours(3, '09:00', '11:00')],
      busy: const [],
      serviceMinutes: 30,
      stepMinutes: 30,
      now: wayEarlier,
    );
    expect(labels(slots), ['09:00', '09:30', '10:00', '10:30']);
  });

  test('a slot must finish inside the window, not merely start inside it', () {
    final slots = Availability.slots(
      day: wed,
      hours: [hours(3, '09:00', '10:00')],
      busy: const [],
      serviceMinutes: 45,
      stepMinutes: 15,
      now: wayEarlier,
    );
    // 09:30 would end at 10:15, past closing.
    expect(labels(slots), ['09:00', '09:15']);
  });

  test('step can be finer than the service, giving overlapping candidates', () {
    final slots = Availability.slots(
      day: wed,
      hours: [hours(3, '09:00', '10:00')],
      busy: const [],
      serviceMinutes: 30,
      stepMinutes: 15,
      now: wayEarlier,
    );
    expect(labels(slots), ['09:00', '09:15', '09:30']);
  });

  test('an existing booking removes every slot it touches', () {
    final slots = Availability.slots(
      day: wed,
      hours: [hours(3, '09:00', '11:00')],
      busy: [busy(wed, '09:30', '10:00')],
      serviceMinutes: 30,
      stepMinutes: 15,
      now: wayEarlier,
    );
    // 09:15 ends 09:45 and 09:45 starts inside the booking — both gone.
    expect(labels(slots), ['09:00', '10:00', '10:15', '10:30']);
  });

  test('back-to-back bookings do not count as an overlap', () {
    final slots = Availability.slots(
      day: wed,
      hours: [hours(3, '09:00', '10:00')],
      busy: [busy(wed, '09:00', '09:30')],
      serviceMinutes: 30,
      stepMinutes: 30,
      now: wayEarlier,
    );
    expect(labels(slots), ['09:30']);
  });

  test('a lunch break splits the day into two runs', () {
    final slots = Availability.slots(
      day: wed,
      hours: [hours(3, '09:00', '14:00')],
      busy: [busy(wed, '12:00', '13:00')],
      serviceMinutes: 60,
      stepMinutes: 60,
      now: wayEarlier,
    );
    expect(labels(slots), ['09:00', '10:00', '11:00', '13:00']);
  });

  test('split shifts are merged and sorted', () {
    final slots = Availability.slots(
      day: wed,
      hours: [hours(3, '16:00', '18:00'), hours(3, '09:00', '10:00')],
      busy: const [],
      serviceMinutes: 60,
      stepMinutes: 60,
      now: wayEarlier,
    );
    expect(labels(slots), ['09:00', '16:00', '17:00']);
  });

  test('overlapping windows never yield a duplicate start time', () {
    final slots = Availability.slots(
      day: wed,
      hours: [hours(3, '09:00', '11:00'), hours(3, '10:00', '12:00')],
      busy: const [],
      serviceMinutes: 60,
      stepMinutes: 60,
      now: wayEarlier,
    );
    expect(labels(slots), ['09:00', '10:00', '11:00']);
  });

  test('hours for other weekdays are ignored', () {
    final slots = Availability.slots(
      day: wed,
      hours: [hours(1, '09:00', '17:00'), hours(5, '09:00', '17:00')],
      busy: const [],
      serviceMinutes: 30,
      stepMinutes: 30,
      now: wayEarlier,
    );
    expect(slots, isEmpty);
  });

  test('a closed day returns nothing rather than throwing', () {
    final slots = Availability.slots(
      day: wed,
      hours: const [],
      busy: const [],
      serviceMinutes: 30,
      stepMinutes: 30,
      now: wayEarlier,
    );
    expect(slots, isEmpty);
  });

  test('slots already past are dropped', () {
    final slots = Availability.slots(
      day: wed,
      hours: [hours(3, '09:00', '12:00')],
      busy: const [],
      serviceMinutes: 60,
      stepMinutes: 60,
      now: DateTime(2026, 10, 14, 10, 30),
    );
    expect(labels(slots), ['11:00']);
  });

  test('lead time blocks the slots immediately ahead', () {
    final slots = Availability.slots(
      day: wed,
      hours: [hours(3, '09:00', '13:00')],
      busy: const [],
      serviceMinutes: 60,
      stepMinutes: 60,
      now: DateTime(2026, 10, 14, 9, 0),
      leadTimeMinutes: 90,
    );
    // now + 90m = 10:30, so 10:00 is too soon.
    expect(labels(slots), ['11:00', '12:00']);
  });

  test('a booking that swallows the whole day leaves nothing', () {
    final slots = Availability.slots(
      day: wed,
      hours: [hours(3, '09:00', '17:00')],
      busy: [busy(wed, '08:00', '18:00')],
      serviceMinutes: 30,
      stepMinutes: 30,
      now: wayEarlier,
    );
    expect(slots, isEmpty);
  });
}
