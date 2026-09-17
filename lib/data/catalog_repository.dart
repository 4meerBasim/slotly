import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/service.dart';
import '../models/shop.dart';
import '../models/staff_member.dart';
import '../models/working_hours.dart';
import 'auth_repository.dart';

final catalogRepositoryProvider = Provider<CatalogRepository>(
  (ref) => CatalogRepository(ref.watch(supabaseProvider)),
);

final shopsProvider = FutureProvider<List<Shop>>(
  (ref) => ref.watch(catalogRepositoryProvider).shops(),
);

/// The shop belonging to the signed-in owner, if they have created one yet.
final myShopProvider = FutureProvider<Shop?>((ref) async {
  final profile = await ref.watch(profileProvider.future);
  if (profile == null || !profile.isOwner) return null;
  return ref.watch(catalogRepositoryProvider).shopForOwner(profile.id);
});

final servicesProvider = FutureProvider.family<List<Service>, String>(
  (ref, shopId) => ref.watch(catalogRepositoryProvider).services(shopId),
);

final staffProvider = FutureProvider.family<List<StaffMember>, String>(
  (ref, shopId) => ref.watch(catalogRepositoryProvider).staff(shopId),
);

final staffForServiceProvider =
    FutureProvider.family<List<StaffMember>, String>(
  (ref, serviceId) =>
      ref.watch(catalogRepositoryProvider).staffForService(serviceId),
);

final workingHoursProvider =
    FutureProvider.family<List<WorkingHours>, String>(
  (ref, staffId) => ref.watch(catalogRepositoryProvider).workingHours(staffId),
);

class CatalogRepository {
  CatalogRepository(this._client);

  final SupabaseClient _client;

  Future<List<Shop>> shops() async {
    final rows = await _client.from('shops').select().order('name');
    return rows.map(Shop.fromJson).toList();
  }

  Future<Shop?> shopForOwner(String ownerId) async {
    final row = await _client
        .from('shops')
        .select()
        .eq('owner_id', ownerId)
        .maybeSingle();
    return row == null ? null : Shop.fromJson(row);
  }

  Future<Shop> createShop({
    required String ownerId,
    required String name,
    String? description,
    String? address,
    String? phone,
  }) async {
    final row = await _client.from('shops').insert({
      'owner_id': ownerId,
      'name': name,
      'description': description,
      'address': address,
      'phone': phone,
    }).select().single();
    return Shop.fromJson(row);
  }

  Future<void> updateShop(
    String shopId,
    Map<String, dynamic> changes,
  ) =>
      _client.from('shops').update(changes).eq('id', shopId);

  Future<List<Service>> services(String shopId) async {
    final rows = await _client
        .from('services')
        .select()
        .eq('shop_id', shopId)
        .eq('is_active', true)
        .order('name');
    return rows.map(Service.fromJson).toList();
  }

  Future<Service> saveService({
    String? id,
    required String shopId,
    required String name,
    required int durationMinutes,
    required int priceCents,
  }) async {
    final payload = {
      'shop_id': shopId,
      'name': name,
      'duration_minutes': durationMinutes,
      'price_cents': priceCents,
    };
    final row = id == null
        ? await _client.from('services').insert(payload).select().single()
        : await _client
            .from('services')
            .update(payload)
            .eq('id', id)
            .select()
            .single();
    return Service.fromJson(row);
  }

  /// Services are archived rather than deleted so past bookings keep their name.
  Future<void> archiveService(String id) =>
      _client.from('services').update({'is_active': false}).eq('id', id);

  Future<List<StaffMember>> staff(String shopId) async {
    final rows = await _client
        .from('staff')
        .select()
        .eq('shop_id', shopId)
        .eq('is_active', true)
        .order('name');
    return rows.map(StaffMember.fromJson).toList();
  }

  Future<List<StaffMember>> staffForService(String serviceId) async {
    final rows = await _client
        .from('staff_services')
        .select('staff(*)')
        .eq('service_id', serviceId);
    return rows
        .map((r) => r['staff'] as Map<String, dynamic>?)
        .whereType<Map<String, dynamic>>()
        .map(StaffMember.fromJson)
        .where((s) => s.isActive)
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));
  }

  Future<StaffMember> saveStaff({
    String? id,
    required String shopId,
    required String name,
    String? title,
  }) async {
    final payload = {'shop_id': shopId, 'name': name, 'title': title};
    final row = id == null
        ? await _client.from('staff').insert(payload).select().single()
        : await _client
            .from('staff')
            .update(payload)
            .eq('id', id)
            .select()
            .single();
    return StaffMember.fromJson(row);
  }

  Future<void> archiveStaff(String id) =>
      _client.from('staff').update({'is_active': false}).eq('id', id);

  Future<List<String>> serviceIdsForStaff(String staffId) async {
    final rows = await _client
        .from('staff_services')
        .select('service_id')
        .eq('staff_id', staffId);
    return rows.map((r) => r['service_id'] as String).toList();
  }

  Future<void> setStaffServices(String staffId, List<String> serviceIds) async {
    await _client.from('staff_services').delete().eq('staff_id', staffId);
    if (serviceIds.isEmpty) return;
    await _client.from('staff_services').insert([
      for (final id in serviceIds) {'staff_id': staffId, 'service_id': id},
    ]);
  }

  Future<List<WorkingHours>> workingHours(String staffId) async {
    final rows = await _client
        .from('working_hours')
        .select()
        .eq('staff_id', staffId)
        .order('weekday');
    return rows.map(WorkingHours.fromJson).toList();
  }

  /// Replaces the whole week in one go — simpler than diffing, and the row
  /// count here is never more than a handful per barber.
  Future<void> setWorkingHours(
    String staffId,
    List<WorkingHours> hours,
  ) async {
    await _client.from('working_hours').delete().eq('staff_id', staffId);
    if (hours.isEmpty) return;
    await _client.from('working_hours').insert([
      for (final h in hours)
        {
          'staff_id': staffId,
          'weekday': h.weekday,
          'start_time': WorkingHours.format(h.startMinutes),
          'end_time': WorkingHours.format(h.endMinutes),
        },
    ]);
  }
}
