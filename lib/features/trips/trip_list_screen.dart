import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:truck_account_book/core/constants/app_constants.dart';
import 'package:truck_account_book/core/theme/app_theme.dart';
import 'package:truck_account_book/core/widgets/shared_widgets.dart';
import 'package:truck_account_book/data/repositories/trip_repository.dart';

class TripListScreen extends ConsumerWidget {
  const TripListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trips = ref.watch(allTripSummariesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('All Trips')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/trips/new'),
        icon: const Icon(Icons.add),
        label: const Text('New Trip'),
      ),
      body: trips.when(
        data: (list) {
          if (list.isEmpty) {
            return const EmptyState(
              icon: Icons.local_shipping_outlined,
              title: 'No trips yet',
              subtitle: 'Tap "New Trip" to record your first delivery.',
            );
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(allTripSummariesProvider),
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: list.length,
              itemBuilder: (context, i) {
                final s = list[i];
                final statusColor = switch (s.status.label) {
                  'Paid' => AppColors.profitGreen,
                  'Partial' => AppColors.expenseOrange,
                  _ => AppColors.pendingRed,
                };
                return Dismissible(
                  key: ValueKey(s.trip.id),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(
                      color: AppColors.pendingRed,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(Icons.delete, color: Colors.white),
                  ),
                  confirmDismiss: (_) async {
                    return await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Delete trip?'),
                        content: const Text('This also removes its expenses and payments.'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
                        ],
                      ),
                    ) ??
                        false;
                  },
                  onDismissed: (_) => ref.read(tripRepositoryProvider).deleteTrip(s.trip.id),
                  child: Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: ListTile(
                      title: Text(s.customer.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text('${s.trip.materialType} • ${s.trip.quantity} • ${formatDate(s.trip.date)}'),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(formatMoney(s.trip.tripAmount), style: const TextStyle(fontWeight: FontWeight.w700)),
                          const SizedBox(height: 4),
                          StatusBadge(label: s.status.label, color: statusColor),
                        ],
                      ),
                      onTap: () => context.push('/trips/${s.trip.id}'),
                    ),
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
}
