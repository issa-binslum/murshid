import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/auth_controller.dart';
import '../../core/api/api_client.dart';

final receiptsProvider = FutureProvider<List<Receipt>>((ref) async {
  final auth = ref.watch(authControllerProvider);
  final token = auth.accessToken;
  if (token == null) throw Exception('Missing access token');
  return ref.read(apiClientProvider).getReceipts(accessToken: token);
});

final accountsProvider = FutureProvider<List<Account>>((ref) async {
  final auth = ref.watch(authControllerProvider);
  final token = auth.accessToken;
  if (token == null) throw Exception('Missing access token');
  return ref.read(apiClientProvider).getAccounts(accessToken: token);
});

class ReceiptsScreen extends ConsumerWidget {
  const ReceiptsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final receipts = ref.watch(receiptsProvider);
    return Scaffold(
      appBar: AppBar(
        leading: Navigator.canPop(context) ? const BackButton() : null,
        title: const Text('Receipts'),
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
          child: receipts.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Failed to load receipts: $e')),
            data: (list) => list.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('No receipts found'),
                        const SizedBox(height: 12),
                        ElevatedButton(
                          onPressed: () => _showCreateDialog(context, ref),
                          child: const Text('Create Receipt'),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: list.length,
                    itemBuilder: (context, i) {
                      final receipt = list[i];
                      return ListTile(
                        title: Text('${receipt.amount}'),
                        subtitle:
                            Text('${receipt.description} - ${receipt.date}'),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete),
                          onPressed: () =>
                              _deleteReceipt(context, ref, receipt.id),
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
          title: const Text('Create Receipt'),
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
                  await ref.read(apiClientProvider).createReceipt(
                        accessToken: token,
                        accountId: selectedAccountId!,
                        amount: num.parse(amountController.text),
                        description: descriptionController.text,
                        date: selectedDate,
                      );
                  ref.invalidate(receiptsProvider);
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

  void _deleteReceipt(BuildContext context, WidgetRef ref, String id) async {
    try {
      final auth = ref.read(authControllerProvider);
      final token = auth.accessToken!;
      await ref
          .read(apiClientProvider)
          .deleteReceipt(accessToken: token, id: id);
      ref.invalidate(receiptsProvider);
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Failed: $e')));
    }
  }
}
