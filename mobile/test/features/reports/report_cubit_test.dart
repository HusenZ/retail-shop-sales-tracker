import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:retail_shop/features/reports/data/report_repository.dart';
import 'package:retail_shop/features/reports/domain/report.dart';
import 'package:retail_shop/features/reports/presentation/report_cubit.dart';

import '../../helpers/fixtures.dart';

class MockReportRepository extends Mock implements ReportRepository {}

void main() {
  late MockReportRepository reports;
  final wednesday = DateTime(2026, 9, 16, 15, 30);

  final emptySummary = ReportSummary(
    totals: ReportTotals(
      saleCount: 0,
      revenue: money('0'),
      cost: money('0'),
      grossProfit: money('0'),
      discount: money('0'),
      expenses: money('0'),
      netProfit: money('0'),
    ),
    byCategory: const [],
    bySaleType: const [],
    byPaymentMethod: const [],
  );

  setUpAll(() => registerFallbackValue(DateTime(2000)));

  setUp(() {
    reports = MockReportRepository();
    when(
      () => reports.summary(
        firstDay: any(named: 'firstDay'),
        lastDay: any(named: 'lastDay'),
      ),
    ).thenAnswer((_) async => emptySummary);
  });

  void expectRequested(DateTime firstDay, DateTime lastDay) {
    verify(() => reports.summary(firstDay: firstDay, lastDay: lastDay)).called(1);
  }

  test('starts with this month up to today', () async {
    final cubit = ReportCubit(reports, now: () => wednesday);

    await cubit.load();

    expectRequested(DateTime(2026, 9, 1), DateTime(2026, 9, 16));
    expect(cubit.state.summary, emptySummary);
  });

  test('today and this week', () async {
    final cubit = ReportCubit(reports, now: () => wednesday);

    await cubit.selectPeriod(ReportPeriod.today);
    expectRequested(DateTime(2026, 9, 16), DateTime(2026, 9, 16));

    await cubit.selectPeriod(ReportPeriod.week);
    expectRequested(DateTime(2026, 9, 14), DateTime(2026, 9, 16));
  });

  test('custom range drops the time of day', () async {
    final cubit = ReportCubit(reports, now: () => wednesday);

    await cubit.selectRange(DateTime(2026, 8, 1, 9), DateTime(2026, 8, 31, 18));

    expect(cubit.state.period, ReportPeriod.custom);
    expectRequested(DateTime(2026, 8, 1), DateTime(2026, 8, 31));
  });
}
