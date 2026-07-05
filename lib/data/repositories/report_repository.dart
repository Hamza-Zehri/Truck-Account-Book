import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:truck_account_book/core/constants/app_constants.dart';
import 'package:truck_account_book/core/utils/calculations.dart';
import 'package:truck_account_book/data/database/app_database.dart';
import 'package:truck_account_book/data/database/database_provider.dart';

/// Aggregated numbers for a date range: used by both the Home Dashboard
/// ("Today's ...") and the Reports screen (Today / Week / Month / Custom).
class PeriodSummary {
  final int tripCount;
  final double totalIncome;
  final double totalExpenses;
  final double netDriverCash;
  final double pendingPayments;
  final Map<String, double> expenseBreakdown;

  PeriodSummary({
    required this.tripCount,
    required this.totalIncome,
    required this.totalExpenses,
    required this.netDriverCash,
    required this.pendingPayments,
    required this.expenseBreakdown,
  });

  double get profit => Calculations.dashboardProfit(
        totalIncome: totalIncome,
        totalExpenses: totalExpenses,
      );

  static PeriodSummary empty() => PeriodSummary(
        tripCount: 0,
        totalIncome: 0,
        totalExpenses: 0,
        netDriverCash: 0,
        pendingPayments: 0,
        expenseBreakdown: {},
      );
}

class ReportRepository {
  final AppDatabase db;
  ReportRepository(this.db);

  (DateTime, DateTime) rangeFor(ReportRange range, {DateTime? customStart, DateTime? customEnd}) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    switch (range) {
      case ReportRange.today:
        return (today, today.add(const Duration(days: 1)));
      case ReportRange.thisWeek:
        final startOfWeek = today.subtract(Duration(days: today.weekday - 1));
        return (startOfWeek, startOfWeek.add(const Duration(days: 7)));
      case ReportRange.thisMonth:
        final start = DateTime(now.year, now.month, 1);
        final end = DateTime(now.year, now.month + 1, 1);
        return (start, end);
      case ReportRange.custom:
        return (
          customStart ?? today,
          (customEnd ?? today).add(const Duration(days: 1)),
        );
    }
  }

  Future<PeriodSummary> summaryFor(
    ReportRange range, {
    DateTime? customStart,
    DateTime? customEnd,
  }) async {
    final (start, end) = rangeFor(range, customStart: customStart, customEnd: customEnd);

    final trips = await db.tripsBetween(start, end);
    final expenses = await db.expensesBetween(start, end);
    final driverCash = await db.netDriverCashBetween(start, end);

    final totalIncome = trips.fold<double>(0, (sum, t) => sum + t.tripAmount);
    final totalExpenses = expenses.fold<double>(0, (sum, e) => sum + e.amount);

    // Pending payments: for every trip in range, trip amount minus payments
    // received against that trip (regardless of when the payment landed).
    double pending = 0;
    for (final trip in trips) {
      final paymentsForTrip =
          await (db.select(db.payments)..where((p) => p.tripId.equals(trip.id))).get();
      final paid = paymentsForTrip.fold<double>(0, (sum, p) => sum + p.amount);
      final remaining = trip.tripAmount - paid;
      if (remaining > 0) pending += remaining;
    }

    final breakdown = <String, double>{};
    for (final e in expenses) {
      breakdown.update(e.category, (v) => v + e.amount, ifAbsent: () => e.amount);
    }

    final adjustedIncome = totalIncome + driverCash;

    return PeriodSummary(
      tripCount: trips.length,
      totalIncome: adjustedIncome,
      totalExpenses: totalExpenses,
      netDriverCash: driverCash,
      pendingPayments: pending,
      expenseBreakdown: breakdown,
    );
  }
}

final reportRepositoryProvider = Provider<ReportRepository>((ref) {
  return ReportRepository(ref.watch(appDatabaseProvider));
});

/// Today's summary, used by the Home Dashboard. Re-computed whenever any
/// trip/expense/payment stream updates (via the ticker provider below).
final todaySummaryProvider = FutureProvider.autoDispose<PeriodSummary>((ref) async {
  ref.watch(dashboardRefreshTickerProvider);
  return ref.watch(reportRepositoryProvider).summaryFor(ReportRange.today);
});

final periodSummaryProvider = FutureProvider.autoDispose
    .family<PeriodSummary, ({ReportRange range, DateTime? start, DateTime? end})>((ref, args) {
  ref.watch(dashboardRefreshTickerProvider);
  return ref.watch(reportRepositoryProvider).summaryFor(
        args.range,
        customStart: args.start,
        customEnd: args.end,
      );
});

/// A tiny counter that other providers can bump after a write (create trip,
/// add expense, receive payment) to force dashboard/report numbers to
/// recompute immediately rather than waiting on the next stream tick.
final dashboardRefreshTickerProvider = StateProvider<int>((ref) => 0);
