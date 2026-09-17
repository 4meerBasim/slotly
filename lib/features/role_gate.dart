import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/async_view.dart';
import '../data/auth_repository.dart';
import 'customer/customer_home.dart';
import 'owner/owner_home.dart';

/// Decides which of the two apps the signed-in user actually sees.
class RoleGate extends ConsumerWidget {
  const RoleGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider);

    return AsyncView(
      value: profile,
      onRetry: () => ref.invalidate(profileProvider),
      data: (p) {
        if (p == null) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        return p.isOwner ? const OwnerHome() : const CustomerHome();
      },
    );
  }
}
