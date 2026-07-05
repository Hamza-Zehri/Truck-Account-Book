import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:truck_account_book/core/constants/app_constants.dart';
import 'package:truck_account_book/core/utils/calculations.dart';
import 'package:truck_account_book/data/database/app_database.dart';
import 'package:truck_account_book/data/database/database_provider.dart';

/// A trip enriched with its computed financial fields, so the UI layer
/// never has to re-derive profit/balance itself.
class TripSummary {
  final Trip trip;
  final Customer customer;
  final double totalExpenses;
  final double totalPaid;

  TripSummary({
    required this.trip,
    required this.customer,
    required this.totalExpenses,
    required this.totalPaid,
  });

  double get profit => Calculations.tripProfit(
        tripAmount: trip.tripAmount,
        totalExpenses: totalExpenses,
      );

  double get balance => Calculations.tripBalance(
        tripAmount: trip.tripAmount,
        totalPaid: totalPaid,
      );

  PaymentStatus get status => Calculations.statusFor(
        tripAmount: trip.tripAmount,
        totalPaid: totalPaid,
      );
}

class TripRepository {
  final AppDatabase db;
  TripRepository(this.db);

  Future<int> createTrip({
    required DateTime date,
    required int customerId,
    required String materialType,
    required String quantity,
    required double tripAmount,
    String? notes,
    String? photoPath,
    String? receiptPhotoPath,
  }) {
    return db.insertTrip(TripsCompanion.insert(
      date: Value(date),
      customerId: customerId,
      materialType: materialType,
      quantity: quantity,
      tripAmount: Value(tripAmount),
      notes: Value(notes),
      photoPath: Value(photoPath),
      receiptPhotoPath: Value(receiptPhotoPath),
    ));
  }

  Future<void> duplicateTrip(Trip original) async {
    await createTrip(
      date: DateTime.now(),
      customerId: original.customerId,
      materialType: original.materialType,
      quantity: original.quantity,
      tripAmount: original.tripAmount,
      notes: original.notes,
    );
  }

  Future<bool> updateTrip(Trip trip) => db.updateTrip(trip);

  Future<int> deleteTrip(int id) => db.deleteTrip(id);

  /// Streams every trip joined with its customer and computed totals.
  /// Re-hydrates totals each time the underlying trip list emits, so the
  /// UI stays correct after any expense/payment write triggers a refresh.
  Stream<List<TripSummary>> watchAllTripSummaries() {
    return db.watchAllTrips().asyncMap((trips) => _hydrate(trips));
  }

  Stream<List<TripSummary>> watchCustomerTripSummaries(int customerId) {
    return db.watchTripsForCustomer(customerId).asyncMap((trips) => _hydrate(trips));
  }

  Future<List<TripSummary>> _hydrate(List<Trip> trips) async {
    final result = <TripSummary>[];
    for (final trip in trips) {
      final customer = await (db.select(db.customers)
            ..where((c) => c.id.equals(trip.customerId)))
          .getSingleOrNull();
      if (customer == null) continue;
      final expenses = await (db.select(db.expenses)
            ..where((e) => e.tripId.equals(trip.id)))
          .get();
      final paymentsForTrip = await (db.select(db.payments)
            ..where((p) => p.tripId.equals(trip.id)))
          .get();
      final totalExpenses = expenses.fold<double>(0, (sum, e) => sum + e.amount);
      final totalPaid = paymentsForTrip.fold<double>(0, (sum, p) => sum + p.amount);
      result.add(TripSummary(
        trip: trip,
        customer: customer,
        totalExpenses: totalExpenses,
        totalPaid: totalPaid,
      ));
    }
    return result;
  }

  Future<TripSummary?> getTripSummary(int tripId) async {
    final trip = await (db.select(db.trips)..where((t) => t.id.equals(tripId)))
        .getSingleOrNull();
    if (trip == null) return null;
    final list = await _hydrate([trip]);
    return list.isEmpty ? null : list.first;
  }
}

final tripRepositoryProvider = Provider<TripRepository>((ref) {
  return TripRepository(ref.watch(appDatabaseProvider));
});

final allTripSummariesProvider = StreamProvider<List<TripSummary>>((ref) {
  return ref.watch(tripRepositoryProvider).watchAllTripSummaries();
});

final customerTripSummariesProvider =
    StreamProvider.family<List<TripSummary>, int>((ref, customerId) {
  return ref.watch(tripRepositoryProvider).watchCustomerTripSummaries(customerId);
});
