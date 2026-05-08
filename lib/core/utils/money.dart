import 'package:intl/intl.dart';

class Money {
  static final NumberFormat _trCurrency = NumberFormat.currency(
    locale: 'tr_TR',
    symbol: '₺',
    decimalDigits: 2,
  );

  /// Görsel format: 9.000,00 ₺
  static String format(num amount) => _trCurrency.format(amount);

  /// Kompakt format takvim/grafik gibi dar alanlar için:
  ///  - 950     → "950"
  ///  - 9500    → "9,5K"
  ///  - 1250000 → "1,3M"
  static String compact(num amount) {
    final v = amount.abs();
    if (v < 1000) return amount.toStringAsFixed(0);
    if (v < 1000000) {
      return '${(amount / 1000).toStringAsFixed(1).replaceAll('.', ',')}K';
    }
    return '${(amount / 1000000).toStringAsFixed(1).replaceAll('.', ',')}M';
  }

  /// TextField'a yazılacak düzenlenebilir metin.
  /// Binlik ayraç YOK — sadece rakam + (varsa) virgülle ondalık.
  /// Bu, parsing kırılganlığını ortadan kaldırır:
  ///  - 9000     → "9000"
  ///  - 9000.5   → "9000,5"
  ///  - 9000.50  → "9000,5"  (gereksiz sıfır temizlenir)
  ///  - 0        → ""
  static String forEdit(double value) {
    if (value == 0) return '';
    final isWhole = value == value.truncateToDouble();
    if (isWhole) return value.toStringAsFixed(0);
    // 2 hane ondalık, sondaki gereksiz sıfırları kırp
    var s = value.toStringAsFixed(2);
    while (s.endsWith('0')) {
      s = s.substring(0, s.length - 1);
    }
    if (s.endsWith('.')) s = s.substring(0, s.length - 1);
    return s.replaceAll('.', ',');
  }

  /// Türkçe input parser (binlik ayraç beklenmiyor):
  ///  - "9000"    → 9000
  ///  - "9000,5"  → 9000.5
  ///  - "9000.5"  → 9000.5  (yanlışlıkla nokta yazılırsa da çalışır)
  static double? tryParse(String input) {
    final s = input
        .replaceAll('₺', '')
        .replaceAll(' ', '')
        .replaceAll(',', '.')
        .trim();
    if (s.isEmpty) return null;
    return double.tryParse(s);
  }
}
