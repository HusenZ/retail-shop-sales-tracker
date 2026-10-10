import 'package:decimal/decimal.dart';
import 'package:retail_shop/features/customers/domain/customer.dart';
import 'package:retail_shop/features/products/domain/product.dart';
import 'package:retail_shop/features/sales/domain/sale.dart';
import 'package:retail_shop/features/sales/domain/sale_type.dart';

Decimal money(String value) => Decimal.parse(value);

const newPhoneType = SaleType(
  id: 'type-new',
  name: 'New Phone',
  isActive: true,
  isDefault: true,
  isExchange: false,
);

const exchangeType = SaleType(
  id: 'type-exchange',
  name: 'Exchange',
  isActive: true,
  isDefault: false,
  isExchange: true,
);

final phone = Product(
  id: 'product-phone',
  name: 'Samsung A16',
  categoryId: 'category-phones',
  purchasePrice: money('800'),
  sellingPrice: money('1000'),
  trackStock: true,
  stockQty: 5,
  lowStockThreshold: 2,
  stockStatus: StockStatus.inStock,
  isActive: true,
);

final rahul = Customer(
  id: 'customer-rahul',
  name: 'Rahul',
  totalPurchases: money('0'),
  transactionCount: 0,
  pendingAmount: money('0'),
);

/// What the server returns after saving a ₹1000 phone sale with a ₹100 discount.
SaleDetail savedSale({String pending = '0'}) => SaleDetail(
      summary: SaleSummary(
        id: 'sale-1',
        soldAt: DateTime.utc(2026, 9, 16, 6, 30),
        saleTypeId: newPhoneType.id,
        saleTypeName: newPhoneType.name,
        productNames: const ['Samsung A16'],
        paymentMethod: PaymentMethod.cash,
        total: money('900'),
        profit: money('100'),
        amountDue: money('900'),
        amountPaid: money('900') - money(pending),
        pendingAmount: money(pending),
      ),
      subtotal: money('1000'),
      discount: money('100'),
      totalCost: money('800'),
      exchangeValue: money('0'),
      items: const [],
      payments: const [],
    );
