import 'package:truck_account_book/core/constants/app_constants.dart';

/// Pure, side-effect-free calculation helpers shared by the dashboard,
/// trip details, customer ledger, and reports screens so the "profit is
/// always up to date" rule in the spec has exactly one implementation.
class Calculations {
  Calculations._();

  /// Trip Profit = Trip Amount - Total Expenses (for that trip).
  static double tripProfit({
    required double tripAmount,
    required double totalExpenses,
  }) {
    return tripAmount - totalExpenses;
  }

  /// Remaining balance for a single trip = Trip Amount - Payments Received.
  static double tripBalance({
    required double tripAmount,
    required double totalPaid,
  }) {
    final remaining = tripAmount - totalPaid;
    return remaining < 0 ? 0 : remaining;
  }

  /// Customer balance across all of their trips.
  static double customerBalance({
    required double totalBusiness,
    required double totalReceived,
  }) {
    final remaining = totalBusiness - totalReceived;
    return remaining < 0 ? 0 : remaining;
  }

  /// Dashboard-level profit = Total Income - Total Expenses.
  static double dashboardProfit({
    required double totalIncome,
    required double totalExpenses,
  }) {
    return totalIncome - totalExpenses;
  }

  static PaymentStatus statusFor({
    required double tripAmount,
    required double totalPaid,
  }) {
    if (tripAmount <= 0) return PaymentStatus.paid;
    if (totalPaid <= 0) return PaymentStatus.pending;
    if (totalPaid >= tripAmount) return PaymentStatus.paid;
    return PaymentStatus.partial;
  }
}
