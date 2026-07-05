import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:truck_account_book/data/database/app_database.dart';
import 'package:truck_account_book/data/database/database_provider.dart';

class ExpenseRepository {
  final AppDatabase db;
  ExpenseRepository(this.db);

  Future<int> addExpense({
    int? tripId,
    required String category,
    required double amount,
    required DateTime date,
    String? notes,
  }) {
    return db.insertExpense(ExpensesCompanion.insert(
      tripId: Value(tripId),
      category: category,
      amount: amount,
      date: Value(date),
      notes: Value(notes),
    ));
  }

  Future<bool> updateExpense(Expense expense) => db.updateExpense(expense);

  Future<int> deleteExpense(int id) => db.deleteExpense(id);

  Stream<List<Expense>> watchForTrip(int tripId) => db.watchExpensesForTrip(tripId);

  Stream<List<Expense>> watchAll() => db.watchAllExpenses();
}

final expenseRepositoryProvider = Provider<ExpenseRepository>((ref) {
  return ExpenseRepository(ref.watch(appDatabaseProvider));
});

final tripExpensesProvider =
    StreamProvider.family<List<Expense>, int>((ref, tripId) {
  return ref.watch(expenseRepositoryProvider).watchForTrip(tripId);
});

final allExpensesProvider = StreamProvider<List<Expense>>((ref) {
  return ref.watch(expenseRepositoryProvider).watchAll();
});
