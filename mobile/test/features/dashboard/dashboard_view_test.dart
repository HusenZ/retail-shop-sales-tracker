import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:retail_shop/core/load_status.dart';
import 'package:retail_shop/features/auth/presentation/auth_cubit.dart';
import 'package:retail_shop/features/dashboard/domain/dashboard.dart';
import 'package:retail_shop/features/dashboard/presentation/dashboard_cubit.dart';
import 'package:retail_shop/features/dashboard/presentation/dashboard_page.dart';
import 'package:retail_shop/features/shop/domain/shop.dart';

import '../../helpers/fixtures.dart';

class MockDashboardCubit extends MockCubit<DashboardState> implements DashboardCubit {}

class MockAuthCubit extends MockCubit<AuthState> implements AuthCubit {}

void main() {
  PeriodTotals period(String first, String total, int count, String profit) => PeriodTotals(
        firstDay: DateTime.parse(first),
        salesTotal: money(total),
        saleCount: count,
        profit: money(profit),
      );

  Future<void> pumpDashboard(WidgetTester tester, DashboardState state) async {
    final dashboard = MockDashboardCubit();
    final auth = MockAuthCubit();
    when(() => dashboard.state).thenReturn(state);
    when(() => auth.state).thenReturn(
      const AuthState(
        status: AuthStatus.authenticated,
        shop: Shop(id: 'shop-1', name: 'Ravi Mobiles', ownerName: 'Ravi', phone: '9876543210'),
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: MultiBlocProvider(
          providers: [
            BlocProvider<DashboardCubit>.value(value: dashboard),
            BlocProvider<AuthCubit>.value(value: auth),
          ],
          child: const DashboardView(),
        ),
      ),
    );
  }

  testWidgets("shows today's figures from the server", (tester) async {
    await pumpDashboard(
      tester,
      DashboardState(
        status: LoadStatus.success,
        dashboard: Dashboard(
          today: period('2026-09-16', '24850', 12, '4280'),
          thisWeek: period('2026-09-14', '60000', 30, '9000'),
          thisMonth: period('2026-09-01', '482500', 140, '72300'),
          pendingTotal: money('5000'),
          pendingSaleCount: 1,
        ),
      ),
    );

    expect(find.text('Ravi Mobiles'), findsOneWidget);
    expect(find.text('₹24,850'), findsOneWidget);
    expect(find.text('₹4,280'), findsOneWidget);
    expect(find.text('12'), findsOneWidget);
    expect(find.text('₹4,82,500'), findsOneWidget);
    expect(find.text('₹5,000'), findsOneWidget);
    expect(find.text('Add Sale'), findsOneWidget);
  });

  testWidgets('offers a retry when loading fails', (tester) async {
    await pumpDashboard(
      tester,
      const DashboardState(status: LoadStatus.failure, errorMessage: 'No internet connection.'),
    );

    expect(find.text('No internet connection.'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
  });
}
