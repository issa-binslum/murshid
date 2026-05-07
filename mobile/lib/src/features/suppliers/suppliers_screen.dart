import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/auth_controller.dart';
import '../../core/api/api_client.dart';

final suppliersProvider = FutureProvider<List<Supplier>>((ref) async {
  final auth = ref.watch(authControllerProvider);
  final token = auth.accessToken;
  if (token == null) throw Exception('Missing access token');
  return ref.read(apiClientProvider).getSuppliers(accessToken: token);
});

class SuppliersScreen extends ConsumerWidget {
  const SuppliersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final suppliers = ref.watch(suppliersProvider);
    return Scaffold(
      appBar: AppBar(
        leading: Navigator.canPop(context) ? const BackButton() : null,
        title: const Text('Suppliers'),
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
          child: suppliers.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) =>
                Center(child: Text('Failed to load suppliers: $e')),
            data: (list) => list.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('No suppliers found'),
                        const SizedBox(height: 12),
                        ElevatedButton(
                          onPressed: () => _showCreateDialog(context, ref),
                          child: const Text('Create Supplier'),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: list.length,
                    itemBuilder: (context, i) {
                      final supplier = list[i];
                      return ListTile(
                        title: Text(supplier.name),
                        subtitle: Text(
                            '${supplier.phone ?? ''} ${supplier.email ?? ''}'),
                        trailing: PopupMenuButton(
                          itemBuilder: (context) => [
                            const PopupMenuItem(
                                value: 'edit', child: Text('Edit')),
                            const PopupMenuItem(
                                value: 'delete', child: Text('Delete')),
                          ],
                          onSelected: (value) {
                            if (value == 'edit') {
                              _showEditDialog(context, ref, supplier);
                            } else if (value == 'delete') {
                              _deleteSupplier(context, ref, supplier.id);
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
    final phoneController = TextEditingController();
    final emailController = TextEditingController();
    final addressController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create Supplier'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Name')),
            TextField(
                controller: phoneController,
                decoration: const InputDecoration(labelText: 'Phone')),
            TextField(
                controller: emailController,
                decoration: const InputDecoration(labelText: 'Email')),
            TextField(
                controller: addressController,
                decoration: const InputDecoration(labelText: 'Address')),
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
                await ref.read(apiClientProvider).createSupplier(
                      accessToken: token,
                      name: nameController.text,
                      phone: phoneController.text.isEmpty
                          ? null
                          : phoneController.text,
                      email: emailController.text.isEmpty
                          ? null
                          : emailController.text,
                      address: addressController.text.isEmpty
                          ? null
                          : addressController.text,
                    );
                ref.invalidate(suppliersProvider);
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

  void _showEditDialog(BuildContext context, WidgetRef ref, Supplier supplier) {
    final nameController = TextEditingController(text: supplier.name);
    final phoneController = TextEditingController(text: supplier.phone);
    final emailController = TextEditingController(text: supplier.email);
    final addressController = TextEditingController(text: supplier.address);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Supplier'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Name')),
            TextField(
                controller: phoneController,
                decoration: const InputDecoration(labelText: 'Phone')),
            TextField(
                controller: emailController,
                decoration: const InputDecoration(labelText: 'Email')),
            TextField(
                controller: addressController,
                decoration: const InputDecoration(labelText: 'Address')),
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
                await ref.read(apiClientProvider).updateSupplier(
                      accessToken: token,
                      id: supplier.id,
                      name: nameController.text,
                      phone: phoneController.text.isEmpty
                          ? null
                          : phoneController.text,
                      email: emailController.text.isEmpty
                          ? null
                          : emailController.text,
                      address: addressController.text.isEmpty
                          ? null
                          : addressController.text,
                    );
                ref.invalidate(suppliersProvider);
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

  void _deleteSupplier(BuildContext context, WidgetRef ref, String id) async {
    try {
      final auth = ref.read(authControllerProvider);
      final token = auth.accessToken!;
      await ref
          .read(apiClientProvider)
          .deleteSupplier(accessToken: token, id: id);
      ref.invalidate(suppliersProvider);
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Failed: $e')));
    }
  }
}
