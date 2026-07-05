import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:truck_account_book/core/widgets/shared_widgets.dart';
import 'package:truck_account_book/data/repositories/trip_repository.dart';

/// Global search across customer name, material, trip date, trip amount,
/// and notes, per the spec. Kept as a simple debounced text-driven query
/// rather than a separate search index, since data volume for a single
/// truck's account book is small.
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _controller = TextEditingController();
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final allTrips = ref.watch(allTripSummariesProvider);

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Search customer, material, date, amount, notes...',
            border: InputBorder.none,
          ),
          onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
        ),
      ),
      body: _query.isEmpty
          ? const EmptyState(
              icon: Icons.search,
              title: 'Search everything',
              subtitle: 'Find a trip or customer instantly.',
            )
          : allTrips.when(
              data: (trips) {
                final matches = trips.where((s) {
                  return s.customer.name.toLowerCase().contains(_query) ||
                      s.trip.materialType.toLowerCase().contains(_query) ||
                      s.trip.quantity.toLowerCase().contains(_query) ||
                      formatDate(s.trip.date).toLowerCase().contains(_query) ||
                      s.trip.tripAmount.toString().contains(_query) ||
                      (s.trip.notes ?? '').toLowerCase().contains(_query);
                }).toList();

                if (matches.isEmpty) {
                  return const EmptyState(
                    icon: Icons.search_off,
                    title: 'No matches',
                    subtitle: 'Try a different name, material, or date.',
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: matches.length,
                  itemBuilder: (context, i) {
                    final s = matches[i];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      child: ListTile(
                        title: Text(s.customer.name),
                        subtitle: Text('${s.trip.materialType} • ${s.trip.quantity} • ${formatDate(s.trip.date)}'),
                        trailing: Text(formatMoney(s.trip.tripAmount)),
                        onTap: () => context.push('/trips/${s.trip.id}'),
                      ),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, st) => Text('Error: $e'),
            ),
    );
  }
}
