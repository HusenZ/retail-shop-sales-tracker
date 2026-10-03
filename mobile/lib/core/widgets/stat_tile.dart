import 'package:flutter/material.dart';

/// A labelled number, e.g. "Profit ₹4,280".
class StatTile extends StatelessWidget {
  const StatTile({required this.label, required this.value, this.color, this.large = false, super.key});

  final String label;
  final String value;
  final Color? color;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: text.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.outline)),
        const SizedBox(height: 4),
        Text(
          value,
          style: (large ? text.headlineMedium : text.titleLarge)?.copyWith(
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}

/// Label on the left, amount on the right; used in totals and report rows.
class AmountRow extends StatelessWidget {
  const AmountRow({required this.label, required this.value, this.bold = false, this.color, super.key});

  final String label;
  final String value;
  final bool bold;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(fontWeight: bold ? FontWeight.bold : null, color: color, fontSize: 16);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(label, style: style)),
          Text(value, style: style),
        ],
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 16, 0, 8),
      child: Text(text, style: Theme.of(context).textTheme.titleMedium),
    );
  }
}
