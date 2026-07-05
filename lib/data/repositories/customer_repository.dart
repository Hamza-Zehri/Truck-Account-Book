import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:truck_account_book/core/utils/calculations.dart';
import 'package:truck_account_book/data/database/app_database.dart';
import 'package:truck_account_book/data/database/database_provider.dart';

/// Customer + derived ledger totals (business, received, pending) as
/// described in the "Customer Ledger" section of the spec.
class CustomerLedger {
  final Customer customer;
  final double totalBusiness;
  final double totalReceived;

  CustomerLedger({
    required this.customer,
    required this.totalBusiness,
    required this.totalReceived,
  });

  double get pendingAmount => Calculations.customerBalance(
        totalBusiness: totalBusiness,
        totalReceived: totalReceived,
      );
}

class CustomerRepository {
  final AppDatabase db;
  CustomerRepository(this.db);

  Future<int> createCustomer({
    required String name,
    String? phone,
    String? notes,
    bool isFavorite = false,
  }) {
    return db.insertCustomer(CustomersCompanion.insert(
      name: name,
      phone: Value(phone),
      notes: Value(notes),
      isFavorite: Value(isFavorite),
    ));
  }

  Future<bool> updateCustomer(Customer customer) => db.updateCustomer(customer);

  Future<int> deleteCustomer(int id) => db.deleteCustomer(id);

  Stream<List<Customer>> watchAllCustomers() => db.watchAllCustomers();

  Future<List<CustomerLedger>> ledgerForAll() async {
    final customers = await db.getAllCustomers();
    final result = <CustomerLedger>[];
    for (final c in customers) {
      result.add(await _ledgerFor(c));
    }
    // Favorites first, then alphabetical - matches "Favorite customers"
    // being a first-class concept in the spec.
    result.sort((a, b) {
      if (a.customer.isFavorite != b.customer.isFavorite) {
        return a.customer.isFavorite ? -1 : 1;
      }
      return a.customer.name.toLowerCase().compareTo(b.customer.name.toLowerCase());
    });
    return result;
  }

  Future<CustomerLedger> ledgerFor(int customerId) async {
    final customer = await (db.select(db.customers)
          ..where((c) => c.id.equals(customerId)))
        .getSingle();
    return _ledgerFor(customer);
  }

  Future<CustomerLedger> _ledgerFor(Customer customer) async {
    final trips = await (db.select(db.trips)
          ..where((t) => t.customerId.equals(customer.id)))
        .get();
    final payments = await (db.select(db.payments)
          ..where((p) => p.customerId.equals(customer.id)))
        .get();
    final totalBusiness = trips.fold<double>(0, (sum, t) => sum + t.tripAmount);
    final totalReceived = payments.fold<double>(0, (sum, p) => sum + p.amount);
    return CustomerLedger(
      customer: customer,
      totalBusiness: totalBusiness,
      totalReceived: totalReceived,
    );
  }

  Future<List<Customer>> searchByName(String query) async {
    final all = await db.getAllCustomers();
    final lower = query.toLowerCase();
    return all.where((c) => c.name.toLowerCase().contains(lower)).toList();
  }
}

final customerRepositoryProvider = Provider<CustomerRepository>((ref) {
  return CustomerRepository(ref.watch(appDatabaseProvider));
});

final allCustomersProvider = StreamProvider<List<Customer>>((ref) {
  return ref.watch(customerRepositoryProvider).watchAllCustomers();
});

final customerLedgerListProvider = FutureProvider.autoDispose<List<CustomerLedger>>((ref) {
  // Re-run whenever the customer list changes.
  ref.watch(allCustomersProvider);
  return ref.watch(customerRepositoryProvider).ledgerForAll();
});

final customerLedgerProvider =
    FutureProvider.autoDispose.family<CustomerLedger, int>((ref, id) {
  return ref.watch(customerRepositoryProvider).ledgerFor(id);
});
