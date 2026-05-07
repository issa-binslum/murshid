import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../auth/auth_controller.dart';
import '../../core/api/api_client.dart';

final dashboardSummaryProvider = FutureProvider<DashboardSummary>((ref) async {
  final auth = ref.watch(authControllerProvider);
  final token = auth.accessToken;
  if (token == null) throw Exception('Missing access token');
  return ref.read(apiClientProvider).dashboardSummary(accessToken: token);
});

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(dashboardSummaryProvider);
    return Scaffold(
      appBar: AppBar(
        leading: Navigator.canPop(context) ? const BackButton() : null,
        title: const Text('Dashboard'),
        actions: [
          TextButton(
            onPressed: () => ref.read(authControllerProvider.notifier).logout(),
            child: const Text('Logout'),
          )
        ],
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const DrawerHeader(
              decoration: BoxDecoration(color: Colors.indigo),
              child: Text('Navigation',
                  style: TextStyle(color: Colors.white, fontSize: 20)),
            ),
            ListTile(
              leading: const Icon(Icons.dashboard),
              title: const Text('Dashboard'),
              onTap: () {
                Navigator.of(context).pop();
                context.go('/');
              },
            ),
            ListTile(
              leading: const Icon(Icons.account_balance),
              title: const Text('Accounts'),
              onTap: () {
                Navigator.of(context).pop();
                context.go('/accounts');
              },
            ),
            ListTile(
              leading: const Icon(Icons.person),
              title: const Text('Customers'),
              onTap: () {
                Navigator.of(context).pop();
                context.go('/customers');
              },
            ),
            ListTile(
              leading: const Icon(Icons.local_shipping),
              title: const Text('Suppliers'),
              onTap: () {
                Navigator.of(context).pop();
                context.go('/suppliers');
              },
            ),
            ListTile(
              leading: const Icon(Icons.inventory),
              title: const Text('Inventory'),
              onTap: () {
                Navigator.of(context).pop();
                context.go('/inventory');
              },
            ),
            ListTile(
              leading: const Icon(Icons.receipt),
              title: const Text('Receipts'),
              onTap: () {
                Navigator.of(context).pop();
                context.go('/receipts');
              },
            ),
            ListTile(
              leading: const Icon(Icons.payment),
              title: const Text('Payments'),
              onTap: () {
                Navigator.of(context).pop();
                context.go('/payments');
              },
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: summary.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) =>
                Center(child: Text('Failed to load dashboard: $e')),
            data: (s) => ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _KpiCard(title: 'Total sales', value: s.totalSales.toString()),
                _KpiCard(
                    title: 'Total purchases',
                    value: s.totalPurchases.toString()),
                _KpiCard(
                    title: 'Total receipts',
                    value: s.totalReceipts.toString(),
                    onTap: () => context.go('/receipts')),
                _KpiCard(
                    title: 'Total payments',
                    value: s.totalPayments.toString(),
                    onTap: () => context.go('/payments')),
                const SizedBox(height: 12),
                _KpiCard(
                    title: 'Customers',
                    value: s.customersCount.toString(),
                    onTap: () => context.go('/customers')),
                _KpiCard(
                    title: 'Suppliers',
                    value: s.suppliersCount.toString(),
                    onTap: () => context.go('/suppliers')),
                _KpiCard(
                    title: 'Low stock items',
                    value: s.lowStockItemsCount.toString(),
                    onTap: () => context.go('/inventory')),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({required this.title, required this.value, this.onTap});

  final String title;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        title: Text(title),
        trailing:
            Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        onTap: onTap,
      ),
    );
  }
}
