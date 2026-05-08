import 'dart:io';

import 'package:excel/excel.dart';
import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../logic/monthly_report.dart';

class ExcelExportService {
  static const _trMonths = [
    'Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran',
    'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık',
  ];

  /// Aylık raporu xlsx dosyası olarak üretir, dosya yolunu döner.
  static Future<File> generate(MonthlyReport report) async {
    final excel = Excel.createExcel();

    _buildSummarySheet(excel, report);
    _buildSharesSheet(excel, report);
    _buildRevenueSheet(excel, report);
    _buildExpenseSheet(excel, report);

    // Default 'Sheet1' sayfasını sil
    if (excel.sheets.containsKey('Sheet1')) {
      excel.delete('Sheet1');
    }

    final bytes = excel.save();
    if (bytes == null) {
      throw Exception('Excel dosyası üretilemedi');
    }

    final dir = await getTemporaryDirectory();
    final monthStr = report.month.toString().padLeft(2, '0');
    final safeName = _sanitizeFileName(report.shopName);
    final fileName = 'Muasebe_${safeName}_${report.year}-$monthStr.xlsx';
    final file = File('${dir.path}/$fileName');
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  /// Üretilmiş dosyayı paylaşma menüsüyle paylaşır.
  static Future<void> share(File file, BuildContext context) async {
    final box = context.findRenderObject() as RenderBox?;
    final origin = box != null
        ? box.localToGlobal(Offset.zero) & box.size
        : null;
    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet')],
      subject: 'Aylık Rapor',
      sharePositionOrigin: origin,
    );
  }

  // ---------- sheet builders ----------

  static void _buildSummarySheet(Excel excel, MonthlyReport r) {
    final s = excel['Özet'];
    s.setColumnWidth(0, 22);
    s.setColumnWidth(1, 18);

    var row = 0;
    _setText(s, row, 0, 'Aylık Rapor', style: _titleStyle());
    s.merge(
      CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row),
      CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row),
    );
    row += 2;

    _setText(s, row, 0, 'Dükkan');
    _setText(s, row, 1, r.shopName, style: _boldStyle());
    row += 1;
    _setText(s, row, 0, 'Ay');
    _setText(s, row, 1, '${_trMonths[r.month - 1]} ${r.year}', style: _boldStyle());
    row += 2;

    _setText(s, row, 0, 'Gelir', style: _sectionStyle());
    row += 1;
    _setText(s, row, 0, 'Toplam Nakit');
    _setMoney(s, row, 1, r.totalCash);
    row += 1;
    _setText(s, row, 0, 'Toplam Kart');
    _setMoney(s, row, 1, r.totalCard);
    row += 1;
    _setText(s, row, 0, 'Toplam Ciro', style: _boldStyle());
    _setMoney(s, row, 1, r.totalRevenue, bold: true);
    row += 2;

    _setText(s, row, 0, 'Gider', style: _sectionStyle());
    row += 1;
    _setText(s, row, 0, 'Toplam Gider', style: _boldStyle());
    _setMoney(s, row, 1, r.totalExpense, bold: true);
    row += 2;

    _setText(s, row, 0, r.isLoss ? 'Net Zarar' : 'Net Kâr', style: _sectionStyle());
    _setMoney(s, row, 1, r.netProfit, bold: true);
  }

  static void _buildSharesSheet(Excel excel, MonthlyReport r) {
    final s = excel['Ortaklık Dağılımı'];
    s.setColumnWidth(0, 24);
    s.setColumnWidth(1, 12);
    s.setColumnWidth(2, 18);

    _setText(s, 0, 0, 'Ortak', style: _headerStyle());
    _setText(s, 0, 1, 'Yüzde', style: _headerStyle());
    _setText(s, 0, 2, 'Pay', style: _headerStyle());

    if (r.shares.isEmpty) {
      _setText(s, 1, 0, 'Bu dükkan için ortak tanımlı değil');
      return;
    }

    for (var i = 0; i < r.shares.length; i++) {
      final share = r.shares[i];
      final row = i + 1;
      _setText(s, row, 0, share.partnerName);
      _setPercentage(s, row, 1, share.percentage);
      _setMoney(s, row, 2, share.amount);
    }

    // Toplam satırı
    final totalRow = r.shares.length + 1;
    _setText(s, totalRow, 0, 'Toplam', style: _boldStyle());
    _setPercentage(s, totalRow, 1, 100, bold: true);
    _setMoney(s, totalRow, 2, r.netProfit, bold: true);
  }

  static void _buildRevenueSheet(Excel excel, MonthlyReport r) {
    final s = excel['Günlük Ciro'];
    s.setColumnWidth(0, 14);
    s.setColumnWidth(1, 14);
    s.setColumnWidth(2, 14);
    s.setColumnWidth(3, 16);
    s.setColumnWidth(4, 30);

    _setText(s, 0, 0, 'Tarih', style: _headerStyle());
    _setText(s, 0, 1, 'Nakit', style: _headerStyle());
    _setText(s, 0, 2, 'Kart', style: _headerStyle());
    _setText(s, 0, 3, 'Toplam', style: _headerStyle());
    _setText(s, 0, 4, 'Not', style: _headerStyle());

    if (r.revenues.isEmpty) {
      _setText(s, 1, 0, 'Bu ay için ciro kaydı yok');
      return;
    }

    for (var i = 0; i < r.revenues.length; i++) {
      final rev = r.revenues[i];
      final row = i + 1;
      _setText(s, row, 0, _formatDate(rev.dateKey));
      _setMoney(s, row, 1, rev.cash);
      _setMoney(s, row, 2, rev.card);
      _setMoney(s, row, 3, rev.total, bold: true);
      if (rev.note != null && rev.note!.isNotEmpty) {
        _setText(s, row, 4, rev.note!);
      }
    }

    // Toplam satırı
    final totalRow = r.revenues.length + 1;
    _setText(s, totalRow, 0, 'Toplam', style: _boldStyle());
    _setMoney(s, totalRow, 1, r.totalCash, bold: true);
    _setMoney(s, totalRow, 2, r.totalCard, bold: true);
    _setMoney(s, totalRow, 3, r.totalRevenue, bold: true);
  }

  static void _buildExpenseSheet(Excel excel, MonthlyReport r) {
    final s = excel['Gider Detayı'];
    s.setColumnWidth(0, 14);
    s.setColumnWidth(1, 28);
    s.setColumnWidth(2, 16);
    s.setColumnWidth(3, 30);

    _setText(s, 0, 0, 'Tarih', style: _headerStyle());
    _setText(s, 0, 1, 'Açıklama', style: _headerStyle());
    _setText(s, 0, 2, 'Tutar', style: _headerStyle());
    _setText(s, 0, 3, 'Not', style: _headerStyle());

    if (r.expenses.isEmpty) {
      _setText(s, 1, 0, 'Bu ay için gider kaydı yok');
      return;
    }

    for (var i = 0; i < r.expenses.length; i++) {
      final exp = r.expenses[i];
      final row = i + 1;
      _setText(s, row, 0, _formatDate(exp.dateKey));
      _setText(s, row, 1, exp.name);
      _setMoney(s, row, 2, exp.amount);
      if (exp.note != null && exp.note!.isNotEmpty) {
        _setText(s, row, 3, exp.note!);
      }
    }

    final totalRow = r.expenses.length + 1;
    _setText(s, totalRow, 0, 'Toplam', style: _boldStyle());
    _setMoney(s, totalRow, 2, r.totalExpense, bold: true);
  }

  // ---------- helpers ----------

  static void _setText(
    Sheet s,
    int row,
    int col,
    String value, {
    CellStyle? style,
  }) {
    final cell = s.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row));
    cell.value = TextCellValue(value);
    if (style != null) cell.cellStyle = style;
  }

  static void _setMoney(
    Sheet s,
    int row,
    int col,
    double value, {
    bool bold = false,
  }) {
    final cell = s.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row));
    cell.value = DoubleCellValue(value);
    cell.cellStyle = CellStyle(
      bold: bold,
      numberFormat: NumFormat.custom(formatCode: '#,##0.00'),
      horizontalAlign: HorizontalAlign.Right,
    );
  }

  static void _setPercentage(
    Sheet s,
    int row,
    int col,
    double value, {
    bool bold = false,
  }) {
    final cell = s.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row));
    cell.value = DoubleCellValue(value);
    cell.cellStyle = CellStyle(
      bold: bold,
      numberFormat: NumFormat.custom(formatCode: '0.00"%"'),
      horizontalAlign: HorizontalAlign.Right,
    );
  }

  static CellStyle _titleStyle() => CellStyle(
        bold: true,
        fontSize: 16,
        horizontalAlign: HorizontalAlign.Left,
      );

  static CellStyle _sectionStyle() => CellStyle(
        bold: true,
        fontSize: 12,
        backgroundColorHex: ExcelColor.fromHexString('FFE7EEF7'),
      );

  static CellStyle _headerStyle() => CellStyle(
        bold: true,
        fontColorHex: ExcelColor.white,
        backgroundColorHex: ExcelColor.fromHexString('FF4472C4'),
        horizontalAlign: HorizontalAlign.Center,
      );

  static CellStyle _boldStyle() => CellStyle(bold: true);

  static String _formatDate(String dateKey) {
    try {
      final d = DateTime.parse(dateKey);
      return DateFormat('dd.MM.yyyy').format(d);
    } catch (_) {
      return dateKey;
    }
  }

  static String _sanitizeFileName(String name) {
    final cleaned = name
        .replaceAll(RegExp(r'[\\/:*?"<>|]'), '')
        .replaceAll(RegExp(r'\s+'), '_')
        .trim();
    return cleaned.isEmpty ? 'dukkan' : cleaned;
  }
}
