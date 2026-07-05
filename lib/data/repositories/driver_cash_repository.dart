import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:truck_account_book/data/database/app_database.dart';
import 'package:truck_account_book/data/database/database_provider.dart';

class DriverCashRepository {
  final AppDatabase db;
  DriverCashRepository(this.db);

  Stream<List<DriverCashData>> watchForTrip(int tripId) =>
      db.watchDriverCashForTrip(tripId);

  Future<int> addAdvance(int tripId, double amount, DateTime date, String? notes) {
    return db.insertDriverCash(DriverCashCompanion.insert(
      tripId: tripId,
      amount: amount, // positive = advance to driver
      date: Value(date),
      notes: Value(notes),
    ));
  }

  Future<int> addRecovery(int tripId, double amount, DateTime date, String? notes) {
    return db.insertDriverCash(DriverCashCompanion.insert(
      tripId: tripId,
      amount: -amount, // negative = recovery from driver
      date: Value(date),
      notes: Value(notes),
    ));
  }

  Future<int> deleteDriverCash(int id) => db.deleteDriverCash(id);

  Future<double> netForTrip(int tripId) => db.netDriverCashForTrip(tripId);
}

final driverCashRepositoryProvider = Provider<DriverCashRepository>((ref) {
  return DriverCashRepository(ref.watch(appDatabaseProvider));
});

final tripDriverCashProvider =
    StreamProvider.family<List<DriverCashData>, int>((ref, tripId) {
  return ref.watch(driverCashRepositoryProvider).watchForTrip(tripId);
});
