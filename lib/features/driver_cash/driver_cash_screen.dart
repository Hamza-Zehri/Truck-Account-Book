import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:truck_account_book/core/theme/app_theme.dart';
import 'package:truck_account_book/core/widgets/shared_widgets.dart';
import 'package:truck_account_book/data/repositories/driver_cash_repository.dart';
import 'package:truck_account_book/data/repositories/report_repository.dart';

class DriverCashScreen extends ConsumerWidget {
  const DriverCashScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncCash = ref.watch(allDriverCashProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Driver Cash')),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton.small(
            heroTag: 'advance',
            backgroundColor: AppColors.expenseOrange,
            onPressed: () => _showDialog(context, ref, isAdvance: true),
            child: const Icon(Icons.arrow_upward),
          ),
          const SizedBox(height: 8),
          FloatingActionButton.small(
            heroTag: 'recovery',
            backgroundColor: AppColors.profitGreen,
            onPressed: () => _showDialog(context, ref, isAdvance: false),
            child: const Icon(Icons.arrow_downward),
          ),
        ],
      ),
      body: asyncCash.when(
        data: (list) {
          if (list.isEmpty) {
            return const EmptyState(
              icon: Icons.account_balance_wallet_outlined,
              title: 'No transactions',
              subtitle: 'Tap + to record an advance or recovery.',
            );
          }
          final net = list.fold<double>(0, (sum, c) => sum + c.amount);
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(allDriverCashProvider),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  color: net >= 0
                      ? AppColors.expenseOrange.withValues(alpha: 0.06)
                      : AppColors.profitGreen.withValues(alpha: 0.06),
                  child: ListTile(
                    leading: Icon(
                      net >= 0 ? Icons.arrow_upward : Icons.arrow_downward,
                      color: net >= 0 ? AppColors.expenseOrange : AppColors.profitGreen,
                    ),
                    title: Text(
                      net >= 0 ? 'Outstanding Advances' : 'Excess Recovered',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    trailing: Text(
                      formatMoney(net.abs()),
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        color: net >= 0 ? AppColors.expenseOrange : AppColors.profitGreen,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                const SectionHeader(title: 'All Transactions'),
                ...list.map((c) {
                  final isAdvance = c.amount >= 0;
                  return Dismissible(
                    key: ValueKey('driver-cash-${c.id}'),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      color: AppColors.pendingRed,
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: const Icon(Icons.delete, color: Colors.white),
                    ),
                    confirmDismiss: (_) async {
                      return await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: Text(isAdvance ? 'Delete advance?' : 'Delete recovery?'),
                          content: Text('Remove ${formatMoney(c.amount.abs())}?'),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, true),
                              child: const Text('Delete', style: TextStyle(color: AppColors.pendingRed)),
                            ),
                          ],
                        ),
                      );
                    },
                    onDismissed: (_) {
                      ref.read(driverCashRepositoryProvider).deleteDriverCash(c.id);
                      ref.read(dashboardRefreshTickerProvider.notifier).state++;
                    },
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        backgroundColor: isAdvance
                            ? AppColors.expenseOrange.withValues(alpha: 0.15)
                            : AppColors.profitGreen.withValues(alpha: 0.15),
                        child: Icon(
                          isAdvance ? Icons.arrow_upward : Icons.arrow_downward,
                          color: isAdvance ? AppColors.expenseOrange : AppColors.profitGreen,
                          size: 18,
                        ),
                      ),
                      title: Text(isAdvance ? 'Cash to Driver' : 'Cash Recovered'),
                      subtitle: Text(formatDate(c.date)),
                      trailing: Text(
                        isAdvance ? '-${formatMoney(c.amount)}' : formatMoney(c.amount.abs()),
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: isAdvance ? AppColors.expenseOrange : AppColors.profitGreen,
                        ),
                      ),
                    ),
                  );
                }),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('Error: $e')),
      ),
    );
  }

  Future<void> _showDialog(BuildContext context, WidgetRef ref, {required bool isAdvance}) async {
    final amountCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    DateTime date = DateTime.now();

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: Text(isAdvance ? 'Cash to Driver' : 'Cash Recovery'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: amountCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(labelText: isAdvance ? 'Amount given' : 'Amount recovered'),
              ),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Date'),
                subtitle: Text(formatDate(date)),
                trailing: const Icon(Icons.calendar_today, size: 18),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: ctx,
                    initialDate: date,
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now().add(const Duration(days: 1)),
                  );
                  if (picked != null) setState(() => date = picked);
                },
              ),
              TextField(
                controller: notesCtrl,
                decoration: const InputDecoration(labelText: 'Notes (optional)'),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            TextButton(
              onPressed: () async {
                final amount = double.tryParse(amountCtrl.text.trim());
                if (amount == null || amount <= 0) return;
                final repo = ref.read(driverCashRepositoryProvider);
                if (isAdvance) {
                  await repo.addAdvance(amount, date,
                      notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim());
                } else {
                  await repo.addRecovery(amount, date,
                      notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim());
                }
                ref.read(dashboardRefreshTickerProvider.notifier).state++;
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
