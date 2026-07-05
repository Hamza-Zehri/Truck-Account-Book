import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:truck_account_book/core/theme/app_theme.dart';
import 'package:truck_account_book/core/widgets/shared_widgets.dart';
import 'package:truck_account_book/data/repositories/customer_repository.dart';
import 'package:truck_account_book/data/repositories/payment_repository.dart';
import 'package:truck_account_book/data/repositories/trip_repository.dart';

class CustomerDetailScreen extends ConsumerWidget {
  final int customerId;
  const CustomerDetailScreen({super.key, required this.customerId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ledgerAsync = ref.watch(customerLedgerProvider(customerId));
    final tripsAsync = ref.watch(customerTripSummariesProvider(customerId));
    final paymentsAsync = ref.watch(customerPaymentsProvider(customerId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Customer Ledger'),
        actions: [
          ledgerAsync.maybeWhen(
            data: (l) => IconButton(
              icon: Icon(l.customer.isFavorite ? Icons.star : Icons.star_border,
                  color: l.customer.isFavorite ? Colors.amber : null),
              onPressed: () => ref.read(customerRepositoryProvider).updateCustomer(
                    l.customer.copyWith(isFavorite: !l.customer.isFavorite),
                  ),
            ),
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
      floatingActionButton: ledgerAsync.maybeWhen(
        data: (l) => FloatingActionButton.extended(
          onPressed: () => context.push('/payments/new', extra: {'customerId': l.customer.id}),
          icon: const Icon(Icons.payments),
          label: const Text('Receive Payment'),
        ),
        orElse: () => null,
      ),
      body: ledgerAsync.when(
        data: (l) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l.customer.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                      if (l.customer.phone != null) Text(l.customer.phone!, style: const TextStyle(color: AppColors.textMuted)),
                      const Divider(height: 24),
                      Row(
                        children: [
                          Expanded(
                            child: _statColumn('Total Business', formatMoney(l.totalBusiness), AppColors.primaryBlue),
                          ),
                          Expanded(
                            child: _statColumn('Total Received', formatMoney(l.totalReceived), AppColors.profitGreen),
                          ),
                          Expanded(
                            child: _statColumn('Pending', formatMoney(l.pendingAmount), AppColors.pendingRed),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const SectionHeader(title: 'Trip History'),
              tripsAsync.when(
                data: (list) {
                  if (list.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Text('No trips yet.', style: TextStyle(color: AppColors.textMuted)),
                    );
                  }
                  return Column(
                    children: list.map((s) {
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          title: Text('${s.trip.materialType} • ${s.trip.quantity}'),
                          subtitle: Text(formatDate(s.trip.date)),
                          trailing: Text(formatMoney(s.trip.tripAmount), style: const TextStyle(fontWeight: FontWeight.w700)),
                          onTap: () => context.push('/trips/${s.trip.id}'),
                        ),
                      );
                    }).toList(),
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, st) => Text('Error: $e'),
              ),
              const SizedBox(height: 16),
              const SectionHeader(title: 'Payment History'),
              paymentsAsync.when(
                data: (list) {
                  if (list.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Text('No payments yet.', style: TextStyle(color: AppColors.textMuted)),
                    );
                  }
                  return Column(
                    children: list.map((p) {
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: const Icon(Icons.payments, color: AppColors.profitGreen),
                          title: Text(p.method),
                          subtitle: Text(formatDate(p.date)),
                          trailing: Text(formatMoney(p.amount), style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.profitGreen)),
                        ),
                      );
                    }).toList(),
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, st) => Text('Error: $e'),
              ),
              const SizedBox(height: 80),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('Error: $e')),
      ),
    );
  }

  Widget _statColumn(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value, style: TextStyle(fontWeight: FontWeight.w700, color: color, fontSize: 15)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
      ],
    );
  }
}
