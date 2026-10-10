import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/widgets/inputs.dart';
import '../data/customer_repository.dart';
import '../domain/customer.dart';

/// Creates a customer, or edits [existing]. Returns the saved customer, or null if cancelled.
Future<Customer?> showCustomerForm(BuildContext context, {Customer? existing}) {
  return showDialog<Customer>(
    context: context,
    builder: (_) => _CustomerFormDialog(
      repository: context.read<CustomerRepository>(),
      existing: existing,
    ),
  );
}

class _CustomerFormDialog extends StatefulWidget {
  const _CustomerFormDialog({required this.repository, this.existing});

  final CustomerRepository repository;
  final Customer? existing;

  @override
  State<_CustomerFormDialog> createState() => _CustomerFormDialogState();
}

class _CustomerFormDialogState extends State<_CustomerFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.existing?.name);
  late final _phone = TextEditingController(text: widget.existing?.phone);
  late final _notes = TextEditingController(text: widget.existing?.notes);
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    final input = CustomerInput(
      name: _name.text.trim(),
      phone: cleanOptional(_phone.text.replaceAll(RegExp(r'[\s\-()]'), '')),
      notes: cleanOptional(_notes.text),
    );
    try {
      final existing = widget.existing;
      final customer = existing == null
          ? await widget.repository.create(input)
          : await widget.repository.update(existing.id, input);
      if (mounted) Navigator.of(context).pop(customer);
    } on ApiException catch (error) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = error.message;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existing == null ? 'New customer' : 'Edit customer'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _name,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Name'),
                validator: requiredText,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Phone (optional)'),
                validator: optionalPhone,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _notes,
                decoration: const InputDecoration(labelText: 'Notes (optional)'),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        TextButton(onPressed: _saving ? null : _save, child: const Text('Save')),
      ],
    );
  }
}
