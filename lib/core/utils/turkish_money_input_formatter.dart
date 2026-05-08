import 'package:flutter/services.dart';

/// Para input'u için: yalnızca rakam ve tek virgül kabul et,
/// virgülden sonra en fazla 2 hane. Nokta yazılmasını engelle (binlik
/// ayracı kullanıcıya bırakmıyoruz; sayı sayı olarak kalsın, çorba olmasın).
class TurkishMoneyInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final raw = newValue.text;
    if (raw.isEmpty) return newValue;

    // Sadece rakam ve virgül
    final filtered = StringBuffer();
    var commaSeen = false;
    var afterComma = 0;
    for (final ch in raw.runes) {
      final c = String.fromCharCode(ch);
      if (RegExp(r'[0-9]').hasMatch(c)) {
        if (commaSeen) {
          if (afterComma >= 2) continue;
          afterComma++;
        }
        filtered.write(c);
      } else if (c == ',' && !commaSeen) {
        commaSeen = true;
        filtered.write(c);
      }
      // Diğer her şey (nokta dahil) düşürülür.
    }

    final result = filtered.toString();
    if (result == raw) return newValue;
    return TextEditingValue(
      text: result,
      selection: TextSelection.collapsed(offset: result.length),
    );
  }
}
