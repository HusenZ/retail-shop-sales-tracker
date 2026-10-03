import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:retail_shop/features/sales/presentation/add_sale_cubit.dart';
import 'package:retail_shop/features/sales/presentation/add_sale_page.dart';

import '../../helpers/fixtures.dart';
import '../../helpers/mocks.dart';

void main() {
  late MockSaleRepository sales;
  late AddSaleCubit cubit;

  setUpAll(registerSaleFallbacks);

  setUp(() async {
    final saleTypes = MockSaleTypeRepository();
    sales = MockSaleRepository();
    when(() => saleTypes.list()).thenAnswer((_) async => [newPhoneType, exchangeType]);
    when(() => sales.create(any())).thenAnswer((_) async => savedSale());
    cubit = AddSaleCubit(saleTypes, sales, newClientRef: () => 'ref-1');
    await cubit.load();
  });

  tearDown(() => cubit.close());

  Future<void> pumpView(WidgetTester tester) async {
    // Tall enough that the whole form is built without scrolling.
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider.value(value: cubit, child: const AddSaleView()),
      ),
    );
    await tester.pump();
  }

  FilledButton saveButton(WidgetTester tester) =>
      tester.widget<FilledButton>(find.byType(FilledButton).last);

  testWidgets('shows sale types with the default selected and Save disabled', (tester) async {
    await pumpView(tester);

    expect(find.widgetWithText(ChoiceChip, 'New Phone'), findsOneWidget);
    expect(find.widgetWithText(ChoiceChip, 'Exchange'), findsOneWidget);
    expect(
      tester.widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'New Phone')).selected,
      isTrue,
    );
    expect(find.text('Tap to choose product'), findsOneWidget);
    expect(saveButton(tester).onPressed, isNull);
  });

  testWidgets('a chosen product fills the price and enables Save', (tester) async {
    await pumpView(tester);

    cubit.selectProduct(phone);
    // The cubit delivers state asynchronously; settle so the screen rebuilds with it.
    await tester.pumpAndSettle();

    expect(find.text('Samsung A16'), findsOneWidget);
    expect(find.text('Save sale · ₹1,000'), findsOneWidget);
    expect(saveButton(tester).onPressed, isNotNull);
    expect(find.widgetWithText(TextField, '1000'), findsOneWidget);
  });

  testWidgets('saving shows the profit calculated by the server', (tester) async {
    await pumpView(tester);
    cubit.selectProduct(phone);
    // The cubit delivers state asynchronously; settle so the screen rebuilds with it.
    await tester.pumpAndSettle();

    await tester.tap(find.text('Save sale · ₹1,000'));
    await tester.pumpAndSettle();

    verify(() => sales.create(any())).called(1);
    expect(find.text('Sale saved'), findsOneWidget);
    expect(find.text('₹100'), findsOneWidget);
    expect(find.text('Add another sale'), findsOneWidget);
  });

  testWidgets('choosing an exchange sale type shows the old phone fields', (tester) async {
    await pumpView(tester);
    expect(find.text('Old phone'), findsNothing);

    await tester.tap(find.widgetWithText(ChoiceChip, 'Exchange'));
    await tester.pump();

    expect(find.text('Old phone'), findsOneWidget);
    expect(find.text('Exchange value'), findsOneWidget);
  });

  testWidgets('credit explains that the amount stays pending', (tester) async {
    await pumpView(tester);
    cubit.selectProduct(phone);
    // The cubit delivers state asynchronously; settle so the screen rebuilds with it.
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(ChoiceChip, 'Credit'));
    await tester.pump();

    expect(find.text('Choose the customer who will pay the rest'), findsOneWidget);
    expect(saveButton(tester).onPressed, isNull);
  });
}
