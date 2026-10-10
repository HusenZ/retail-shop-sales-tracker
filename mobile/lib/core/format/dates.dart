import 'package:intl/intl.dart';

final _day = DateFormat('d MMM yyyy');
final _time = DateFormat('h:mm a');
final _apiDate = DateFormat('yyyy-MM-dd');

String formatDate(DateTime moment) => _day.format(moment.toLocal());

String formatTime(DateTime moment) => _time.format(moment.toLocal());

String formatDateTime(DateTime moment) => '${formatDate(moment)}, ${formatTime(moment)}';

/// "Today", "Yesterday" or a date — used for sale history headings.
String formatDayHeading(DateTime moment, {DateTime? now}) {
  final local = dateOnly(moment.toLocal());
  final today = dateOnly(now ?? DateTime.now());
  final difference = today.difference(local).inDays;
  if (difference == 0) return 'Today';
  if (difference == 1) return 'Yesterday';
  return _day.format(local);
}

String apiDate(DateTime day) => _apiDate.format(day);

DateTime dateOnly(DateTime moment) => DateTime(moment.year, moment.month, moment.day);

/// Weeks start on Monday, matching the backend.
DateTime startOfWeek(DateTime day) => dateOnly(day).subtract(Duration(days: day.weekday - 1));

DateTime startOfMonth(DateTime day) => DateTime(day.year, day.month);
