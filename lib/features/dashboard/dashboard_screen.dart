import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:truck_account_book/core/theme/app_theme.dart';
import 'package:truck_account_book/core/widgets/shared_widgets.dart';
import 'package:truck_account_book/data/repositories/customer_repository.dart';
import 'package:truck_account_book/data/repositories/report_repository.dart';
import 'package:truck_account_book/data/repositories/trip_repository.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = ref.watch(todaySummaryProvider);
    final trips = ref.watch(allTripSummariesProvider);
    final ledgers = ref.watch(customerLedgerListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Truck Account Book'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => context.push('/search'),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(todaySummaryProvider);
          ref.invalidate(allTripSummariesProvider);
          ref.invalidate(customerLedgerListProvider);
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            today.when(
              data: (s) => GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.35,
                children: [
                  StatCard(
                    label: "Today's Trips",
                    value: '${s.tripCount}',
                    color: AppColors.primaryBlue,
                    icon: Icons.local_shipping,
                  ),
                  StatCard(
                    label: "Today's Income",
                    value: formatMoney(s.totalIncome),
                    color: AppColors.primaryBlue,
                    icon: Icons.trending_up,
                  ),
                  StatCard(
                    label: "Today's Expenses",
                    value: formatMoney(s.totalExpenses),
                    color: AppColors.expenseOrange,
                    icon: Icons.receipt_long,
                  ),
                  StatCard(
                    label: "Today's Profit",
                    value: formatMoney(s.profit),
                    color: s.profit >= 0 ? AppColors.profitGreen : AppColors.pendingRed,
                    icon: Icons.account_balance_wallet,
                  ),
                ],
              ),
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, st) => Text('Error loading dashboard: $e'),
            ),
            const SizedBox(height: 8),
            ledgers.when(
              data: (list) {
                final pending = list.fold<double>(0, (sum, l) => sum + l.pendingAmount);
                return Card(
                  color: AppColors.pendingRed.withValues(alpha: 0.06),
                  child: ListTile(
                    leading: const Icon(Icons.warning_amber_rounded, color: AppColors.pendingRed),
                    title: const Text('Pending Payments'),
                    trailing: Text(
                      formatMoney(pending),
                      style: const TextStyle(
                        color: AppColors.pendingRed,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                    onTap: () => context.push('/customers'),
                  ),
                );
              },
              loading: () => const SizedBox.shrink(),
              error: (e, st) => const SizedBox.shrink(),
            ),
            const SizedBox(height: 20),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.6,
              children: [
                BigActionButton(
                  label: 'New Trip',
                  icon: Icons.add_road,
                  color: AppColors.primaryBlue,
                  onTap: () => context.push('/trips/new'),
                ),
                BigActionButton(
                  label: 'Receive Payment',
                  icon: Icons.payments,
                  color: AppColors.profitGreen,
                  onTap: () => context.push('/payments/new'),
                ),
                BigActionButton(
                  label: 'Add Expense',
                  icon: Icons.receipt_long,
                  color: AppColors.expenseOrange,
                  onTap: () => context.push('/expenses/new'),
                ),
                BigActionButton(
                  label: 'Reports',
                  icon: Icons.bar_chart,
                  color: AppColors.primaryBlueLight,
                  onTap: () => context.push('/reports'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SectionHeader(title: 'Recent Trips', onSeeAll: () => context.push('/trips')),
            trips.when(
              data: (list) {
                if (list.isEmpty) {
                  return const EmptyState(
                    icon: Icons.local_shipping_outlined,
                    title: 'No trips yet',
                    subtitle: 'Tap "New Trip" to record your first delivery.',
                  );
                }
                final recent = list.take(5).toList();
                return Column(
                  children: recent.map((s) {
                    return Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      child: ListTile(
                        title: Text(s.customer.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text('${s.trip.materialType} • ${s.trip.quantity} • ${formatDate(s.trip.date)}'),
                        trailing: Text(
                          formatMoney(s.trip.tripAmount),
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
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
            SectionHeader(title: 'Pending Payments', onSeeAll: () => context.push('/customers')),
            ledgers.when(
              data: (list) {
                final pendingCustomers = list.where((l) => l.pendingAmount > 0).take(5).toList();
                if (pendingCustomers.isEmpty) {
                  return const EmptyState(
                    icon: Icons.check_circle_outline,
                    title: 'All caught up',
                    subtitle: 'No pending customer payments right now.',
                  );
                }
                return Column(
                  children: pendingCustomers.map((l) {
                    return Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      child: ListTile(
                        title: Text(l.customer.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: const Text('Pending balance'),
                        trailing: Text(
                          formatMoney(l.pendingAmount),
                          style: const TextStyle(color: AppColors.pendingRed, fontWeight: FontWeight.w700),
                        ),
                        onTap: () => context.push('/customers/${l.customer.id}'),
                      ),
                    );
                  }).toList(),
                );
              },
              loading: () => const SizedBox.shrink(),
              error: (e, st) => const SizedBox.shrink(),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}
