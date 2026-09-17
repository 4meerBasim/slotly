/// A recurring weekly availability window for one staff member.
/// [weekday] follows Postgres `extract(dow)`: 0 = Sunday .. 6 = Saturday.
class WorkingHours {
  const WorkingHours({
    required this.id,
    required this.staffId,
    required this.weekday,
    required this.startMinutes,
    required this.endMinutes,
  });

  final String id;
  final String staffId;
  final int weekday;
  final int startMinutes;
  final int endMinutes;

  factory WorkingHours.fromJson(Map<String, dynamic> json) => WorkingHours(
        id: json['id'] as String,
        staffId: json['staff_id'] as String,
        weekday: json['weekday'] as int,
        startMinutes: _parse(json['start_time'] as String),
        endMinutes: _parse(json['end_time'] as String),
      );

  /// Postgres `time` arrives as "09:00:00".
  static int _parse(String time) {
    final parts = time.split(':');
    return int.parse(parts[0]) * 60 + int.parse(parts[1]);
  }

  static String format(int minutes) {
    final h = (minutes ~/ 60).toString().padLeft(2, '0');
    final m = (minutes % 60).toString().padLeft(2, '0');
    return '$h:$m:00';
  }
}
