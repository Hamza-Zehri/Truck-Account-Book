import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:truck_account_book/core/constants/app_constants.dart';
import 'package:truck_account_book/core/theme/app_theme.dart';
import 'package:truck_account_book/core/widgets/shared_widgets.dart';
import 'package:truck_account_book/data/repositories/expense_repository.dart';
import 'package:truck_account_book/data/repositories/payment_repository.dart';
import 'package:truck_account_book/data/repositories/report_repository.dart';
import 'package:truck_account_book/data/repositories/trip_repository.dart';

class TripDetailScreen extends ConsumerWidget {
  final int tripId;
  const TripDetailScreen({super.key, required this.tripId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(_tripSummaryProvider(tripId));
    final expensesAsync = ref.watch(tripExpensesProvider(tripId));
    final paymentsAsync = ref.watch(tripPaymentsProvider(tripId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Trip Details'),
        actions: [
          summaryAsync.maybeWhen(
            data: (s) => s == null
                ? const SizedBox.shrink()
                : PopupMenuButton<String>(
                    onSelected: (v) async {
                      if (v == 'edit') {
                        context.push('/trips/$tripId/edit', extra: s.trip);
                      } else if (v == 'duplicate') {
                        await ref.read(tripRepositoryProvider).duplicateTrip(s.trip);
                        ref.read(dashboardRefreshTickerProvider.notifier).state++;
                        if (context.mounted) {
                          ScaffoldMessenger.of(context)
                              .showSnackBar(const SnackBar(content: Text('Trip duplicated')));
                        }
                      } else if (v == 'delete') {
                        final confirmed = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Delete trip?'),
                            content: const Text('This also removes its expenses and payments.'),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                              TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
                            ],
                          ),
                        );
                        if (confirmed == true) {
                          await ref.read(tripRepositoryProvider).deleteTrip(tripId);
                          if (context.mounted) context.pop();
                        }
                      }
                    },
                    itemBuilder: (context) => const [
                      PopupMenuItem(value: 'edit', child: Text('Edit')),
                      PopupMenuItem(value: 'duplicate', child: Text('Duplicate previous trip')),
                      PopupMenuItem(value: 'delete', child: Text('Delete')),
                    ],
                  ),
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
      body: summaryAsync.when(
        data: (s) {
          if (s == null) return const Center(child: Text('Trip not found'));
          final statusColor = switch (s.status.label) {
            'Paid' => AppColors.profitGreen,
            'Partial' => AppColors.expenseOrange,
            _ => AppColors.pendingRed,
          };
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(s.customer.name,
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                          StatusBadge(label: s.status.label, color: statusColor),
                        ],
                      ),
                      if (s.customer.phone != null && s.customer.phone!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(s.customer.phone!, style: const TextStyle(color: AppColors.textMuted)),
                        ),
                      const Divider(height: 24),
                      _row('Date', formatDate(s.trip.date)),
                      _row('Material', s.trip.materialType),
                      _row('Quantity', s.trip.quantity),
                      _row('Trip Amount', formatMoney(s.trip.tripAmount)),
                      _row('Total Expenses', formatMoney(s.totalExpenses), color: AppColors.expenseOrange),
                      _row('Profit', formatMoney(s.profit),
                          color: s.profit >= 0 ? AppColors.profitGreen : AppColors.pendingRed),
                      _row('Remaining Balance', formatMoney(s.balance), color: AppColors.pendingRed),
                      if (s.trip.notes != null && s.trip.notes!.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(s.trip.notes!, style: const TextStyle(color: AppColors.textMuted)),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => context.push('/expenses/new', extra: tripId),
                      icon: const Icon(Icons.add),
                      label: const Text('Add Expense'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => context.push('/payments/new', extra: {
                        'tripId': tripId,
                        'customerId': s.customer.id,
                      }),
                      icon: const Icon(Icons.payments),
                      label: const Text('Receive Payment'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: ExpenseCategories.quick.map((c) {
                  return ActionChip(
                    label: Text(c),
                    avatar: const Icon(Icons.flash_on, size: 16),
                    onPressed: () => context.push('/expenses/new', extra: tripId, ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),
              const SectionHeader(title: 'Expenses'),
              expensesAsync.when(
                data: (list) {
                  if (list.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Text('No expenses added yet.', style: TextStyle(color: AppColors.textMuted)),
                    );
                  }
                   return Column(
                     children: list.map((e) {
                        return Dismissible(
                          key: ValueKey('expense-${e.id}'),
                          direction: DismissDirection.endToStart,
                          background: Container(
                            color: AppColors.pendingRed,
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: const Icon(Icons.delete, color: Colors.white),
                          ),
                          confirmDismiss: (_) => _confirmDeleteExpense(context, e.category, e.amount),
                          onDismissed: (_) {
                            ref.read(expenseRepositoryProvider).deleteExpense(e.id);
                            ref.read(dashboardRefreshTickerProvider.notifier).state++;
                          },
                          child: ListTile(
                           contentPadding: EdgeInsets.zero,
                           leading: const CircleAvatar(
                             backgroundColor: Color(0x1AEF6C00),
                             child: Icon(Icons.receipt, color: AppColors.expenseOrange, size: 18),
                           ),
                           title: Text(e.category),
                           subtitle: Text(formatDate(e.date)),
                           trailing: Row(
                             mainAxisSize: MainAxisSize.min,
                             children: [
                               Text(formatMoney(e.amount),
                                   style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.expenseOrange)),
                               const SizedBox(width: 8),
                               GestureDetector(
                                 onTap: () async {
                                   final confirmed = await _confirmDeleteExpense(context, e.category, e.amount);
                                   if (confirmed == true) {
                                     ref.read(expenseRepositoryProvider).deleteExpense(e.id);
                                     ref.read(dashboardRefreshTickerProvider.notifier).state++;
                                   }
                                 },
                                 child: const Icon(Icons.close, size: 18, color: AppColors.textMuted),
                               ),
                             ],
                           ),
                         ),
                       );
                    }).toList(),
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, st) => Text('Error: $e'),
              ),
              const SizedBox(height: 12),
              const SectionHeader(title: 'Payments'),
              paymentsAsync.when(
                data: (list) {
                  if (list.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Text('No payments received yet.', style: TextStyle(color: AppColors.textMuted)),
                    );
                  }
                  return Column(
                    children: list.map((p) {
                      return Dismissible(
                        key: ValueKey('payment-${p.id}'),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          color: AppColors.pendingRed,
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: const Icon(Icons.delete, color: Colors.white),
                        ),
                        onDismissed: (_) => ref.read(paymentRepositoryProvider).deletePayment(p.id),
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const CircleAvatar(
                            backgroundColor: Color(0x1A2E7D32),
                            child: Icon(Icons.payments, color: AppColors.profitGreen, size: 18),
                          ),
                          title: Text(p.method),
                          subtitle: Text('${formatDate(p.date)}${p.reference != null ? ' • ${p.reference}' : ''}'),
                          trailing: Text(formatMoney(p.amount),
                              style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.profitGreen)),
                        ),
                      );
                    }).toList(),
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, st) => Text('Error: $e'),
              ),
              const SizedBox(height: 40),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('Error: $e')),
      ),
    );
  }

  static Future<bool?> _confirmDeleteExpense(BuildContext context, String category, double amount) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete expense?'),
        content: Text('Remove "$category" (${formatMoney(amount)})?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: AppColors.pendingRed)),
          ),
        ],
      ),
    );
  }

  Widget _row(String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AppColors.textMuted)),
          Text(value, style: TextStyle(fontWeight: FontWeight.w600, color: color)),
        ],
      ),
    );
  }
}

final _tripSummaryProvider = FutureProvider.autoDispose.family<TripSummary?, int>((ref, tripId) {
  ref.watch(dashboardRefreshTickerProvider);
  ref.watch(tripExpensesProvider(tripId));
  ref.watch(tripPaymentsProvider(tripId));
  return ref.watch(tripRepositoryProvider).getTripSummary(tripId);
});
