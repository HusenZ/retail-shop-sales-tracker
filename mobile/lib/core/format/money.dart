import 'package:decimal/decimal.dart';

/// Money arrives from the API as strings like "15999.00" and is never a double.
Decimal parseMoney(Object? value) => Decimal.parse(value.toString());

/// Parses what the shopkeeper typed: "15,999", "₹ 500", "499.5". Null when empty,
/// negative, or with more than two decimals.
Decimal? parseMoneyInput(String text) {
  final cleaned = text.replaceAll(RegExp(r'[₹,\s]'), '');
  if (!_amountPattern.hasMatch(cleaned)) return null;
  return Decimal.parse(cleaned);
}

final _amountPattern = RegExp(r'^[0-9]+(\.[0-9]{1,2})?$');

/// ₹4,82,500 — Indian digit grouping, paise shown only when present.
String formatRupees(Decimal amount) {
  final isNegative = amount < Decimal.zero;
  final parts = amount.abs().toStringAsFixed(2).split('.');
  final paise = parts[1] == '00' ? '' : '.${parts[1]}';
  return '${isNegative ? '-' : ''}₹${_groupIndian(parts[0])}$paise';
}

/// Plain value for pre-filling a text field: "15999" or "499.50".
String moneyInputText(Decimal amount) {
  final fixed = amount.toStringAsFixed(2);
  return fixed.endsWith('.00') ? fixed.substring(0, fixed.length - 3) : fixed;
}

String _groupIndian(String digits) {
  if (digits.length <= 3) return digits;
  final lastThree = digits.substring(digits.length - 3);
  var rest = digits.substring(0, digits.length - 3);
  final groups = <String>[];
  while (rest.length > 2) {
    groups.insert(0, rest.substring(rest.length - 2));
    rest = rest.substring(0, rest.length - 2);
  }
  if (rest.isNotEmpty) groups.insert(0, rest);
  return '${groups.join(',')},$lastThree';
}
