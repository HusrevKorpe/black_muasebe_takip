import 'package:intl/intl.dart';

class DateKeys {
  static final DateFormat _key = DateFormat('yyyy-MM-dd');
  static final DateFormat _human = DateFormat('d MMMM yyyy', 'tr_TR');
  static final DateFormat _short = DateFormat('d MMM', 'tr_TR');

  static String key(DateTime d) => _key.format(d);
  static String human(DateTime d) => _human.format(d);
  static String short(DateTime d) => _short.format(d);

  static DateTime today() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }
}
