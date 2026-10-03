import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/load_status.dart';
import '../data/customer_repository.dart';
import '../domain/customer.dart';

class CustomerListState extends Equatable {
  const CustomerListState({
    this.status = LoadStatus.initial,
    this.customers = const [],
    this.search = '',
    this.pendingOnly = false,
    this.errorMessage,
  });

  final LoadStatus status;
  final List<Customer> customers;
  final String search;
  final bool pendingOnly;
  final String? errorMessage;

  CustomerListState copyWith({
    LoadStatus? status,
    List<Customer>? customers,
    String? search,
    bool? pendingOnly,
    String? errorMessage,
  }) =>
      CustomerListState(
        status: status ?? this.status,
        customers: customers ?? this.customers,
        search: search ?? this.search,
        pendingOnly: pendingOnly ?? this.pendingOnly,
        errorMessage: errorMessage,
      );

  @override
  List<Object?> get props => [status, customers, search, pendingOnly, errorMessage];
}

class CustomerListCubit extends Cubit<CustomerListState> {
  CustomerListCubit(this._customers, {bool pendingOnly = false, Stream<void>? saleChanges})
      : super(CustomerListState(pendingOnly: pendingOnly)) {
    _subscriptions = [
      _customers.changes.listen((_) => load()),
      if (saleChanges != null) saleChanges.listen((_) => load()),
    ];
  }

  static const _searchDelay = Duration(milliseconds: 300);

  final CustomerRepository _customers;
  late final List<StreamSubscription<void>> _subscriptions;
  Timer? _searchTimer;

  Future<void> load() async {
    emit(state.copyWith(status: LoadStatus.loading));
    try {
      final customers = await _customers.list(
        search: state.search.isEmpty ? null : state.search,
        pendingOnly: state.pendingOnly,
      );
      if (!isClosed) emit(state.copyWith(status: LoadStatus.success, customers: customers));
    } on ApiException catch (error) {
      if (!isClosed) {
        emit(state.copyWith(status: LoadStatus.failure, errorMessage: error.message));
      }
    }
  }

  void search(String text) {
    emit(state.copyWith(search: text.trim()));
    _searchTimer?.cancel();
    _searchTimer = Timer(_searchDelay, load);
  }

  Future<void> showPendingOnly(bool pendingOnly) {
    emit(state.copyWith(pendingOnly: pendingOnly));
    return load();
  }

  @override
  Future<void> close() {
    _searchTimer?.cancel();
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    return super.close();
  }
}
