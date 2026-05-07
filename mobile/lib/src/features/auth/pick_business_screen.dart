import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../auth/auth_controller.dart';

class PickBusinessScreen extends ConsumerWidget {
  const PickBusinessScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(authControllerProvider);
    final notifier = ref.read(authControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Business'),
        actions: [
          TextButton(
            onPressed: () => notifier.logout(),
            child: const Text('Logout'),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: state.businesses.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, i) {
            final b = state.businesses[i];
            return Card(
              child: ListTile(
                title: Text(b.businessName),
                subtitle: Text('${b.roleName} • ${b.currency}'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () async {
                  try {
                    await notifier.switchBusiness(b.businessId);
                    context.go('/');
                  } catch (_) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Failed to switch business.')),
                    );
                  }
                },
              ),
            );
          },
        ),
      ),
    );
  }
}
