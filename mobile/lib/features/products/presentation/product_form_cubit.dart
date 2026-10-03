import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/load_status.dart';
import '../data/category_repository.dart';
import '../data/product_repository.dart';
import '../domain/category.dart';
import '../domain/product.dart';

class ProductFormState extends Equatable {
  const ProductFormState({
    this.status = LoadStatus.initial,
    this.categories = const [],
    this.product,
    this.isSaving = false,
    this.isSaved = false,
    this.errorMessage,
  });

  final LoadStatus status;
  final List<Category> categories;

  /// The product being edited; null when adding a new one.
  final Product? product;
  final bool isSaving;
  final bool isSaved;
  final String? errorMessage;

  ProductFormState copyWith({
    LoadStatus? status,
    List<Category>? categories,
    Product? product,
    bool? isSaving,
    bool? isSaved,
    String? errorMessage,
  }) =>
      ProductFormState(
        status: status ?? this.status,
        categories: categories ?? this.categories,
        product: product ?? this.product,
        isSaving: isSaving ?? this.isSaving,
        isSaved: isSaved ?? this.isSaved,
        errorMessage: errorMessage,
      );

  @override
  List<Object?> get props => [status, categories, product, isSaving, isSaved, errorMessage];
}

class ProductFormCubit extends Cubit<ProductFormState> {
  ProductFormCubit(this._products, this._categories, {this.productId})
      : super(const ProductFormState());

  final ProductRepository _products;
  final CategoryRepository _categories;
  final String? productId;

  Future<void> load() async {
    emit(state.copyWith(status: LoadStatus.loading));
    try {
      final product = productId == null ? null : await _products.get(productId!);
      final categories = await _categories.list(includeInactive: true);
      emit(
        state.copyWith(
          status: LoadStatus.success,
          product: product,
          // A disabled category stays selectable only for products already in it.
          categories: categories
              .where((category) => category.isActive || category.id == product?.categoryId)
              .toList(),
        ),
      );
    } on ApiException catch (error) {
      emit(state.copyWith(status: LoadStatus.failure, errorMessage: error.message));
    }
  }

  Future<void> save(ProductInput input) async {
    emit(state.copyWith(isSaving: true));
    try {
      final product = productId == null
          ? await _products.create(input)
          : await _products.update(productId!, input);
      emit(state.copyWith(isSaving: false, isSaved: true, product: product));
    } on ApiException catch (error) {
      emit(state.copyWith(isSaving: false, errorMessage: error.message));
    }
  }

  Future<void> adjustStock(int change) async {
    emit(state.copyWith(isSaving: true));
    try {
      final product = await _products.adjustStock(productId!, change);
      emit(state.copyWith(isSaving: false, product: product));
    } on ApiException catch (error) {
      emit(state.copyWith(isSaving: false, errorMessage: error.message));
    }
  }
}
