import 'package:decimal/decimal.dart';
import 'package:equatable/equatable.dart';

import '../../../core/api/api_client.dart';
import '../../../core/format/money.dart';

enum StockStatus {
  inStock('in_stock', 'In stock'),
  low('low', 'Low stock'),
  out('out', 'Out of stock'),
  notTracked('not_tracked', 'Not tracked');

  const StockStatus(this.apiValue, this.label);

  final String apiValue;
  final String label;

  static StockStatus fromApi(String value) =>
      values.firstWhere((status) => status.apiValue == value);
}

class Product extends Equatable {
  const Product({
    required this.id,
    required this.name,
    required this.categoryId,
    required this.purchasePrice,
    required this.sellingPrice,
    required this.trackStock,
    required this.stockQty,
    required this.lowStockThreshold,
    required this.stockStatus,
    required this.isActive,
    this.brand,
    this.model,
    this.sku,
    this.imei,
  });

  factory Product.fromJson(Json json) => Product(
        id: json['id'] as String,
        name: json['name'] as String,
        categoryId: json['category_id'] as String,
        purchasePrice: parseMoney(json['purchase_price']),
        sellingPrice: parseMoney(json['selling_price']),
        trackStock: json['track_stock'] as bool,
        stockQty: json['stock_qty'] as int,
        lowStockThreshold: json['low_stock_threshold'] as int,
        stockStatus: StockStatus.fromApi(json['stock_status'] as String),
        isActive: json['is_active'] as bool,
        brand: json['brand'] as String?,
        model: json['model'] as String?,
        sku: json['sku'] as String?,
        imei: json['imei'] as String?,
      );

  final String id;
  final String name;
  final String categoryId;
  final Decimal purchasePrice;
  final Decimal sellingPrice;
  final bool trackStock;
  final int stockQty;
  final int lowStockThreshold;
  final StockStatus stockStatus;
  final bool isActive;
  final String? brand;
  final String? model;
  final String? sku;
  final String? imei;

  bool get canBeSold => isActive && stockStatus != StockStatus.out;

  String get stockLabel => switch (stockStatus) {
        StockStatus.notTracked => 'Stock not tracked',
        StockStatus.out => 'Out of stock',
        _ => '$stockQty in stock',
      };

  @override
  List<Object?> get props => [
        id,
        name,
        categoryId,
        purchasePrice,
        sellingPrice,
        trackStock,
        stockQty,
        lowStockThreshold,
        stockStatus,
        isActive,
        brand,
        model,
        sku,
        imei,
      ];
}

/// Fields the shopkeeper edits. Stock is set only when creating; later changes go
/// through stock adjustments so they cannot overwrite a sale's stock change.
class ProductInput {
  const ProductInput({
    required this.name,
    required this.categoryId,
    required this.purchasePrice,
    required this.sellingPrice,
    required this.trackStock,
    required this.lowStockThreshold,
    this.initialStock = 0,
    this.isActive = true,
    this.brand,
    this.model,
    this.sku,
    this.imei,
  });

  final String name;
  final String categoryId;
  final Decimal purchasePrice;
  final Decimal sellingPrice;
  final bool trackStock;
  final int lowStockThreshold;
  final int initialStock;
  final bool isActive;
  final String? brand;
  final String? model;
  final String? sku;
  final String? imei;

  Json toCreateJson() => {..._commonJson(), 'stock_qty': initialStock};

  Json toUpdateJson() => {..._commonJson(), 'is_active': isActive};

  Json _commonJson() => {
        'name': name,
        'category_id': categoryId,
        'purchase_price': purchasePrice.toString(),
        'selling_price': sellingPrice.toString(),
        'track_stock': trackStock,
        'low_stock_threshold': lowStockThreshold,
        'brand': brand,
        'model': model,
        'sku': sku,
        'imei': imei,
      };
}
