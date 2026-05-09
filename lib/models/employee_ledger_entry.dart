import 'package:cloud_firestore/cloud_firestore.dart';

enum LedgerEntryType { avans, borc, odeme }

extension LedgerEntryTypeX on LedgerEntryType {
  String get wireValue => switch (this) {
        LedgerEntryType.avans => 'avans',
        LedgerEntryType.borc => 'borc',
        LedgerEntryType.odeme => 'odeme',
      };

  String get label => switch (this) {
        LedgerEntryType.avans => 'Avans',
        LedgerEntryType.borc => 'Borç',
        LedgerEntryType.odeme => 'Ödeme',
      };

  /// Bakiyeye katkısı: avans/borç pozitif (personel firmaya borçlanır),
  /// ödeme negatif (borç kapanır).
  int get sign => switch (this) {
        LedgerEntryType.avans => 1,
        LedgerEntryType.borc => 1,
        LedgerEntryType.odeme => -1,
      };

  static LedgerEntryType fromWire(String? raw) {
    return switch (raw) {
      'avans' => LedgerEntryType.avans,
      'odeme' => LedgerEntryType.odeme,
      _ => LedgerEntryType.borc,
    };
  }
}

class EmployeeLedgerEntry {
  final String id;
  final String shopId;
  final String employeeId;
  final LedgerEntryType type;
  final double amount;
  final String dateKey;
  final DateTime date;
  final String? note;
  final String createdBy;
  final DateTime? createdAt;

  const EmployeeLedgerEntry({
    required this.id,
    required this.shopId,
    required this.employeeId,
    required this.type,
    required this.amount,
    required this.dateKey,
    required this.date,
    required this.createdBy,
    this.note,
    this.createdAt,
  });

  double get signedAmount => amount * type.sign;

  factory EmployeeLedgerEntry.fromDoc(
    String shopId,
    String employeeId,
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? {};
    final ts = data['date'];
    final date = ts is Timestamp
        ? ts.toDate()
        : (ts is String
            ? DateTime.tryParse(ts) ?? DateTime.now()
            : DateTime.now());
    return EmployeeLedgerEntry(
      id: doc.id,
      shopId: shopId,
      employeeId: employeeId,
      type: LedgerEntryTypeX.fromWire(data['type'] as String?),
      amount: (data['amount'] as num?)?.toDouble() ?? 0,
      dateKey: data['dateKey'] as String? ?? '',
      date: date,
      note: data['note'] as String?,
      createdBy: data['createdBy'] as String? ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toCreateMap() => {
        'type': type.wireValue,
        'amount': amount,
        'date': Timestamp.fromDate(date),
        'dateKey': dateKey,
        if (note != null && note!.isNotEmpty) 'note': note,
        'createdBy': createdBy,
        'createdAt': FieldValue.serverTimestamp(),
      };
}
