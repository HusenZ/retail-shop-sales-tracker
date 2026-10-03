import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/load_status.dart';
import '../data/dashboard_repository.dart';
import '../domain/dashboard.dart';

class DashboardState extends Equatable {
  const DashboardState({this.status = LoadStatus.initial, this.dashboard, this.errorMessage});

  final LoadStatus status;
  final Dashboard? dashboard;
  final String? errorMessage;

  @override
  List<Object?> get props => [status, dashboard, errorMessage];
}

class DashboardCubit extends Cubit<DashboardState> {
  DashboardCubit(this._dashboard, {required Stream<void> saleChanges})
      : super(const DashboardState()) {
    _subscription = saleChanges.listen((_) => load());
  }

  final DashboardRepository _dashboard;
  late final StreamSubscription<void> _subscription;

  Future<void> load() async {
    // Keep showing the last figures while refreshing.
    if (state.dashboard == null) emit(const DashboardState(status: LoadStatus.loading));
    try {
      final dashboard = await _dashboard.load();
      if (!isClosed) emit(DashboardState(status: LoadStatus.success, dashboard: dashboard));
    } on ApiException catch (error) {
      if (!isClosed) {
        emit(
          DashboardState(
            status: state.dashboard == null ? LoadStatus.failure : LoadStatus.success,
            dashboard: state.dashboard,
            errorMessage: error.message,
          ),
        );
      }
    }
  }

  @override
  Future<void> close() {
    _subscription.cancel();
    return super.close();
  }
}
