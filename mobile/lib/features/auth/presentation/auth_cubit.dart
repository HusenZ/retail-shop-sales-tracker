import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/api/api_exception.dart';
import '../../shop/data/shop_repository.dart';
import '../../shop/domain/shop.dart';
import '../data/auth_repository.dart';
import '../domain/user.dart';

enum AuthStatus { unknown, unauthenticated, needsShop, authenticated }

class AuthState extends Equatable {
  const AuthState({
    this.status = AuthStatus.unknown,
    this.user,
    this.shop,
    this.isSubmitting = false,
    this.errorMessage,
  });

  final AuthStatus status;
  final User? user;
  final Shop? shop;
  final bool isSubmitting;
  final String? errorMessage;

  AuthState submitting() =>
      AuthState(status: status, user: user, shop: shop, isSubmitting: true);

  AuthState failed(String message) =>
      AuthState(status: status, user: user, shop: shop, errorMessage: message);

  @override
  List<Object?> get props => [status, user, shop, isSubmitting, errorMessage];
}

/// The app-wide session: who is logged in and whether their shop exists.
/// The router decides which screens are reachable from [AuthState.status].
class AuthCubit extends Cubit<AuthState> {
  AuthCubit(this._auth, this._shops) : super(const AuthState());

  final AuthRepository _auth;
  final ShopRepository _shops;

  Future<void> restoreSession() async {
    if (!await _auth.hasSavedSession()) {
      emit(const AuthState(status: AuthStatus.unauthenticated));
      return;
    }
    emit(const AuthState(isSubmitting: true));
    try {
      await _signedIn(await _auth.currentUser());
    } on ApiException catch (error) {
      if (error.isUnauthorized) {
        await logout();
      } else {
        // Keep the saved login; the splash screen offers a retry.
        emit(AuthState(errorMessage: error.message));
      }
    }
  }

  Future<void> login({required String email, required String password}) =>
      _submit(() => _auth.login(email: email.trim(), password: password));

  Future<void> register({
    required String fullName,
    required String email,
    required String password,
  }) =>
      _submit(
        () => _auth.register(fullName: fullName.trim(), email: email.trim(), password: password),
      );

  Future<void> createShop(ShopInput input) async {
    emit(state.submitting());
    try {
      final shop = await _shops.createShop(input);
      emit(AuthState(status: AuthStatus.authenticated, user: state.user, shop: shop));
    } on ApiException catch (error) {
      emit(state.failed(error.message));
    }
  }

  /// Returns true when saved, so the edit screen can close itself.
  Future<bool> updateShop(ShopInput input) async {
    emit(state.submitting());
    try {
      final shop = await _shops.updateShop(input);
      emit(AuthState(status: state.status, user: state.user, shop: shop));
      return true;
    } on ApiException catch (error) {
      emit(state.failed(error.message));
      return false;
    }
  }

  Future<void> logout() async {
    await _auth.logout();
    emit(const AuthState(status: AuthStatus.unauthenticated));
  }

  /// The server rejected the saved token, e.g. after it expired.
  void sessionExpired() {
    if (state.status != AuthStatus.unauthenticated) unawaited(logout());
  }

  Future<void> _submit(Future<User> Function() authenticate) async {
    emit(state.submitting());
    try {
      await _signedIn(await authenticate());
    } on ApiException catch (error) {
      emit(state.failed(error.message));
    }
  }

  Future<void> _signedIn(User user) async {
    final shop = await _shops.getShop();
    emit(
      AuthState(
        status: shop == null ? AuthStatus.needsShop : AuthStatus.authenticated,
        user: user,
        shop: shop,
      ),
    );
  }
}
