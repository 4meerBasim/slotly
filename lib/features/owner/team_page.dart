import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/async_view.dart';
import '../../data/catalog_repository.dart';
import '../../models/shop.dart';
import '../../models/staff_member.dart';
import 'staff_detail_page.dart';

class TeamPage extends ConsumerWidget {
  const TeamPage({super.key, required this.shop});

  final Shop shop;

  Future<void> _add(BuildContext context, WidgetRef ref) async {
    final created = await showModalBottomSheet<StaffMember>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _StaffSheet(shopId: shop.id),
    );
    if (created == null || !context.mounted) return;
    ref.invalidate(staffProvider(shop.id));
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => StaffDetailPage(shop: shop, staff: created),
      ),
    );
    ref.invalidate(staffProvider(shop.id));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final staff = ref.watch(staffProvider(shop.id));

    return Scaffold(
      appBar: AppBar(title: const Text('Team')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _add(context, ref),
        icon: const Icon(Icons.person_add_alt),
        label: const Text('Add barber'),
      ),
      body: AsyncView(
        value: staff,
        onRetry: () => ref.invalidate(staffProvider(shop.id)),
        data: (list) {
          if (list.isEmpty) {
            return const EmptyState(
              icon: Icons.groups_outlined,
              title: 'No barbers yet',
              message: 'Add someone, then set what they do and when they work.',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            itemCount: list.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (_, i) {
              final s = list[i];
              return Card(
                child: ListTile(
                  leading: CircleAvatar(child: Text(s.initials)),
                  title: Text(s.name),
                  subtitle: Text(s.title ?? 'Barber'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => StaffDetailPage(shop: shop, staff: s),
                      ),
                    );
                    ref.invalidate(staffProvider(shop.id));
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _StaffSheet extends ConsumerStatefulWidget {
  const _StaffSheet({required this.shopId});

  final String shopId;

  @override
  ConsumerState<_StaffSheet> createState() => _StaffSheetState();
}

class _StaffSheetState extends ConsumerState<_StaffSheet> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _title = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _title.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      final created = await ref.read(catalogRepositoryProvider).saveStaff(
            shopId: widget.shopId,
            name: _name.text.trim(),
            title: _title.text.trim(),
          );
      if (mounted) Navigator.pop(context, created);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Could not save: $e')));
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('New barber',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 20),
            TextFormField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Name'),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _title,
              decoration: const InputDecoration(
                labelText: 'Title',
                hintText: 'Senior barber',
              ),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _busy ? null : _save,
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }
}
