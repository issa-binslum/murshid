import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/auth_controller.dart';
import '../../core/api/api_client.dart';

final accountsProvider = FutureProvider<List<Account>>((ref) async {
  final auth = ref.watch(authControllerProvider);
  final token = auth.accessToken;
  if (token == null) throw Exception('Missing access token');
  return ref.read(apiClientProvider).getAccounts(accessToken: token);
});

class AccountsScreen extends ConsumerWidget {
  const AccountsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accounts = ref.watch(accountsProvider);
    return Scaffold(
      appBar: AppBar(
        leading: Navigator.canPop(context) ? const BackButton() : null,
        title: const Text('Accounts'),
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
          child: accounts.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Failed to load accounts: $e')),
            data: (list) => list.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('No accounts found'),
                        const SizedBox(height: 12),
                        ElevatedButton(
                          onPressed: () => _showCreateDialog(context, ref),
                          child: const Text('Create Account'),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: list.length,
                    itemBuilder: (context, i) {
                      final account = list[i];
                      return ListTile(
                        title: Text(account.accountName),
                        subtitle: Text(
                            '${account.type} • ${account.currentBalance} balance'),
                        trailing: PopupMenuButton(
                          itemBuilder: (context) => [
                            const PopupMenuItem(
                                value: 'edit', child: Text('Edit')),
                            const PopupMenuItem(
                                value: 'delete', child: Text('Delete')),
                          ],
                          onSelected: (value) {
                            if (value == 'edit') {
                              _showEditDialog(context, ref, account);
                            } else if (value == 'delete') {
                              _deleteAccount(context, ref, account.id);
                            }
                          },
                        ),
                      );
                    },
                  ),
          ),
        ),
      ),
    );
  }

  void _showCreateDialog(BuildContext context, WidgetRef ref) {
    final nameController = TextEditingController();
    String selectedType = 'BANK';
    final bankNameController = TextEditingController();
    final accountNumberController = TextEditingController();
    final openingBalanceController = TextEditingController(text: '0');
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create Account'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Account Name')),
            DropdownButtonFormField<String>(
              value: selectedType,
              items: const [
                DropdownMenuItem(value: 'BANK', child: Text('Bank')),
                DropdownMenuItem(value: 'CASH', child: Text('Cash')),
                DropdownMenuItem(
                    value: 'MOBILE_WALLET', child: Text('Mobile Wallet')),
              ],
              onChanged: (value) {
                if (value != null) selectedType = value;
              },
              decoration: const InputDecoration(labelText: 'Type'),
            ),
            TextField(
                controller: bankNameController,
                decoration:
                    const InputDecoration(labelText: 'Bank Name (optional)')),
            TextField(
                controller: accountNumberController,
                decoration: const InputDecoration(
                    labelText: 'Account Number (optional)')),
            TextField(
                controller: openingBalanceController,
                decoration: const InputDecoration(labelText: 'Opening Balance'),
                keyboardType: TextInputType.number),
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
                await ref.read(apiClientProvider).createAccount(
                      accessToken: token,
                      accountName: nameController.text,
                      type: selectedType,
                      bankName: bankNameController.text.isEmpty
                          ? null
                          : bankNameController.text,
                      accountNumber: accountNumberController.text.isEmpty
                          ? null
                          : accountNumberController.text,
                      openingBalance: num.parse(openingBalanceController.text),
                    );
                ref.invalidate(accountsProvider);
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
    );
  }

  void _showEditDialog(BuildContext context, WidgetRef ref, Account account) {
    final nameController = TextEditingController(text: account.accountName);
    String selectedType = account.type;
    final bankNameController = TextEditingController(text: account.bankName);
    final accountNumberController =
        TextEditingController(text: account.accountNumber);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Account'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Account Name')),
            DropdownButtonFormField<String>(
              value: selectedType,
              items: const [
                DropdownMenuItem(value: 'BANK', child: Text('Bank')),
                DropdownMenuItem(value: 'CASH', child: Text('Cash')),
                DropdownMenuItem(
                    value: 'MOBILE_WALLET', child: Text('Mobile Wallet')),
              ],
              onChanged: (value) {
                if (value != null) selectedType = value;
              },
              decoration: const InputDecoration(labelText: 'Type'),
            ),
            TextField(
                controller: bankNameController,
                decoration:
                    const InputDecoration(labelText: 'Bank Name (optional)')),
            TextField(
                controller: accountNumberController,
                decoration: const InputDecoration(
                    labelText: 'Account Number (optional)')),
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
                await ref.read(apiClientProvider).updateAccount(
                      accessToken: token,
                      id: account.id,
                      accountName: nameController.text,
                      type: selectedType,
                      bankName: bankNameController.text.isEmpty
                          ? null
                          : bankNameController.text,
                      accountNumber: accountNumberController.text.isEmpty
                          ? null
                          : accountNumberController.text,
                    );
                ref.invalidate(accountsProvider);
                Navigator.of(context).pop();
              } catch (e) {
                ScaffoldMessenger.of(context)
                    .showSnackBar(SnackBar(content: Text('Failed: $e')));
              }
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  void _deleteAccount(BuildContext context, WidgetRef ref, String id) async {
    try {
      final auth = ref.read(authControllerProvider);
      final token = auth.accessToken!;
      await ref
          .read(apiClientProvider)
          .deleteAccount(accessToken: token, id: id);
      ref.invalidate(accountsProvider);
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Failed: $e')));
    }
  }
}
