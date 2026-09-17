import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/async_view.dart';
import '../../core/formatters.dart';
import '../../data/catalog_repository.dart';
import '../../models/service.dart';
import '../../models/shop.dart';

class ServicesPage extends ConsumerWidget {
  const ServicesPage({super.key, required this.shop});

  final Shop shop;

  Future<void> _edit(
    BuildContext context,
    WidgetRef ref, [
    Service? existing,
  ]) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _ServiceSheet(shopId: shop.id, existing: existing),
    );
    if (saved == true) ref.invalidate(servicesProvider(shop.id));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final services = ref.watch(servicesProvider(shop.id));

    return Scaffold(
      appBar: AppBar(title: const Text('Services')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _edit(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Add service'),
      ),
      body: AsyncView(
        value: services,
        onRetry: () => ref.invalidate(servicesProvider(shop.id)),
        data: (list) {
          if (list.isEmpty) {
            return const EmptyState(
              icon: Icons.content_cut,
              title: 'No services yet',
              message: 'Add a haircut or a shave so customers can book.',
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
                  title: Text(s.name),
                  subtitle: Text(
                    '${duration(s.durationMinutes)} · ${money(s.priceCents)}',
                  ),
                  trailing: PopupMenuButton<String>(
                    onSelected: (v) async {
                      if (v == 'edit') {
                        await _edit(context, ref, s);
                      } else {
                        await ref
                            .read(catalogRepositoryProvider)
                            .archiveService(s.id);
                        ref.invalidate(servicesProvider(shop.id));
                      }
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'edit', child: Text('Edit')),
                      PopupMenuItem(value: 'archive', child: Text('Remove')),
                    ],
                  ),
                  onTap: () => _edit(context, ref, s),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _ServiceSheet extends ConsumerStatefulWidget {
  const _ServiceSheet({required this.shopId, this.existing});

  final String shopId;
  final Service? existing;

  @override
  ConsumerState<_ServiceSheet> createState() => _ServiceSheetState();
}

class _ServiceSheetState extends ConsumerState<_ServiceSheet> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.existing?.name ?? '');
  late final _minutes = TextEditingController(
    text: '${widget.existing?.durationMinutes ?? 30}',
  );
  late final _price = TextEditingController(
    text: widget.existing == null
        ? ''
        : (widget.existing!.priceCents / 100).toStringAsFixed(2),
  );
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _minutes.dispose();
    _price.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      await ref.read(catalogRepositoryProvider).saveService(
            id: widget.existing?.id,
            shopId: widget.shopId,
            name: _name.text.trim(),
            durationMinutes: int.parse(_minutes.text),
            priceCents: (double.parse(_price.text) * 100).round(),
          );
      if (mounted) Navigator.pop(context, true);
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
            Text(
              widget.existing == null ? 'New service' : 'Edit service',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Name'),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _minutes,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Minutes',
                      suffixText: 'min',
                    ),
                    validator: (v) {
                      final n = int.tryParse(v ?? '');
                      return (n == null || n <= 0) ? 'Invalid' : null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _price,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Price',
                      prefixText: '\$ ',
                    ),
                    validator: (v) {
                      final n = double.tryParse(v ?? '');
                      return (n == null || n < 0) ? 'Invalid' : null;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _busy ? null : _save,
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}
