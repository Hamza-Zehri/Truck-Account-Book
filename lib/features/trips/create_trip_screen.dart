import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:truck_account_book/core/constants/app_constants.dart';
import 'package:truck_account_book/core/widgets/shared_widgets.dart';
import 'package:truck_account_book/data/database/app_database.dart';
import 'package:truck_account_book/data/repositories/customer_repository.dart';
import 'package:truck_account_book/data/repositories/report_repository.dart';
import 'package:truck_account_book/data/repositories/trip_repository.dart';

/// New Trip screen. Reachable from the dashboard in a single tap, and
/// saveable in three taps total (open -> fill -> save) for a returning
/// customer thanks to autocomplete + remembered material type.
class CreateTripScreen extends ConsumerStatefulWidget {
  final Trip? existing; // non-null when editing
  const CreateTripScreen({super.key, this.existing});

  @override
  ConsumerState<CreateTripScreen> createState() => _CreateTripScreenState();
}

class _CreateTripScreenState extends ConsumerState<CreateTripScreen> {
  final _formKey = GlobalKey<FormState>();
  final _customerNameCtrl = TextEditingController();
  final _customerPhoneCtrl = TextEditingController();
  final _quantityCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  DateTime _date = DateTime.now();
  String _materialType = MaterialTypes.values.first;
  Customer? _selectedCustomer;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _date = e.date;
      _materialType = e.materialType;
      _quantityCtrl.text = e.quantity;
      _amountCtrl.text = e.tripAmount == 0 ? '' : e.tripAmount.toStringAsFixed(0);
      _notesCtrl.text = e.notes ?? '';
    }
  }

  @override
  void dispose() {
    _customerNameCtrl.dispose();
    _customerPhoneCtrl.dispose();
    _quantityCtrl.dispose();
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

  Future<int> _resolveCustomerId() async {
    final repo = ref.read(customerRepositoryProvider);
    if (_selectedCustomer != null) return _selectedCustomer!.id;
    // No existing customer selected -> create one from the typed name.
    return repo.createCustomer(
      name: _customerNameCtrl.text.trim(),
      phone: _customerPhoneCtrl.text.trim().isEmpty ? null : _customerPhoneCtrl.text.trim(),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final customerId = await _resolveCustomerId();
      final tripRepo = ref.read(tripRepositoryProvider);
      final amount = double.tryParse(_amountCtrl.text.trim()) ?? 0;

      if (widget.existing != null) {
        await tripRepo.updateTrip(widget.existing!.copyWith(
          date: _date,
          customerId: customerId,
          materialType: _materialType,
          quantity: _quantityCtrl.text.trim(),
          tripAmount: amount,
          notes: Value(_notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim()),
        ));
      } else {
        await tripRepo.createTrip(
          date: _date,
          customerId: customerId,
          materialType: _materialType,
          quantity: _quantityCtrl.text.trim(),
          tripAmount: amount,
          notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
        );
      }
      ref.read(dashboardRefreshTickerProvider.notifier).state++;
      if (mounted) context.pop();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final customersAsync = ref.watch(allCustomersProvider);

    return Scaffold(
      appBar: AppBar(title: Text(widget.existing == null ? 'New Trip' : 'Edit Trip')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Date'),
              subtitle: Text(formatDate(_date)),
              trailing: const Icon(Icons.calendar_today, size: 18),
              onTap: _pickDate,
            ),
            const SizedBox(height: 8),
            customersAsync.when(
              data: (customers) => Autocomplete<Customer>(
                displayStringForOption: (c) => c.name,
                optionsBuilder: (v) {
                  if (v.text.isEmpty) return const Iterable<Customer>.empty();
                  return customers.where(
                      (c) => c.name.toLowerCase().contains(v.text.toLowerCase()));
                },
                onSelected: (c) {
                  _selectedCustomer = c;
                  _customerNameCtrl.text = c.name;
                  _customerPhoneCtrl.text = c.phone ?? '';
                },
                fieldViewBuilder: (context, controller, focusNode, onSubmit) {
                  controller.text = _customerNameCtrl.text;
                  return TextFormField(
                    controller: controller,
                    focusNode: focusNode,
                    decoration: const InputDecoration(labelText: 'Customer Name'),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter customer name' : null,
                    onChanged: (v) {
                      _customerNameCtrl.text = v;
                      _selectedCustomer = null;
                    },
                  );
                },
              ),
              loading: () => TextFormField(
                controller: _customerNameCtrl,
                decoration: const InputDecoration(labelText: 'Customer Name'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter customer name' : null,
              ),
              error: (e, st) => Text('Error: $e'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _customerPhoneCtrl,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Customer Phone (optional)'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _materialType,
              decoration: const InputDecoration(labelText: 'Material Type'),
              items: MaterialTypes.values
                  .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                  .toList(),
              onChanged: (v) => setState(() => _materialType = v ?? _materialType),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _quantityCtrl,
              decoration: const InputDecoration(
                labelText: 'Quantity',
                hintText: 'e.g. 20 Ton or 5000 Bricks',
              ),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter quantity' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _amountCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Trip Amount', prefixText: 'Rs. '),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Enter trip amount';
                if (double.tryParse(v.trim()) == null) return 'Enter a valid number';
                return null;
              },
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
                  ? const SizedBox(
                      width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Save Trip'),
            ),
          ],
        ),
      ),
    );
  }
}
