import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:retail_shop/core/api/api_exception.dart';
import 'package:retail_shop/features/auth/data/auth_repository.dart';
import 'package:retail_shop/features/auth/domain/user.dart';
import 'package:retail_shop/features/auth/presentation/auth_cubit.dart';
import 'package:retail_shop/features/shop/data/shop_repository.dart';
import 'package:retail_shop/features/shop/domain/shop.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

class MockShopRepository extends Mock implements ShopRepository {}

void main() {
  late MockAuthRepository auth;
  late MockShopRepository shops;

  const user = User(id: 'user-1', email: 'ravi@example.com', fullName: 'Ravi');
  const shop = Shop(id: 'shop-1', name: 'Ravi Mobiles', ownerName: 'Ravi', phone: '9876543210');
  const shopInput = ShopInput(name: 'Ravi Mobiles', ownerName: 'Ravi', phone: '9876543210');

  setUpAll(() => registerFallbackValue(shopInput));

  setUp(() {
    auth = MockAuthRepository();
    shops = MockShopRepository();
    when(() => auth.logout()).thenAnswer((_) async {});
  });

  void loginReturns(User result) {
    when(() => auth.login(email: any(named: 'email'), password: any(named: 'password')))
        .thenAnswer((_) async => result);
  }

  blocTest<AuthCubit, AuthState>(
    'login with an existing shop opens the app',
    setUp: () {
      loginReturns(user);
      when(() => shops.getShop()).thenAnswer((_) async => shop);
    },
    build: () => AuthCubit(auth, shops),
    act: (cubit) => cubit.login(email: ' ravi@example.com ', password: 'secret-password'),
    expect: () => [
      const AuthState(isSubmitting: true),
      const AuthState(status: AuthStatus.authenticated, user: user, shop: shop),
    ],
    verify: (_) => verify(
      () => auth.login(email: 'ravi@example.com', password: 'secret-password'),
    ).called(1),
  );

  blocTest<AuthCubit, AuthState>(
    'login without a shop asks for shop setup',
    setUp: () {
      loginReturns(user);
      when(() => shops.getShop()).thenAnswer((_) async => null);
    },
    build: () => AuthCubit(auth, shops),
    act: (cubit) => cubit.login(email: 'ravi@example.com', password: 'secret-password'),
    expect: () => [
      const AuthState(isSubmitting: true),
      const AuthState(status: AuthStatus.needsShop, user: user),
    ],
  );

  blocTest<AuthCubit, AuthState>(
    'wrong password shows the server message',
    setUp: () {
      when(() => auth.login(email: any(named: 'email'), password: any(named: 'password')))
          .thenThrow(const ApiException('Wrong email or password', statusCode: 401));
    },
    build: () => AuthCubit(auth, shops),
    act: (cubit) => cubit.login(email: 'ravi@example.com', password: 'nope'),
    expect: () => [
      const AuthState(isSubmitting: true),
      const AuthState(errorMessage: 'Wrong email or password'),
    ],
  );

  blocTest<AuthCubit, AuthState>(
    'no saved login goes to the login screen',
    setUp: () => when(() => auth.hasSavedSession()).thenAnswer((_) async => false),
    build: () => AuthCubit(auth, shops),
    act: (cubit) => cubit.restoreSession(),
    expect: () => [const AuthState(status: AuthStatus.unauthenticated)],
  );

  blocTest<AuthCubit, AuthState>(
    'an expired saved login is cleared',
    setUp: () {
      when(() => auth.hasSavedSession()).thenAnswer((_) async => true);
      when(() => auth.currentUser())
          .thenThrow(const ApiException('Not logged in', statusCode: 401));
    },
    build: () => AuthCubit(auth, shops),
    act: (cubit) => cubit.restoreSession(),
    expect: () => [
      const AuthState(isSubmitting: true),
      const AuthState(status: AuthStatus.unauthenticated),
    ],
    verify: (_) => verify(() => auth.logout()).called(1),
  );

  blocTest<AuthCubit, AuthState>(
    'no internet at start keeps the saved login and offers a retry',
    setUp: () {
      when(() => auth.hasSavedSession()).thenAnswer((_) async => true);
      when(() => auth.currentUser())
          .thenThrow(const ApiException(ApiException.noConnectionMessage));
    },
    build: () => AuthCubit(auth, shops),
    act: (cubit) => cubit.restoreSession(),
    expect: () => [
      const AuthState(isSubmitting: true),
      const AuthState(errorMessage: ApiException.noConnectionMessage),
    ],
    verify: (_) => verifyNever(() => auth.logout()),
  );

  blocTest<AuthCubit, AuthState>(
    'creating the shop opens the app',
    setUp: () => when(() => shops.createShop(any())).thenAnswer((_) async => shop),
    build: () => AuthCubit(auth, shops),
    seed: () => const AuthState(status: AuthStatus.needsShop, user: user),
    act: (cubit) => cubit.createShop(shopInput),
    expect: () => [
      const AuthState(status: AuthStatus.needsShop, user: user, isSubmitting: true),
      const AuthState(status: AuthStatus.authenticated, user: user, shop: shop),
    ],
  );

  blocTest<AuthCubit, AuthState>(
    'logout forgets the session',
    build: () => AuthCubit(auth, shops),
    seed: () => const AuthState(status: AuthStatus.authenticated, user: user, shop: shop),
    act: (cubit) => cubit.logout(),
    expect: () => [const AuthState(status: AuthStatus.unauthenticated)],
  );
}
