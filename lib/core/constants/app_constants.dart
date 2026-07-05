/// App-wide constants: material types, expense categories, payment methods,
/// default values, and the single source of truth for enums used across
/// the Truck Account Book app.
library;

/// Default PIN used the very first time the app is launched.
const String kDefaultPin = '1234';

/// Shared preferences keys.
class PrefsKeys {
  PrefsKeys._();
  static const String pinHash = 'pin_hash';
  static const String darkMode = 'dark_mode';
  static const String lastBackupDate = 'last_backup_date';
  static const String isFirstLaunch = 'is_first_launch';
}

/// Material types a trip can carry. Kept as a simple list (with an "Other"
/// escape hatch) rather than a rigid enum so the dropdown can be extended
/// later without a schema migration for the type itself.
class MaterialTypes {
  MaterialTypes._();
  static const List<String> values = [
    'Sand',
    'Wadh Sand',
    'Wahair Sand',
    'Crush',
    'Bricks',
    'Soil',
    'Other',
  ];
}

/// Expense categories, matching the spec exactly.
class ExpenseCategories {
  ExpenseCategories._();
  static const List<String> values = [
    'Diesel',
    'Labour',
    'Commission',
    'Loading',
    'Unloading',
    'Toll Tax',
    'Repair',
    'Tyre',
    'Engine Oil',
    'Food',
    'Tea',
    'Parking',
    'Police Fine',
    'Other',
  ];

  /// A short list surfaced as "quick expense" buttons on the trip detail
  /// screen, since these are the ones truck owners log most often.
  static const List<String> quick = [
    'Diesel',
    'Labour',
    'Toll Tax',
    'Food',
  ];
}

/// Payment methods supported when recording a customer payment.
enum PaymentMethod { cash, bank, jazzCash, easyPaisa }

extension PaymentMethodLabel on PaymentMethod {
  String get label {
    switch (this) {
      case PaymentMethod.cash:
        return 'Cash';
      case PaymentMethod.bank:
        return 'Bank';
      case PaymentMethod.jazzCash:
        return 'JazzCash';
      case PaymentMethod.easyPaisa:
        return 'EasyPaisa';
    }
  }

  static PaymentMethod fromLabel(String label) {
    return PaymentMethod.values.firstWhere(
      (e) => e.label == label,
      orElse: () => PaymentMethod.cash,
    );
  }
}

/// Derived payment status for a trip / customer balance.
enum PaymentStatus { paid, partial, pending }

extension PaymentStatusLabel on PaymentStatus {
  String get label {
    switch (this) {
      case PaymentStatus.paid:
        return 'Paid';
      case PaymentStatus.partial:
        return 'Partial';
      case PaymentStatus.pending:
        return 'Pending';
    }
  }
}

/// Report date-range filter options.
enum ReportRange { today, thisWeek, thisMonth, custom }
