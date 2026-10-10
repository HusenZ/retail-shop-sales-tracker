import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'core/api/api_client.dart';
import 'core/router/app_router.dart';
import 'core/storage/token_storage.dart';
import 'core/theme.dart';
import 'features/auth/data/auth_repository.dart';
import 'features/auth/presentation/auth_cubit.dart';
import 'features/customers/data/customer_repository.dart';
import 'features/dashboard/data/dashboard_repository.dart';
import 'features/expenses/data/expense_repository.dart';
import 'features/products/data/category_repository.dart';
import 'features/products/data/product_repository.dart';
import 'features/reports/data/report_repository.dart';
import 'features/sales/data/sale_repository.dart';
import 'features/sales/data/sale_type_repository.dart';
import 'features/shop/data/shop_repository.dart';

/// Every repository, created once and shared by all screens.
class AppDependencies {
  AppDependencies({required String apiBaseUrl}) {
    final tokens = TokenStorage();
    api = ApiClient(baseUrl: apiBaseUrl, tokenStorage: tokens);
    auth = AuthRepository(api, tokens);
    shop = ShopRepository(api);
    categories = CategoryRepository(api);
    saleTypes = SaleTypeRepository(api);
    products = ProductRepository(api);
    customers = CustomerRepository(api);
    sales = SaleRepository(api);
    expenses = ExpenseRepository(api);
    dashboard = DashboardRepository(api);
    reports = ReportRepository(api);
  }

  late final ApiClient api;
  late final AuthRepository auth;
  late final ShopRepository shop;
  late final CategoryRepository categories;
  late final SaleTypeRepository saleTypes;
  late final ProductRepository products;
  late final CustomerRepository customers;
  late final SaleRepository sales;
  late final ExpenseRepository expenses;
  late final DashboardRepository dashboard;
  late final ReportRepository reports;
}

class RetailShopApp extends StatefulWidget {
  const RetailShopApp({required this.dependencies, super.key});

  final AppDependencies dependencies;

  @override
  State<RetailShopApp> createState() => _RetailShopAppState();
}

class _RetailShopAppState extends State<RetailShopApp> {
  late final AuthCubit _authCubit;
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    final deps = widget.dependencies;
    _authCubit = AuthCubit(deps.auth, deps.shop)..restoreSession();
    deps.api.onUnauthorized = _authCubit.sessionExpired;
    _router = createRouter(_authCubit);
  }

  @override
  void dispose() {
    _router.dispose();
    _authCubit.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final deps = widget.dependencies;
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider.value(value: deps.auth),
        RepositoryProvider.value(value: deps.shop),
        RepositoryProvider.value(value: deps.categories),
        RepositoryProvider.value(value: deps.saleTypes),
        RepositoryProvider.value(value: deps.products),
        RepositoryProvider.value(value: deps.customers),
        RepositoryProvider.value(value: deps.sales),
        RepositoryProvider.value(value: deps.expenses),
        RepositoryProvider.value(value: deps.dashboard),
        RepositoryProvider.value(value: deps.reports),
      ],
      child: BlocProvider.value(
        value: _authCubit,
        child: MaterialApp.router(
          title: 'Shop Sales',
          theme: buildTheme(),
          routerConfig: _router,
          debugShowCheckedModeBanner: false,
        ),
      ),
    );
  }
}
