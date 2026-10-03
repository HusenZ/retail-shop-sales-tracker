import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/load_status.dart';
import '../data/sale_repository.dart';
import '../domain/sale.dart';

class SaleListState extends Equatable {
  const SaleListState({
    this.status = LoadStatus.initial,
    this.sales = const [],
    this.filters = const SaleFilters(),
    this.hasMore = false,
    this.isLoadingMore = false,
    this.errorMessage,
  });

  final LoadStatus status;
  final List<SaleSummary> sales;
  final SaleFilters filters;
  final bool hasMore;
  final bool isLoadingMore;
  final String? errorMessage;

  SaleListState copyWith({
    LoadStatus? status,
    List<SaleSummary>? sales,
    SaleFilters? filters,
    bool? hasMore,
    bool? isLoadingMore,
    String? errorMessage,
  }) =>
      SaleListState(
        status: status ?? this.status,
        sales: sales ?? this.sales,
        filters: filters ?? this.filters,
        hasMore: hasMore ?? this.hasMore,
        isLoadingMore: isLoadingMore ?? this.isLoadingMore,
        errorMessage: errorMessage,
      );

  @override
  List<Object?> get props => [status, sales, filters, hasMore, isLoadingMore, errorMessage];
}

class SaleListCubit extends Cubit<SaleListState> {
  SaleListCubit(this._sales) : super(const SaleListState()) {
    _subscription = _sales.changes.listen((_) => load());
  }

  static const pageSize = 50;

  final SaleRepository _sales;
  late final StreamSubscription<void> _subscription;

  Future<void> load() async {
    emit(state.copyWith(status: LoadStatus.loading));
    try {
      final sales = await _sales.list(filters: state.filters, limit: pageSize);
      if (!isClosed) {
        emit(
          state.copyWith(
            status: LoadStatus.success,
            sales: sales,
            hasMore: sales.length == pageSize,
          ),
        );
      }
    } on ApiException catch (error) {
      if (!isClosed) {
        emit(state.copyWith(status: LoadStatus.failure, errorMessage: error.message));
      }
    }
  }

  Future<void> loadMore() async {
    if (!state.hasMore || state.isLoadingMore) return;
    emit(state.copyWith(isLoadingMore: true));
    try {
      final more = await _sales.list(
        filters: state.filters,
        limit: pageSize,
        offset: state.sales.length,
      );
      if (!isClosed) {
        emit(
          state.copyWith(
            sales: [...state.sales, ...more],
            hasMore: more.length == pageSize,
            isLoadingMore: false,
          ),
        );
      }
    } on ApiException catch (error) {
      if (!isClosed) emit(state.copyWith(isLoadingMore: false, errorMessage: error.message));
    }
  }

  Future<void> applyFilters(SaleFilters filters) {
    emit(state.copyWith(filters: filters, sales: const []));
    return load();
  }

  @override
  Future<void> close() {
    _subscription.cancel();
    return super.close();
  }
}
