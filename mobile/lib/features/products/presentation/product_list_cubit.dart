import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/load_status.dart';
import '../data/product_repository.dart';
import '../domain/product.dart';

class ProductListState extends Equatable {
  const ProductListState({
    this.status = LoadStatus.initial,
    this.products = const [],
    this.search = '',
    this.stockFilter,
    this.errorMessage,
  });

  final LoadStatus status;
  final List<Product> products;
  final String search;
  final StockStatus? stockFilter;
  final String? errorMessage;

  ProductListState copyWith({
    LoadStatus? status,
    List<Product>? products,
    String? search,
    ValueGetter<StockStatus?>? stockFilter,
    ValueGetter<String?>? errorMessage,
  }) =>
      ProductListState(
        status: status ?? this.status,
        products: products ?? this.products,
        search: search ?? this.search,
        stockFilter: stockFilter != null ? stockFilter() : this.stockFilter,
        errorMessage: errorMessage != null ? errorMessage() : this.errorMessage,
      );

  @override
  List<Object?> get props => [status, products, search, stockFilter, errorMessage];
}

/// Product list with search and stock filter; also backs the product picker in Add Sale.
class ProductListCubit extends Cubit<ProductListState> {
  ProductListCubit(this._products, {Stream<void>? saleChanges})
      : super(const ProductListState()) {
    _subscriptions = [
      _products.changes.listen((_) => load()),
      if (saleChanges != null) saleChanges.listen((_) => load()),
    ];
  }

  static const _searchDelay = Duration(milliseconds: 300);

  final ProductRepository _products;
  late final List<StreamSubscription<void>> _subscriptions;
  Timer? _searchTimer;

  Future<void> load() async {
    emit(state.copyWith(status: LoadStatus.loading, errorMessage: () => null));
    try {
      final products = await _products.list(
        search: state.search.isEmpty ? null : state.search,
        stockStatus: state.stockFilter,
      );
      if (!isClosed) emit(state.copyWith(status: LoadStatus.success, products: products));
    } on ApiException catch (error) {
      if (!isClosed) {
        emit(state.copyWith(status: LoadStatus.failure, errorMessage: () => error.message));
      }
    }
  }

  void search(String text) {
    emit(state.copyWith(search: text.trim()));
    _searchTimer?.cancel();
    _searchTimer = Timer(_searchDelay, load);
  }

  Future<void> filterByStock(StockStatus? filter) {
    emit(state.copyWith(stockFilter: () => filter));
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
