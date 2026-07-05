import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

export 'package:drift/drift.dart' show Value;

part 'app_database.g.dart';

/// One row per customer. A customer can have many trips and many payments.
class Customers extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 100)();
  TextColumn get phone => text().nullable()();
  TextColumn get notes => text().nullable()();
  BoolColumn get isFavorite => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

/// One row per trip. A trip belongs to a customer, and can have many
/// expenses and many payments attached to it.
class Trips extends Table {
  IntColumn get id => integer().autoIncrement()();
  DateTimeColumn get date => dateTime().withDefault(currentDateAndTime)();
  IntColumn get customerId =>
      integer().references(Customers, #id, onDelete: KeyAction.cascade)();
  TextColumn get materialType => text()();
  TextColumn get quantity => text()(); // free text: "20 Ton", "5000 Bricks"
  RealColumn get tripAmount => real().withDefault(const Constant(0))();
  TextColumn get notes => text().nullable()();
  TextColumn get photoPath => text().nullable()();
  TextColumn get receiptPhotoPath => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

/// One row per expense. Expenses may optionally be tied to a specific trip,
/// or logged as a general truck expense (tripId null).
class Expenses extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get tripId =>
      integer().nullable().references(Trips, #id, onDelete: KeyAction.cascade)();
  TextColumn get category => text()();
  RealColumn get amount => real()();
  DateTimeColumn get date => dateTime().withDefault(currentDateAndTime)();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

/// One row per payment received from a customer. May optionally be tied to
/// a specific trip, or recorded as a general payment against the running
/// customer balance.
class Payments extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get customerId =>
      integer().references(Customers, #id, onDelete: KeyAction.cascade)();
  IntColumn get tripId =>
      integer().nullable().references(Trips, #id, onDelete: KeyAction.setNull)();
  RealColumn get amount => real()();
  DateTimeColumn get date => dateTime().withDefault(currentDateAndTime)();
  TextColumn get method => text().withDefault(const Constant('Cash'))();
  TextColumn get reference => text().nullable()();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

/// One row per driver-cash transaction: positive = advance (owner gives cash
/// to driver), negative = recovery (driver returns cash). Tracked separately
/// from expenses because advances are later accounted for — they don't reduce
/// trip profit directly.
class DriverCash extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get tripId =>
      integer().references(Trips, #id, onDelete: KeyAction.cascade)();
  RealColumn get amount => real()(); // positive = advance, negative = recovery
  DateTimeColumn get date => dateTime().withDefault(currentDateAndTime)();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

/// Single-row key/value app settings table (PIN hash, theme, etc. are kept
/// in SharedPreferences instead — this table is reserved for settings that
/// benefit from being inside the backed-up database file, e.g. last backup
/// timestamp shown in the About screen).
class AppSettingsTable extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}

@DriftDatabase(tables: [Customers, Trips, Expenses, Payments, DriverCash, AppSettingsTable])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  /// Constructor used only for tests, to point at an in-memory database.
  AppDatabase.forTesting(super.e);

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
        },
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            await m.createTable(driverCash);
          }
        },
      );

  // ---------------------------------------------------------------------
  // Customers
  // ---------------------------------------------------------------------

  Future<List<Customer>> getAllCustomers() => select(customers).get();

  Stream<List<Customer>> watchAllCustomers() => select(customers).watch();

  Future<int> insertCustomer(CustomersCompanion entry) =>
      into(customers).insert(entry);

  Future<bool> updateCustomer(Customer entry) => update(customers).replace(entry);

  Future<int> deleteCustomer(int id) =>
      (delete(customers)..where((t) => t.id.equals(id))).go();

  // ---------------------------------------------------------------------
  // Trips
  // ---------------------------------------------------------------------

  Future<int> insertTrip(TripsCompanion entry) => into(trips).insert(entry);

  Future<bool> updateTrip(Trip entry) => update(trips).replace(entry);

  Future<int> deleteTrip(int id) =>
      (delete(trips)..where((t) => t.id.equals(id))).go();

  Stream<List<Trip>> watchAllTrips() =>
      (select(trips)..orderBy([(t) => OrderingTerm.desc(t.date)])).watch();

  Stream<List<Trip>> watchTripsForCustomer(int customerId) =>
      (select(trips)
            ..where((t) => t.customerId.equals(customerId))
            ..orderBy([(t) => OrderingTerm.desc(t.date)]))
          .watch();

  Stream<Trip?> watchTrip(int id) =>
      (select(trips)..where((t) => t.id.equals(id))).watchSingleOrNull();

  Future<List<Trip>> tripsBetween(DateTime start, DateTime end) =>
      (select(trips)
            ..where((t) => t.date.isBiggerOrEqualValue(start) & t.date.isSmallerThanValue(end)))
          .get();

  // ---------------------------------------------------------------------
  // Expenses
  // ---------------------------------------------------------------------

  Future<int> insertExpense(ExpensesCompanion entry) =>
      into(expenses).insert(entry);

  Future<bool> updateExpense(Expense entry) => update(expenses).replace(entry);

  Future<int> deleteExpense(int id) =>
      (delete(expenses)..where((t) => t.id.equals(id))).go();

  Stream<List<Expense>> watchExpensesForTrip(int tripId) =>
      (select(expenses)..where((t) => t.tripId.equals(tripId))).watch();

  Future<List<Expense>> expensesBetween(DateTime start, DateTime end) =>
      (select(expenses)
            ..where((t) =>
                t.date.isBiggerOrEqualValue(start) & t.date.isSmallerThanValue(end)))
          .get();

  // ---------------------------------------------------------------------
  // Payments
  // ---------------------------------------------------------------------

  Future<int> insertPayment(PaymentsCompanion entry) =>
      into(payments).insert(entry);

  Future<bool> updatePayment(Payment entry) => update(payments).replace(entry);

  Future<int> deletePayment(int id) =>
      (delete(payments)..where((t) => t.id.equals(id))).go();

  Stream<List<Payment>> watchPaymentsForTrip(int tripId) =>
      (select(payments)..where((t) => t.tripId.equals(tripId))).watch();

  Stream<List<Payment>> watchPaymentsForCustomer(int customerId) =>
      (select(payments)..where((t) => t.customerId.equals(customerId))).watch();

  Future<List<Payment>> paymentsBetween(DateTime start, DateTime end) =>
      (select(payments)
            ..where((t) =>
                t.date.isBiggerOrEqualValue(start) & t.date.isSmallerThanValue(end)))
          .get();

  // ---------------------------------------------------------------------
  // Driver Cash
  // ---------------------------------------------------------------------

  Future<int> insertDriverCash(DriverCashCompanion entry) =>
      into(driverCash).insert(entry);

  Future<int> deleteDriverCash(int id) =>
      (delete(driverCash)..where((t) => t.id.equals(id))).go();

  Stream<List<DriverCashData>> watchDriverCashForTrip(int tripId) =>
      (select(driverCash)
            ..where((t) => t.tripId.equals(tripId))
            ..orderBy([(t) => OrderingTerm.desc(t.date)]))
          .watch();

  /// Net cash for a trip: sum of all advances minus recoveries.
  /// Positive = driver still owes money, negative = driver returned more
  /// than advanced.
  Future<double> netDriverCashForTrip(int tripId) async {
    final rows = await (select(driverCash)
          ..where((t) => t.tripId.equals(tripId)))
        .get();
    return rows.fold<double>(0, (sum, r) => sum + r.amount);
  }

  // ---------------------------------------------------------------------
  // Admin (delete all data / daily auto-backup)
  // ---------------------------------------------------------------------

  /// Deletes all rows from every table, leaving the app in a fresh state.
  /// Uses a batch so the operation is atomic and FK constraints are checked
  /// after all deletes finish.
  Future<void> deleteAllData() async {
    await batch((b) {
      b.deleteAll(driverCash);
      b.deleteAll(payments);
      b.deleteAll(expenses);
      b.deleteAll(trips);
      b.deleteAll(customers);
    });
  }

  // ---------------------------------------------------------------------
  // Search (simple LIKE-based global search across the fields the spec
  // calls out: customer name, material, trip date, trip amount, notes).
  // ---------------------------------------------------------------------

  Future<List<Trip>> searchTrips(String query) async {
    final likeQuery = '%$query%';
    return (select(trips)
          ..where((t) =>
              t.materialType.like(likeQuery) |
              t.notes.like(likeQuery) |
              t.quantity.like(likeQuery)))
        .get();
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'truck_account_book.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}

/// Absolute path to the live database file, used by the backup/restore
/// feature in Settings.
Future<File> getDatabaseFile() async {
  final dbFolder = await getApplicationDocumentsDirectory();
  return File(p.join(dbFolder.path, 'truck_account_book.sqlite'));
}
