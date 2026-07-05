import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:truck_account_book/core/constants/app_constants.dart';
import 'package:truck_account_book/core/theme/app_theme.dart';
import 'package:truck_account_book/core/widgets/shared_widgets.dart';
import 'package:truck_account_book/data/repositories/report_repository.dart';
import 'package:truck_account_book/features/reports/export_service.dart';

class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  ReportRange _range = ReportRange.today;
  DateTime? _customStart;
  DateTime? _customEnd;
  bool _exporting = false;

  Future<void> _pickCustomRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: now.add(const Duration(days: 1)),
      initialDateRange: DateTimeRange(
        start: _customStart ?? now.subtract(const Duration(days: 7)),
        end: _customEnd ?? now,
      ),
    );
    if (picked != null) {
      setState(() {
        _range = ReportRange.custom;
        _customStart = picked.start;
        _customEnd = picked.end;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final summaryAsync = ref.watch(periodSummaryProvider(
      (range: _range, start: _customStart, end: _customEnd),
    ));

    return Scaffold(
      appBar: AppBar(title: const Text('Reports')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Wrap(
            spacing: 8,
            children: [
              _filterChip('Today', ReportRange.today),
              _filterChip('This Week', ReportRange.thisWeek),
              _filterChip('This Month', ReportRange.thisMonth),
              ChoiceChip(
                label: const Text('Custom'),
                selected: _range == ReportRange.custom,
                onSelected: (_) => _pickCustomRange(),
              ),
            ],
          ),
          const SizedBox(height: 16),
          summaryAsync.when(
            data: (s) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 1.35,
                  children: [
                    StatCard(label: 'Total Trips', value: '${s.tripCount}', color: AppColors.primaryBlue, icon: Icons.local_shipping),
                    StatCard(label: 'Income', value: formatMoney(s.totalIncome), color: AppColors.primaryBlue, icon: Icons.trending_up),
                    StatCard(label: 'Expenses', value: formatMoney(s.totalExpenses), color: AppColors.expenseOrange, icon: Icons.receipt_long),
                    StatCard(
                      label: 'Profit',
                      value: formatMoney(s.profit),
                      color: s.profit >= 0 ? AppColors.profitGreen : AppColors.pendingRed,
                      icon: Icons.savings,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Card(
                  color: AppColors.pendingRed.withValues(alpha: 0.06),
                  child: ListTile(
                    leading: const Icon(Icons.warning_amber_rounded, color: AppColors.pendingRed),
                    title: const Text('Pending Payments'),
                    trailing: Text(formatMoney(s.pendingPayments),
                        style: const TextStyle(color: AppColors.pendingRed, fontWeight: FontWeight.w700, fontSize: 16)),
                  ),
                ),
                const SizedBox(height: 20),
                const SectionHeader(title: 'Expense Breakdown'),
                if (s.expenseBreakdown.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text('No expenses in this period.', style: TextStyle(color: AppColors.textMuted)),
                  )
                else
                  ...s.expenseBreakdown.entries.map((e) {
                    final pct = s.totalExpenses == 0 ? 0.0 : e.value / s.totalExpenses;
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(e.key),
                              Text(formatMoney(e.value), style: const TextStyle(fontWeight: FontWeight.w600)),
                            ],
                          ),
                          const SizedBox(height: 4),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: LinearProgressIndicator(
                              value: pct,
                              minHeight: 6,
                              backgroundColor: AppColors.cardBorder,
                              color: AppColors.expenseOrange,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _exporting ? null : () => _export(context, s, asPdf: true),
                        icon: const Icon(Icons.picture_as_pdf),
                        label: const Text('Export PDF'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _exporting ? null : () => _export(context, s, asPdf: false),
                        icon: const Icon(Icons.table_chart),
                        label: const Text('Export Excel'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, st) => Text('Error: $e'),
          ),
        ],
      ),
    );
  }

  Widget _filterChip(String label, ReportRange range) {
    return ChoiceChip(
      label: Text(label),
      selected: _range == range,
      onSelected: (_) => setState(() => _range = range),
    );
  }

  Future<void> _export(BuildContext context, PeriodSummary s, {required bool asPdf}) async {
    setState(() => _exporting = true);
    try {
      final label = switch (_range) {
        ReportRange.today => 'Today',
        ReportRange.thisWeek => 'This Week',
        ReportRange.thisMonth => 'This Month',
        ReportRange.custom => 'Custom Range',
      };
      if (asPdf) {
        await ExportService.exportSummaryToPdf(summary: s, periodLabel: label);
      } else {
        await ExportService.exportSummaryToExcel(summary: s, periodLabel: label);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Export failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }
}
