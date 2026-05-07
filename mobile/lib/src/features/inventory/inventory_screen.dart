import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/auth_controller.dart';
import '../../core/api/api_client.dart';

final inventoryProvider = FutureProvider<List<InventoryItem>>((ref) async {
  final auth = ref.watch(authControllerProvider);
  final token = auth.accessToken;
  if (token == null) throw Exception('Missing access token');
  return ref.read(apiClientProvider).getInventory(accessToken: token);
});

class InventoryScreen extends ConsumerWidget {
  const InventoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inventory = ref.watch(inventoryProvider);
    return Scaffold(
      appBar: AppBar(
        leading: Navigator.canPop(context) ? const BackButton() : null,
        title: const Text('Inventory'),
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
          child: inventory.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) =>
                Center(child: Text('Failed to load inventory: $e')),
            data: (list) => list.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('No inventory items found'),
                        const SizedBox(height: 12),
                        ElevatedButton(
                          onPressed: () => _showCreateDialog(context, ref),
                          child: const Text('Create Item'),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: list.length,
                    itemBuilder: (context, i) {
                      final item = list[i];
                      return ListTile(
                        title: Text(item.name),
                        subtitle: Text(
                            '${item.quantity} ${item.unit} (Low: ${item.lowStockLevel})'),
                        trailing: PopupMenuButton(
                          itemBuilder: (context) => [
                            const PopupMenuItem(
                                value: 'edit', child: Text('Edit')),
                            const PopupMenuItem(
                                value: 'adjust', child: Text('Adjust Stock')),
                            const PopupMenuItem(
                                value: 'movements',
                                child: Text('View Movements')),
                            const PopupMenuItem(
                                value: 'delete', child: Text('Delete')),
                          ],
                          onSelected: (value) {
                            if (value == 'edit') {
                              _showEditDialog(context, ref, item);
                            } else if (value == 'adjust') {
                              _showAdjustDialog(context, ref, item);
                            } else if (value == 'movements') {
                              _showMovementsDialog(context, ref, item);
                            } else if (value == 'delete') {
                              _deleteItem(context, ref, item.id);
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
    final descriptionController = TextEditingController();
    final quantityController = TextEditingController();
    final unitController = TextEditingController();
    final lowStockController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create Inventory Item'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Name')),
            TextField(
                controller: descriptionController,
                decoration: const InputDecoration(labelText: 'Description')),
            TextField(
                controller: quantityController,
                decoration: const InputDecoration(labelText: 'Quantity'),
                keyboardType: TextInputType.number),
            TextField(
                controller: unitController,
                decoration: const InputDecoration(labelText: 'Unit')),
            TextField(
                controller: lowStockController,
                decoration: const InputDecoration(labelText: 'Low Stock Level'),
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
                await ref.read(apiClientProvider).createInventoryItem(
                      accessToken: token,
                      name: nameController.text,
                      description: descriptionController.text.isEmpty
                          ? null
                          : descriptionController.text,
                      quantity: num.parse(quantityController.text),
                      unit: unitController.text,
                      lowStockLevel: num.parse(lowStockController.text),
                    );
                ref.invalidate(inventoryProvider);
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

  void _showEditDialog(
      BuildContext context, WidgetRef ref, InventoryItem item) {
    final nameController = TextEditingController(text: item.name);
    final descriptionController = TextEditingController(text: item.description);
    final lowStockController =
        TextEditingController(text: item.lowStockLevel.toString());
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Inventory Item'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Name')),
            TextField(
                controller: descriptionController,
                decoration: const InputDecoration(labelText: 'Description')),
            TextField(
                controller: lowStockController,
                decoration: const InputDecoration(labelText: 'Low Stock Level'),
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
                await ref.read(apiClientProvider).updateInventoryItem(
                      accessToken: token,
                      id: item.id,
                      name: nameController.text,
                      description: descriptionController.text.isEmpty
                          ? null
                          : descriptionController.text,
                      lowStockLevel: num.parse(lowStockController.text),
                    );
                ref.invalidate(inventoryProvider);
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

  void _showAdjustDialog(
      BuildContext context, WidgetRef ref, InventoryItem item) {
    final quantityController = TextEditingController();
    final reasonController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Adjust Stock'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
                controller: quantityController,
                decoration: const InputDecoration(labelText: 'Quantity Change'),
                keyboardType: TextInputType.number),
            TextField(
                controller: reasonController,
                decoration: const InputDecoration(labelText: 'Reason')),
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
                await ref.read(apiClientProvider).adjustInventory(
                      accessToken: token,
                      itemId: item.id,
                      quantity: num.parse(quantityController.text),
                      reason: reasonController.text,
                    );
                ref.invalidate(inventoryProvider);
                Navigator.of(context).pop();
              } catch (e) {
                ScaffoldMessenger.of(context)
                    .showSnackBar(SnackBar(content: Text('Failed: $e')));
              }
            },
            child: const Text('Adjust'),
          ),
        ],
      ),
    );
  }

  void _showMovementsDialog(
      BuildContext context, WidgetRef ref, InventoryItem item) async {
    try {
      final auth = ref.read(authControllerProvider);
      final token = auth.accessToken!;
      final movements = await ref
          .read(apiClientProvider)
          .getInventoryMovements(accessToken: token, itemId: item.id);
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Movements for ${item.name}'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: movements.length,
              itemBuilder: (context, i) {
                final movement = movements[i];
                return ListTile(
                  title: Text('${movement.type} ${movement.quantity}'),
                  subtitle: Text('${movement.reason} - ${movement.createdAt}'),
                );
              },
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close')),
          ],
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load movements: $e')));
    }
  }

  void _deleteItem(BuildContext context, WidgetRef ref, String id) async {
    try {
      final auth = ref.read(authControllerProvider);
      final token = auth.accessToken!;
      await ref
          .read(apiClientProvider)
          .deleteInventoryItem(accessToken: token, id: id);
      ref.invalidate(inventoryProvider);
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Failed: $e')));
    }
  }
}
