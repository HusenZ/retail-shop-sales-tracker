import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/auth_cubit.dart';
import '../../features/auth/presentation/login_page.dart';
import '../../features/auth/presentation/register_page.dart';
import '../../features/auth/presentation/splash_page.dart';
import '../../features/customers/presentation/customer_detail_page.dart';
import '../../features/customers/presentation/customer_list_page.dart';
import '../../features/dashboard/presentation/dashboard_page.dart';
import '../../features/expenses/presentation/expenses_page.dart';
import '../../features/products/presentation/categories_page.dart';
import '../../features/products/presentation/product_form_page.dart';
import '../../features/products/presentation/product_list_page.dart';
import '../../features/reports/presentation/reports_page.dart';
import '../../features/sales/presentation/add_sale_page.dart';
import '../../features/sales/presentation/sale_detail_page.dart';
import '../../features/sales/presentation/sale_list_page.dart';
import '../../features/sales/presentation/sale_types_page.dart';
import '../../features/settings/presentation/settings_page.dart';
import '../../features/shop/presentation/shop_form_page.dart';
import 'home_shell.dart';

const _authPages = {'/login', '/register'};

GoRouter createRouter(AuthCubit authCubit) {
  return GoRouter(
    initialLocation: '/dashboard',
    refreshListenable: _StatusListenable(authCubit),
    redirect: (context, state) => _redirect(authCubit.state.status, state.matchedLocation),
    routes: [
      GoRoute(path: '/splash', builder: (_, __) => const SplashPage()),
      GoRoute(path: '/login', builder: (_, __) => const LoginPage()),
      GoRoute(path: '/register', builder: (_, __) => const RegisterPage()),
      GoRoute(path: '/shop-setup', builder: (_, __) => const ShopFormPage()),
      StatefulShellRoute.indexedStack(
        builder: (_, __, shell) => HomeShell(shell: shell),
        branches: [
          _tab('/dashboard', const DashboardPage()),
          _tab('/sales', const SaleListPage()),
          _tab('/products', const ProductListPage()),
          _tab('/reports', const ReportsPage()),
          _tab('/settings', const SettingsPage()),
        ],
      ),
      // Full-screen pages opened on top of the tabs. "new" routes come before the
      // ":id" routes so they are not read as an id.
      GoRoute(path: '/sales/new', builder: (_, __) => const AddSalePage()),
      GoRoute(
        path: '/sales/:saleId',
        builder: (_, state) => SaleDetailPage(saleId: state.pathParameters['saleId']!),
      ),
      GoRoute(path: '/products/new', builder: (_, __) => const ProductFormPage()),
      GoRoute(
        path: '/products/:productId',
        builder: (_, state) => ProductFormPage(productId: state.pathParameters['productId']),
      ),
      GoRoute(
        path: '/customers',
        builder: (_, state) =>
            CustomerListPage(pendingOnly: state.uri.queryParameters['pending'] == 'true'),
      ),
      GoRoute(
        path: '/customers/:customerId',
        builder: (_, state) => CustomerDetailPage(customerId: state.pathParameters['customerId']!),
      ),
      GoRoute(
        path: '/settings/shop',
        builder: (context, __) => ShopFormPage(shop: context.read<AuthCubit>().state.shop),
      ),
      GoRoute(path: '/settings/categories', builder: (_, __) => const CategoriesPage()),
      GoRoute(path: '/settings/sale-types', builder: (_, __) => const SaleTypesPage()),
      GoRoute(path: '/expenses', builder: (_, __) => const ExpensesPage()),
    ],
  );
}

StatefulShellBranch _tab(String path, Widget page) => StatefulShellBranch(
      routes: [GoRoute(path: path, builder: (_, __) => page)],
    );

/// Sends the user to the one place their session allows.
String? _redirect(AuthStatus status, String location) {
  return switch (status) {
    AuthStatus.unknown => location == '/splash' ? null : '/splash',
    AuthStatus.unauthenticated => _authPages.contains(location) ? null : '/login',
    AuthStatus.needsShop => location == '/shop-setup' ? null : '/shop-setup',
    AuthStatus.authenticated =>
      _authPages.contains(location) || location == '/splash' || location == '/shop-setup'
          ? '/dashboard'
          : null,
  };
}

/// Re-runs the redirect only when the session status changes, not on every form update.
class _StatusListenable extends ChangeNotifier {
  _StatusListenable(AuthCubit cubit) {
    _subscription =
        cubit.stream.map((state) => state.status).distinct().listen((_) => notifyListeners());
  }

  late final StreamSubscription<AuthStatus> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
