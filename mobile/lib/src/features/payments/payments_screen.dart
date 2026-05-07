import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/auth_controller.dart';
import '../../core/api/api_client.dart';

final paymentsProvider = FutureProvider<List<Payment>>((ref) async {
  final auth = ref.watch(authControllerProvider);
  final token = auth.accessToken;
  if (token == null) throw Exception('Missing access token');
  return ref.read(apiClientProvider).getPayments(accessToken: token);
});

final accountsProvider = FutureProvider<List<Account>>((ref) async {
  final auth = ref.watch(authControllerProvider);
  final token = auth.accessToken;
  if (token == null) throw Exception('Missing access token');
  return ref.read(apiClientProvider).getAccounts(accessToken: token);
});

class PaymentsScreen extends ConsumerWidget {
  const PaymentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final payments = ref.watch(paymentsProvider);
    return Scaffold(
      appBar: AppBar(
        leading: Navigator.canPop(context) ? const BackButton() : null,
        title: const Text('Payments'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showCreateDialog(context, ref),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCreateDialog(context, ref),
        child: const Icon(Icons.add),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: payments.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Failed to load payments: $e')),
            data: (list) => list.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('No payments found'),
                        const SizedBox(height: 12),
                        ElevatedButton(
                          onPressed: () => _showCreateDialog(context, ref),
                          child: const Text('Create Payment'),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: list.length,
                    itemBuilder: (context, i) {
                      final payment = list[i];
                      return ListTile(
                        title: Text('${payment.amount}'),
                        subtitle:
                            Text('${payment.description} - ${payment.date}'),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete),
                          onPressed: () =>
                              _deletePayment(context, ref, payment.id),
                        ),
                      );
                    },
                  ),
          ),
        ),
      ),
    );
  }

  void _showCreateDialog(BuildContext context, WidgetRef ref) async {
    final accounts = await ref.read(accountsProvider.future);
    if (accounts.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('No accounts available')));
      return;
    }
    String? selectedAccountId = accounts.first.id;
    final amountController = TextEditingController();
    final descriptionController = TextEditingController();
    DateTime selectedDate = DateTime.now();
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Create Payment'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButton<String>(
                value: selectedAccountId,
                items: accounts
                    .map((a) => DropdownMenuItem(
                        value: a.id, child: Text(a.accountName)))
                    .toList(),
                onChanged: (value) => setState(() => selectedAccountId = value),
              ),
              TextField(
                  controller: amountController,
                  decoration: const InputDecoration(labelText: 'Amount'),
                  keyboardType: TextInputType.number),
              TextField(
                  controller: descriptionController,
                  decoration: const InputDecoration(labelText: 'Description')),
              Row(
                children: [
                  Text('Date: ${selectedDate.toLocal()}'.split(' ')[0]),
                  IconButton(
                    icon: const Icon(Icons.calendar_today),
                    onPressed: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: selectedDate,
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2101),
                      );
                      if (date != null) setState(() => selectedDate = date);
                    },
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel')),
            TextButton(
              onPressed: () async {
                try {
                  final auth = ref.read(authControllerProvider);
                  final token = auth.accessToken!;
                  await ref.read(apiClientProvider).createPayment(
                        accessToken: token,
                        accountId: selectedAccountId!,
                        amount: num.parse(amountController.text),
                        description: descriptionController.text,
                        date: selectedDate,
                      );
                  ref.invalidate(paymentsProvider);
                  Navigator.of(context).pop();
                } catch (e) {
                  ScaffoldMessenger.of(context)
                      .showSnackBar(SnackBar(content: Text('Failed: $e')));
                }
              },
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
  }

  void _deletePayment(BuildContext context, WidgetRef ref, String id) async {
    try {
      final auth = ref.read(authControllerProvider);
      final token = auth.accessToken!;
      await ref
          .read(apiClientProvider)
          .deletePayment(accessToken: token, id: id);
      ref.invalidate(paymentsProvider);
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Failed: $e')));
    }
  }
}
