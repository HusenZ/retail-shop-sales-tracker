import 'dart:async';

/// Lets screens refresh when data changes elsewhere, e.g. the dashboard after a sale.
mixin DataChanges {
  final _changes = StreamController<void>.broadcast();

  Stream<void> get changes => _changes.stream;

  void notifyChanged() => _changes.add(null);
}
