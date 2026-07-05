import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:truck_account_book/core/constants/app_constants.dart';
import 'package:truck_account_book/core/widgets/shared_widgets.dart';
import 'package:truck_account_book/data/database/app_database.dart';
import 'package:truck_account_book/data/repositories/customer_repository.dart';
import 'package:truck_account_book/data/repositories/payment_repository.dart';
import 'package:truck_account_book/data/repositories/report_repository.dart';
import 'package:truck_account_book/data/repositories/trip_repository.dart';

/// Receive Payment screen. Can be opened generally (from dashboard), from
/// a trip (pre-fills customer + trip), or from a customer ledger
/// (pre-fills customer only).
class ReceivePaymentScreen extends ConsumerStatefulWidget {
  final int? tripId;
  final int? customerId;
  const ReceivePaymentScreen({super.key, this.tripId, this.customerId});

  @override
  ConsumerState<ReceivePaymentScreen> createState() => _ReceivePaymentScreenState();
}

class _ReceivePaymentScreenState extends ConsumerState<ReceivePaymentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountCtrl = TextEditingController();
  final _referenceCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  DateTime _date = DateTime.now();
  PaymentMethod _method = PaymentMethod.cash;
  Customer? _selectedCustomer;
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
    _referenceCtrl.dispose();
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
    final customerId = widget.customerId ?? _selectedCustomer?.id;
    if (customerId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a customer')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await ref.read(paymentRepositoryProvider).addPayment(
            customerId: customerId,
            tripId: _selectedTripId,
            amount: double.parse(_amountCtrl.text.trim()),
            date: _date,
            method: _method,
            reference: _referenceCtrl.text.trim().isEmpty ? null : _referenceCtrl.text.trim(),
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
    final customersAsync = ref.watch(allCustomersProvider);
    final tripsAsync = ref.watch(allTripSummariesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Receive Payment')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (widget.customerId == null)
              customersAsync.when(
                data: (customers) => DropdownButtonFormField<Customer>(
                  initialValue: _selectedCustomer,
                  decoration: const InputDecoration(labelText: 'Customer'),
                  items: customers
                      .map((c) => DropdownMenuItem(value: c, child: Text(c.name)))
                      .toList(),
                  onChanged: (v) => setState(() => _selectedCustomer = v),
                  validator: (v) => v == null ? 'Select a customer' : null,
                ),
                loading: () => const LinearProgressIndicator(),
                error: (e, st) => Text('Error: $e'),
              )
            else
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 4),
                child: Text('Payment for selected customer', style: TextStyle(color: Colors.grey)),
              ),
            const SizedBox(height: 12),
            if (widget.tripId == null)
              tripsAsync.when(
                data: (list) => DropdownButtonFormField<int?>(
                  initialValue: _selectedTripId,
                  decoration: const InputDecoration(labelText: 'Trip (optional)'),
                  items: [
                    const DropdownMenuItem<int?>(value: null, child: Text('General payment (no trip)')),
                    ...list.map((s) => DropdownMenuItem<int?>(
                          value: s.trip.id,
                          child: Text('${s.customer.name} • ${formatDate(s.trip.date)}'),
                        )),
                  ],
                  onChanged: (v) => setState(() => _selectedTripId = v),
                ),
                loading: () => const LinearProgressIndicator(),
                error: (e, st) => Text('Error: $e'),
              ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _amountCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Amount Received', prefixText: 'Rs. '),
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
            DropdownButtonFormField<PaymentMethod>(
              initialValue: _method,
              decoration: const InputDecoration(labelText: 'Payment Method'),
              items: PaymentMethod.values
                  .map((m) => DropdownMenuItem(value: m, child: Text(m.label)))
                  .toList(),
              onChanged: (v) => setState(() => _method = v ?? _method),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _referenceCtrl,
              decoration: const InputDecoration(labelText: 'Reference (optional)'),
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
                  : const Text('Save Payment'),
            ),
          ],
        ),
      ),
    );
  }
}
