import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:truck_account_book/core/theme/app_theme.dart';
import 'package:truck_account_book/core/widgets/shared_widgets.dart';
import 'package:truck_account_book/data/repositories/customer_repository.dart';

class CustomerListScreen extends ConsumerWidget {
  const CustomerListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ledgers = ref.watch(customerLedgerListProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Customers')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddCustomerSheet(context, ref),
        icon: const Icon(Icons.person_add),
        label: const Text('Add Customer'),
      ),
      body: ledgers.when(
        data: (list) {
          if (list.isEmpty) {
            return const EmptyState(
              icon: Icons.people_outline,
              title: 'No customers yet',
              subtitle: 'Customers are added automatically when you create a trip,\nor you can add one directly.',
            );
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(customerLedgerListProvider),
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: list.length,
              itemBuilder: (context, i) {
                final l = list[i];
                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: AppColors.primaryBlue.withValues(alpha: 0.12),
                      child: Text(l.customer.name.isNotEmpty ? l.customer.name[0].toUpperCase() : '?',
                          style: const TextStyle(color: AppColors.primaryBlue, fontWeight: FontWeight.w700)),
                    ),
                    title: Row(
                      children: [
                        Flexible(child: Text(l.customer.name, style: const TextStyle(fontWeight: FontWeight.w600))),
                        if (l.customer.isFavorite) ...[
                          const SizedBox(width: 6),
                          const Icon(Icons.star, color: Colors.amber, size: 16),
                        ],
                      ],
                    ),
                    subtitle: Text(l.customer.phone ?? 'No phone number'),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          formatMoney(l.pendingAmount),
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: l.pendingAmount > 0 ? AppColors.pendingRed : AppColors.profitGreen,
                          ),
                        ),
                        const Text('pending', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                      ],
                    ),
                    onTap: () => context.push('/customers/${l.customer.id}'),
                  ),
                );
              },
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('Error: $e')),
      ),
    );
  }

  void _showAddCustomerSheet(BuildContext context, WidgetRef ref) {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 20, right: 20, top: 20,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Add Customer', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Name')),
            const SizedBox(height: 12),
            TextField(controller: phoneCtrl, decoration: const InputDecoration(labelText: 'Phone (optional)')),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () async {
                if (nameCtrl.text.trim().isEmpty) return;
                await ref.read(customerRepositoryProvider).createCustomer(
                      name: nameCtrl.text.trim(),
                      phone: phoneCtrl.text.trim().isEmpty ? null : phoneCtrl.text.trim(),
                    );
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}
