import 'package:mocktail/mocktail.dart';
import 'package:retail_shop/features/sales/data/sale_repository.dart';
import 'package:retail_shop/features/sales/data/sale_type_repository.dart';
import 'package:retail_shop/features/sales/domain/sale.dart';

class MockSaleTypeRepository extends Mock implements SaleTypeRepository {}

class MockSaleRepository extends Mock implements SaleRepository {}

void registerSaleFallbacks() {
  registerFallbackValue(
    const NewSale(saleTypeId: '', items: [], paymentMethod: PaymentMethod.cash, clientRef: ''),
  );
}
