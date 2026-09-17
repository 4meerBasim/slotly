import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../scheduling/availability.dart';
import 'booking_repository.dart';
import 'catalog_repository.dart';

typedef SlotQuery = ({
  String staffId,
  DateTime day,
  int serviceMinutes,
  int stepMinutes,
});

/// Joins the barber's weekly hours with everything already on their calendar
/// and hands both to the pure slot generator.
///
/// [SlotQuery.day] must be date-only — records compare by value, so a query
/// carrying a wall-clock time would create a fresh provider on every rebuild.
final slotsProvider =
    FutureProvider.family<List<DateTime>, SlotQuery>((ref, q) async {
  final hours = await ref.watch(workingHoursProvider(q.staffId).future);
  final busy = await ref
      .watch(busyRangesProvider((staffId: q.staffId, day: q.day)).future);

  return Availability.slots(
    day: q.day,
    hours: hours,
    busy: busy,
    serviceMinutes: q.serviceMinutes,
    stepMinutes: q.stepMinutes,
    leadTimeMinutes: 30,
  );
});
