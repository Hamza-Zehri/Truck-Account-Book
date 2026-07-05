import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:truck_account_book/core/constants/app_constants.dart';
import 'package:truck_account_book/core/widgets/shared_widgets.dart';
import 'package:truck_account_book/data/repositories/expense_repository.dart';
import 'package:truck_account_book/data/repositories/report_repository.dart';
import 'package:truck_account_book/data/repositories/trip_repository.dart';

/// Add Expense screen. If opened from a trip's detail page, [tripId] is
/// pre-filled and locked; otherwise the user can optionally attach the
/// expense to a trip via a dropdown (spec: "Trip (optional)").
class AddExpenseScreen extends ConsumerStatefulWidget {
  final int? tripId;
  const AddExpenseScreen({super.key, this.tripId});

  @override
  ConsumerState<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends ConsumerState<AddExpenseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  String _category = ExpenseCategories.values.first;
  DateTime _date = DateTime.now();
  int? _selectedTripId;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _selectedTripId = widget.tripId;
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await ref.read(expenseRepositoryProvider).addExpense(
            tripId: _selectedTripId,
            category: _category,
            amount: double.parse(_amountCtrl.text.trim()),
            date: _date,
            notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
          );
      ref.read(dashboardRefreshTickerProvider.notifier).state++;
      if (mounted) context.pop();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tripsAsync = ref.watch(allTripSummariesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Add Expense')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            DropdownButtonFormField<String>(
              initialValue: _category,
              decoration: const InputDecoration(labelText: 'Category'),
              items: ExpenseCategories.values
                  .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                  .toList(),
              onChanged: (v) => setState(() => _category = v ?? _category),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _amountCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Amount', prefixText: 'Rs. '),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Enter amount';
                if (double.tryParse(v.trim()) == null) return 'Enter a valid number';
                return null;
              },
            ),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Date'),
              subtitle: Text(formatDate(_date)),
              trailing: const Icon(Icons.calendar_today, size: 18),
              onTap: _pickDate,
            ),
            const SizedBox(height: 8),
            if (widget.tripId == null)
              tripsAsync.when(
                data: (list) => DropdownButtonFormField<int?>(
                  initialValue: _selectedTripId,
                  decoration: const InputDecoration(labelText: 'Trip (optional)'),
                  items: [
                    const DropdownMenuItem<int?>(value: null, child: Text('General expense (no trip)')),
                    ...list.map((s) => DropdownMenuItem<int?>(
                          value: s.trip.id,
                          child: Text('${s.customer.name} • ${formatDate(s.trip.date)}'),
                        )),
                  ],
                  onChanged: (v) => setState(() => _selectedTripId = v),
                ),
                loading: () => const LinearProgressIndicator(),
                error: (e, st) => Text('Error: $e'),
              )
            else
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 4),
                child: Text('Linked to current trip', style: TextStyle(color: Colors.grey)),
              ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _notesCtrl,
              decoration: const InputDecoration(labelText: 'Notes'),
              maxLines: 2,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Save Expense'),
            ),
          ],
        ),
      ),
    );
  }
}
