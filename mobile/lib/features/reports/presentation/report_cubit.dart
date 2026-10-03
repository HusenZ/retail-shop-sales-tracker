import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/format/dates.dart';
import '../../../core/load_status.dart';
import '../data/report_repository.dart';
import '../domain/report.dart';

enum ReportPeriod {
  today('Today'),
  week('This week'),
  month('This month'),
  custom('Pick dates');

  const ReportPeriod(this.label);

  final String label;
}

class ReportState extends Equatable {
  const ReportState({
    required this.period,
    required this.firstDay,
    required this.lastDay,
    this.status = LoadStatus.initial,
    this.summary,
    this.errorMessage,
  });

  final ReportPeriod period;
  final DateTime firstDay;
  final DateTime lastDay;
  final LoadStatus status;
  final ReportSummary? summary;
  final String? errorMessage;

  ReportState withRange(ReportPeriod period, DateTime firstDay, DateTime lastDay) =>
      ReportState(period: period, firstDay: firstDay, lastDay: lastDay, summary: summary);

  @override
  List<Object?> get props => [period, firstDay, lastDay, status, summary, errorMessage];
}

/// Picks the date range and loads its report. The phone only chooses dates; every
/// figure comes from the server.
class ReportCubit extends Cubit<ReportState> {
  ReportCubit(this._reports, {List<Stream<void>> refreshOn = const [], DateTime Function()? now})
      : _now = now ?? DateTime.now,
        super(_initialState((now ?? DateTime.now)())) {
    _subscriptions = [for (final stream in refreshOn) stream.listen((_) => load())];
  }

  final ReportRepository _reports;
  final DateTime Function() _now;
  late final List<StreamSubscription<void>> _subscriptions;

  static ReportState _initialState(DateTime now) {
    final today = dateOnly(now);
    return ReportState(period: ReportPeriod.month, firstDay: startOfMonth(today), lastDay: today);
  }

  Future<void> load() async {
    emit(
      ReportState(
        period: state.period,
        firstDay: state.firstDay,
        lastDay: state.lastDay,
        status: LoadStatus.loading,
        summary: state.summary,
      ),
    );
    try {
      final summary = await _reports.summary(firstDay: state.firstDay, lastDay: state.lastDay);
      if (!isClosed) {
        emit(
          ReportState(
            period: state.period,
            firstDay: state.firstDay,
            lastDay: state.lastDay,
            status: LoadStatus.success,
            summary: summary,
          ),
        );
      }
    } on ApiException catch (error) {
      if (!isClosed) {
        emit(
          ReportState(
            period: state.period,
            firstDay: state.firstDay,
            lastDay: state.lastDay,
            status: LoadStatus.failure,
            summary: state.summary,
            errorMessage: error.message,
          ),
        );
      }
    }
  }

  Future<void> selectPeriod(ReportPeriod period) {
    final today = dateOnly(_now());
    final firstDay = switch (period) {
      ReportPeriod.today => today,
      ReportPeriod.week => startOfWeek(today),
      ReportPeriod.month || ReportPeriod.custom => startOfMonth(today),
    };
    emit(state.withRange(period, firstDay, today));
    return load();
  }

  Future<void> selectRange(DateTime firstDay, DateTime lastDay) {
    emit(state.withRange(ReportPeriod.custom, dateOnly(firstDay), dateOnly(lastDay)));
    return load();
  }

  @override
  Future<void> close() {
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    return super.close();
  }
}
