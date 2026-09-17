import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/async_view.dart';
import '../../core/formatters.dart';
import '../../data/catalog_repository.dart';
import '../../models/service.dart';
import '../../models/shop.dart';
import 'booking_flow_page.dart';

class ShopDetailPage extends ConsumerWidget {
  const ShopDetailPage({super.key, required this.shop});

  final Shop shop;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final services = ref.watch(servicesProvider(shop.id));
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text(shop.name)),
      body: AsyncView(
        value: services,
        onRetry: () => ref.invalidate(servicesProvider(shop.id)),
        data: (list) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            if (shop.description != null && shop.description!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(shop.description!,
                    style: TextStyle(color: scheme.onSurfaceVariant)),
              ),
            if (shop.address != null && shop.address!.isNotEmpty)
              _InfoRow(icon: Icons.place_outlined, text: shop.address!),
            if (shop.phone != null && shop.phone!.isNotEmpty)
              _InfoRow(icon: Icons.call_outlined, text: shop.phone!),
            const SizedBox(height: 20),
            Text('Services',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 10),
            if (list.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: EmptyState(
                  icon: Icons.content_cut,
                  title: 'No services listed',
                  message: 'This shop has not added anything bookable yet.',
                ),
              )
            else
              for (final service in list) ...[
                _ServiceTile(shop: shop, service: service),
                const SizedBox(height: 10),
              ],
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: scheme.outline),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: TextStyle(color: scheme.onSurfaceVariant)),
          ),
        ],
      ),
    );
  }
}

class _ServiceTile extends StatelessWidget {
  const _ServiceTile({required this.shop, required this.service});

  final Shop shop;
  final Service service;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => BookingFlowPage(shop: shop, service: service),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(service.name,
                        style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: 3),
                    Text(
                      duration(service.durationMinutes),
                      style: TextStyle(color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              Text(
                money(service.priceCents),
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right, color: scheme.outline),
            ],
          ),
        ),
      ),
    );
  }
}
