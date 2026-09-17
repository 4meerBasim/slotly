import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/async_view.dart';
import '../../data/catalog_repository.dart';
import '../../models/shop.dart';
import '../profile_page.dart';
import 'create_shop_page.dart';
import 'schedule_page.dart';
import 'services_page.dart';
import 'team_page.dart';

class OwnerHome extends ConsumerWidget {
  const OwnerHome({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shop = ref.watch(myShopProvider);

    return AsyncView(
      value: shop,
      onRetry: () => ref.invalidate(myShopProvider),
      // An owner with no shop yet is sent straight to setup rather than
      // dropped into empty tabs they cannot fill.
      data: (s) => s == null ? const CreateShopPage() : _OwnerTabs(shop: s),
    );
  }
}

class _OwnerTabs extends StatefulWidget {
  const _OwnerTabs({required this.shop});

  final Shop shop;

  @override
  State<_OwnerTabs> createState() => _OwnerTabsState();
}

class _OwnerTabsState extends State<_OwnerTabs> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      SchedulePage(shop: widget.shop),
      ServicesPage(shop: widget.shop),
      TeamPage(shop: widget.shop),
      const ProfilePage(),
    ];

    return Scaffold(
      body: IndexedStack(index: _index, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.calendar_today_outlined),
            selectedIcon: Icon(Icons.calendar_today),
            label: 'Schedule',
          ),
          NavigationDestination(
            icon: Icon(Icons.content_cut_outlined),
            selectedIcon: Icon(Icons.content_cut),
            label: 'Services',
          ),
          NavigationDestination(
            icon: Icon(Icons.groups_outlined),
            selectedIcon: Icon(Icons.groups),
            label: 'Team',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
