import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../format/money.dart';

/// Rupee amount field with a numeric keyboard.
class MoneyField extends StatelessWidget {
  const MoneyField({
    required this.label,
    this.controller,
    this.onChanged,
    this.isRequired = false,
    this.allowZero = true,
    this.autofocus = false,
    this.helperText,
    super.key,
  });

  final String label;
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;
  final bool isRequired;
  final bool allowZero;
  final bool autofocus;
  final String? helperText;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      onChanged: onChanged,
      autofocus: autofocus,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
      decoration: InputDecoration(labelText: label, prefixText: '₹ ', helperText: helperText),
      validator: (text) {
        final value = text ?? '';
        if (value.trim().isEmpty) return isRequired ? 'Required' : null;
        final amount = parseMoneyInput(value);
        if (amount == null) return 'Enter a valid amount';
        if (!allowZero && amount == Decimal.zero) return 'Must be more than zero';
        return null;
      },
    );
  }
}

String? requiredText(String? value) => (value == null || value.trim().isEmpty) ? 'Required' : null;

String? optionalPhone(String? value) {
  final digits = (value ?? '').replaceAll(RegExp(r'[\s\-()]'), '');
  if (digits.isEmpty) return null;
  return RegExp(r'^\+?[0-9]{10,15}$').hasMatch(digits) ? null : 'Enter a valid phone number';
}

String? requiredPhone(String? value) => requiredText(value) ?? optionalPhone(value);

String? cleanOptional(String text) => text.trim().isEmpty ? null : text.trim();

/// Asks for a single name, e.g. a new category. Returns null when cancelled.
Future<String?> showNameDialog(
  BuildContext context, {
  required String title,
  String initialValue = '',
  String label = 'Name',
}) {
  final controller = TextEditingController(text: initialValue);
  final formKey = GlobalKey<FormState>();
  return showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Form(
        key: formKey,
        child: TextFormField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(labelText: label),
          validator: requiredText,
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        TextButton(
          onPressed: () {
            if (formKey.currentState!.validate()) {
              Navigator.pop(context, controller.text.trim());
            }
          },
          child: const Text('Save'),
        ),
      ],
    ),
  );
}

Future<bool> confirm(
  BuildContext context, {
  required String title,
  String? message,
  String action = 'Yes',
  String cancel = 'Cancel',
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: message == null ? null : Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: Text(cancel)),
        TextButton(onPressed: () => Navigator.pop(context, true), child: Text(action)),
      ],
    ),
  );
  return result ?? false;
}
