import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:truck_account_book/data/database/app_database.dart';
import 'package:truck_account_book/data/database/database_provider.dart';

class DriverCashRepository {
  final AppDatabase db;
  DriverCashRepository(this.db);

  Stream<List<DriverCashData>> watchAll() => db.watchAllDriverCash();

  Future<int> addAdvance(double amount, DateTime date, String? notes) {
    return db.insertDriverCash(DriverCashCompanion.insert(
      amount: amount,
      date: Value(date),
      notes: Value(notes),
    ));
  }

  Future<int> addRecovery(double amount, DateTime date, String? notes) {
    return db.insertDriverCash(DriverCashCompanion.insert(
      amount: -amount,
      date: Value(date),
      notes: Value(notes),
    ));
  }

  Future<int> deleteDriverCash(int id) => db.deleteDriverCash(id);

  Future<double> totalNet() => db.totalNetDriverCash();
}

final driverCashRepositoryProvider = Provider<DriverCashRepository>((ref) {
  return DriverCashRepository(ref.watch(appDatabaseProvider));
});

final allDriverCashProvider =
    StreamProvider<List<DriverCashData>>((ref) {
  return ref.watch(driverCashRepositoryProvider).watchAll();
});
