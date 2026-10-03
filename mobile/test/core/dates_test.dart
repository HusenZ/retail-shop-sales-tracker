import 'package:flutter_test/flutter_test.dart';
import 'package:retail_shop/core/format/dates.dart';

void main() {
  test('weeks start on Monday', () {
    expect(startOfWeek(DateTime(2026, 9, 16)), DateTime(2026, 9, 14)); // Wednesday
    expect(startOfWeek(DateTime(2026, 9, 14)), DateTime(2026, 9, 14)); // Monday
    expect(startOfWeek(DateTime(2026, 9, 20)), DateTime(2026, 9, 14)); // Sunday
  });

  test('day headings', () {
    final now = DateTime(2026, 9, 16, 10);

    expect(formatDayHeading(DateTime(2026, 9, 16, 9), now: now), 'Today');
    expect(formatDayHeading(DateTime(2026, 9, 15, 23), now: now), 'Yesterday');
    expect(formatDayHeading(DateTime(2026, 9, 2, 12), now: now), '2 Sep 2026');
  });

  test('api dates', () {
    expect(apiDate(DateTime(2026, 9, 1)), '2026-09-01');
  });
}
