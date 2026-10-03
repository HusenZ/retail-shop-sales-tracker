import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:retail_shop/core/api/api_exception.dart';
import 'package:retail_shop/features/sales/domain/sale.dart';
import 'package:retail_shop/features/sales/presentation/add_sale_cubit.dart';

import '../../helpers/fixtures.dart';
import '../../helpers/mocks.dart';

void main() {
  late MockSaleTypeRepository saleTypes;
  late MockSaleRepository sales;
  late List<String> refs;

  setUpAll(registerSaleFallbacks);

  setUp(() {
    saleTypes = MockSaleTypeRepository();
    sales = MockSaleRepository();
    refs = ['ref-1', 'ref-2', 'ref-3'];
    when(() => saleTypes.list()).thenAnswer((_) async => [newPhoneType, exchangeType]);
    when(() => sales.create(any())).thenAnswer((_) async => savedSale());
  });

  Future<AddSaleCubit> loadedCubit() async {
    final cubit = AddSaleCubit(saleTypes, sales, newClientRef: () => refs.removeAt(0));
    await cubit.load();
    return cubit;
  }

  NewSale sentSale() => verify(() => sales.create(captureAny())).captured.last as NewSale;

  blocTest<AddSaleCubit, AddSaleState>(
    'loading preselects the default sale type',
    build: () => AddSaleCubit(saleTypes, sales, newClientRef: () => 'ref-1'),
    act: (cubit) => cubit.load(),
    expect: () => [
      const AddSaleState(clientRef: 'ref-1'),
      const AddSaleState(
        clientRef: 'ref-1',
        status: AddSaleStatus.ready,
        saleTypes: [newPhoneType, exchangeType],
        saleType: newPhoneType,
      ),
    ],
  );

  test('a sale cannot be saved until a product is chosen', () async {
    final cubit = await loadedCubit();

    expect(cubit.state.problem, 'Choose a product');
    expect(cubit.state.canSave, isFalse);

    cubit.selectProduct(phone);

    expect(cubit.state.canSave, isTrue);
  });

  test('previews the total from price, quantity and discount', () async {
    final cubit = await loadedCubit()
      ..selectProduct(phone)
      ..increaseQuantity()
      ..setDiscount(money('100'));

    expect(cubit.state.price, money('1000'));
    expect(cubit.state.total, money('1900'));
    expect(cubit.state.customerPays, money('1900'));
  });

  test('sends a normal sale and keeps the server result', () async {
    final cubit = await loadedCubit()
      ..selectProduct(phone)
      ..setDiscount(money('100'))
      ..selectPaymentMethod(PaymentMethod.upi);

    await cubit.submit();

    final sent = sentSale();
    expect(sent.saleTypeId, newPhoneType.id);
    expect(sent.items, [NewSaleItem(productId: phone.id, quantity: 1)]);
    expect(sent.discount, money('100'));
    expect(sent.paymentMethod, PaymentMethod.upi);
    expect(sent.amountPaid, isNull);
    expect(sent.clientRef, 'ref-1');
    expect(sent.toJson()['items'], [
      {'product_id': phone.id, 'quantity': 1},
    ]);
    expect(cubit.state.status, AddSaleStatus.saved);
    expect(cubit.state.savedSale!.summary.profit, money('100'));
  });

  test('a changed price is sent; the usual price is not', () async {
    final cubit = await loadedCubit()
      ..selectProduct(phone)
      ..setUnitPrice(money('950'));

    await cubit.submit();

    expect(sentSale().items.single.unitPrice, money('950'));
  });

  test('retrying after a failure reuses the same client reference', () async {
    var attempts = 0;
    when(() => sales.create(any())).thenAnswer((_) async {
      attempts++;
      if (attempts == 1) throw const ApiException(ApiException.noConnectionMessage);
      return savedSale();
    });
    final cubit = await loadedCubit()
      ..selectProduct(phone);

    await cubit.submit();
    expect(cubit.state.status, AddSaleStatus.ready);
    expect(cubit.state.errorMessage, ApiException.noConnectionMessage);

    await cubit.submit();

    final sent = verify(() => sales.create(captureAny())).captured.cast<NewSale>();
    expect(sent.map((sale) => sale.clientRef), ['ref-1', 'ref-1']);
    expect(cubit.state.status, AddSaleStatus.saved);
  });

  test('starting a new sale clears the form but keeps the sale type', () async {
    final cubit = await loadedCubit()
      ..selectSaleType(exchangeType)
      ..selectProduct(phone);
    await cubit.submit();

    cubit.startNew();

    expect(cubit.state.clientRef, 'ref-2');
    expect(cubit.state.product, isNull);
    expect(cubit.state.saleType, exchangeType);
    expect(cubit.state.status, AddSaleStatus.ready);
  });

  test('more than the stock cannot be sold', () async {
    final cubit = await loadedCubit()
      ..selectProduct(phone)
      ..setQuantity(6);

    await cubit.submit();

    expect(cubit.state.problem, 'Only 5 in stock');
    verifyNever(() => sales.create(any()));
  });

  test('discount larger than the price is not allowed', () async {
    final cubit = await loadedCubit()
      ..selectProduct(phone)
      ..setDiscount(money('1001'));

    expect(cubit.state.problem, 'Discount is more than the price');
  });

  group('credit', () {
    test('needs a customer', () async {
      final cubit = await loadedCubit()
        ..selectProduct(phone)
        ..selectPaymentMethod(PaymentMethod.credit);

      expect(cubit.state.pendingAmount, money('1000'));
      expect(cubit.state.problem, 'Choose the customer who will pay the rest');

      cubit.selectCustomer(rahul);
      await cubit.submit();

      final sent = sentSale();
      expect(sent.paymentMethod, PaymentMethod.credit);
      expect(sent.customerId, rahul.id);
      expect(sent.amountPaid, isNull);
    });

    test('part payment sends the amount paid now', () async {
      final cubit = await loadedCubit()
        ..selectProduct(phone)
        ..setPartPayment(true)
        ..setAmountPaid(money('600'))
        ..selectCustomer(rahul);

      expect(cubit.state.pendingAmount, money('400'));
      await cubit.submit();

      expect(sentSale().amountPaid, money('600'));
    });

    test('paying more than the total is not allowed', () async {
      final cubit = await loadedCubit()
        ..selectProduct(phone)
        ..setPartPayment(true)
        ..setAmountPaid(money('1500'));

      expect(cubit.state.problem, 'Amount paid is more than the total');
    });
  });

  group('exchange', () {
    test('asks for the old phone details', () async {
      final cubit = await loadedCubit()
        ..selectSaleType(exchangeType)
        ..selectProduct(phone);

      expect(cubit.state.problem, 'Enter the old phone model');

      cubit.setExchangeDeviceName('Redmi Note 10');
      expect(cubit.state.problem, 'Enter the old phone value');
    });

    test('old phone value reduces what the customer pays', () async {
      final cubit = await loadedCubit()
        ..selectSaleType(exchangeType)
        ..selectProduct(phone)
        ..setExchangeDeviceName(' Redmi Note 10 ')
        ..setExchangeValue(money('300'));

      expect(cubit.state.total, money('1000'));
      expect(cubit.state.customerPays, money('700'));

      await cubit.submit();

      expect(
        sentSale().exchange,
        ExchangeDetails(deviceName: 'Redmi Note 10', value: money('300')),
      );
    });

    test('details are ignored for a normal sale type', () async {
      final cubit = await loadedCubit()
        ..selectProduct(phone)
        ..setExchangeValue(money('300'));

      expect(cubit.state.customerPays, money('1000'));
      await cubit.submit();

      expect(sentSale().exchange, isNull);
    });
  });
}
