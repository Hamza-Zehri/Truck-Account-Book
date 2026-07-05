import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:truck_account_book/core/constants/app_constants.dart';
import 'package:truck_account_book/data/database/app_database.dart';
import 'package:truck_account_book/data/database/database_provider.dart';

class PaymentRepository {
  final AppDatabase db;
  PaymentRepository(this.db);

  Future<int> addPayment({
    required int customerId,
    int? tripId,
    required double amount,
    required DateTime date,
    required PaymentMethod method,
    String? reference,
    String? notes,
  }) {
    return db.insertPayment(PaymentsCompanion.insert(
      customerId: customerId,
      tripId: Value(tripId),
      amount: amount,
      date: Value(date),
      method: Value(method.label),
      reference: Value(reference),
      notes: Value(notes),
    ));
  }

  Future<bool> updatePayment(Payment payment) => db.updatePayment(payment);

  Future<int> deletePayment(int id) => db.deletePayment(id);

  Stream<List<Payment>> watchForTrip(int tripId) => db.watchPaymentsForTrip(tripId);

  Stream<List<Payment>> watchForCustomer(int customerId) =>
      db.watchPaymentsForCustomer(customerId);
}

final paymentRepositoryProvider = Provider<PaymentRepository>((ref) {
  return PaymentRepository(ref.watch(appDatabaseProvider));
});

final tripPaymentsProvider =
    StreamProvider.family<List<Payment>, int>((ref, tripId) {
  return ref.watch(paymentRepositoryProvider).watchForTrip(tripId);
});

final customerPaymentsProvider =
    StreamProvider.family<List<Payment>, int>((ref, customerId) {
  return ref.watch(paymentRepositoryProvider).watchForCustomer(customerId);
});
