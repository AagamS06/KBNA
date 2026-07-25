import 'package:intl/intl.dart';

/// AUD money from integer cents, e.g. 1450 -> "$14.50". Mirrors the website's
/// `money()` helper.
String money(int cents) => '\$${(cents / 100).toStringAsFixed(2)}';

/// A relative, plain-English timestamp for order rows: "Today, 9:14 am",
/// "Yesterday, 4:02 pm", else "Tue 22 Jul, 11:31 am". en-AU, lower-case am/pm.
String relativeTimestamp(DateTime when) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final that = DateTime(when.year, when.month, when.day);
  final diffDays = today.difference(that).inDays;

  final time = DateFormat('h:mm a').format(when).toLowerCase();
  if (diffDays == 0) return 'Today, $time';
  if (diffDays == 1) return 'Yesterday, $time';
  return '${DateFormat('EEE d MMM').format(when)}, $time';
}

/// "Thursday 24 July" — the Today screen subtitle.
String longDate(DateTime when) => DateFormat('EEEE d MMMM').format(when);

/// "Thursday 24 July, 9:14 am" — the order detail heading.
String longDateTime(DateTime when) =>
    '${DateFormat('EEEE d MMMM').format(when)}, '
    '${DateFormat('h:mm a').format(when).toLowerCase()}';

/// Which day-group an order belongs to in the Orders list.
String orderGroup(DateTime when) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final that = DateTime(when.year, when.month, when.day);
  final diff = today.difference(that).inDays;
  if (diff == 0) return 'TODAY';
  if (diff == 1) return 'YESTERDAY';
  return 'EARLIER';
}
