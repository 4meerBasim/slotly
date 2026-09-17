import 'package:intl/intl.dart';

String money(int cents) => NumberFormat.currency(
      symbol: '\$',
      decimalDigits: cents % 100 == 0 ? 0 : 2,
    ).format(cents / 100);

String duration(int minutes) {
  if (minutes < 60) return '${minutes}m';
  final h = minutes ~/ 60;
  final m = minutes % 60;
  return m == 0 ? '${h}h' : '${h}h ${m}m';
}

final _time = DateFormat.jm();
final _dayLabel = DateFormat('EEE, MMM d');
final _fullDate = DateFormat('EEEE, MMMM d');

String clock(DateTime t) => _time.format(t);
String dayLabel(DateTime t) => _dayLabel.format(t);
String fullDate(DateTime t) => _fullDate.format(t);

String relativeDay(DateTime t) {
  final now = DateTime.now();
  final d = DateTime(t.year, t.month, t.day)
      .difference(DateTime(now.year, now.month, now.day))
      .inDays;
  if (d == 0) return 'Today';
  if (d == 1) return 'Tomorrow';
  if (d == -1) return 'Yesterday';
  return dayLabel(t);
}
