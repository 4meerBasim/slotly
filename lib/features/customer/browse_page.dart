import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/async_view.dart';
import '../../data/catalog_repository.dart';
import '../../models/shop.dart';
import 'shop_detail_page.dart';

class BrowsePage extends ConsumerStatefulWidget {
  const BrowsePage({super.key});

  @override
  ConsumerState<BrowsePage> createState() => _BrowsePageState();
}

class _BrowsePageState extends ConsumerState<BrowsePage> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final shops = ref.watch(shopsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Find a barber')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: SearchBar(
              hintText: 'Search shops',
              leading: const Icon(Icons.search),
              onChanged: (v) => setState(() => _query = v.toLowerCase()),
              elevation: const WidgetStatePropertyAll(0),
            ),
          ),
          Expanded(
            child: AsyncView(
              value: shops,
              onRetry: () => ref.invalidate(shopsProvider),
              data: (all) {
                final visible = all
                    .where((s) =>
                        _query.isEmpty ||
                        s.name.toLowerCase().contains(_query) ||
                        (s.address ?? '').toLowerCase().contains(_query))
                    .toList();

                if (visible.isEmpty) {
                  return EmptyState(
                    icon: Icons.storefront_outlined,
                    title: all.isEmpty ? 'No shops yet' : 'No matches',
                    message: all.isEmpty
                        ? 'Shops will appear here once owners add them.'
                        : 'Try a different search.',
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async => ref.invalidate(shopsProvider),
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                    itemCount: visible.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (_, i) => _ShopCard(shop: visible[i]),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ShopCard extends StatelessWidget {
  const _ShopCard({required this.shop});

  final Shop shop;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => ShopDetailPage(shop: shop)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                height: 56,
                width: 56,
                decoration: BoxDecoration(
                  color: scheme.primaryContainer,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(Icons.content_cut,
                    color: scheme.onPrimaryContainer),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      shop.name,
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    if (shop.address != null && shop.address!.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        shop.address!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: scheme.onSurfaceVariant),
                      ),
                    ],
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: scheme.outline),
            ],
          ),
        ),
      ),
    );
  }
}
