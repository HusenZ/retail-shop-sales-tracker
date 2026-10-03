import 'package:flutter_test/flutter_test.dart';
import 'package:retail_shop/core/api/api_exception.dart';

void main() {
  test('reads a business error message', () {
    expect(
      ApiException.messageFromBody({'detail': 'Only 1 of "Samsung A16" in stock'}),
      'Only 1 of "Samsung A16" in stock',
    );
  });

  test('reads the first validation error without the Pydantic prefix', () {
    final body = {
      'detail': [
        {
          'msg': 'Value error, Each product can appear only once',
          'loc': ['body', 'items']
        },
      ],
    };

    expect(ApiException.messageFromBody(body), 'Each product can appear only once');
  });

  test('returns null for unexpected bodies', () {
    expect(ApiException.messageFromBody('<html>'), isNull);
    expect(ApiException.messageFromBody({'detail': <Object>[]}), isNull);
  });
}
