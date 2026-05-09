import 'package:flutter_test/flutter_test.dart';
import 'package:muasebe_takip/features/reports/logic/monthly_report_calculator.dart';
import 'package:muasebe_takip/models/employee.dart';
import 'package:muasebe_takip/models/employee_ledger_entry.dart';
import 'package:muasebe_takip/models/expense.dart';
import 'package:muasebe_takip/models/partner.dart';
import 'package:muasebe_takip/models/revenue.dart';
import 'package:muasebe_takip/models/shop.dart';

Shop _shopWith(List<Partner> partners) => Shop(
      id: 's1',
      name: 'Merkez',
      ownerId: 'u1',
      partners: partners,
    );

Revenue _rev(String date, double cash, double card) => Revenue(
      id: date,
      shopId: 's1',
      dateKey: date,
      cash: cash,
      card: card,
      createdBy: 'u1',
    );

Expense _exp(String date, double amount, [String name = 'gider']) => Expense(
      id: '$date-$name',
      shopId: 's1',
      dateKey: date,
      name: name,
      amount: amount,
      createdBy: 'u1',
    );

void main() {
  group('calculateMonthlyReport', () {
    test('iki ortak 50/50 — basit senaryo', () {
      final shop = _shopWith([
        const Partner(id: 'p1', name: 'Ahmet', percentage: 50),
        const Partner(id: 'p2', name: 'Mehmet', percentage: 50),
      ]);
      final revenues = [
        _rev('2026-05-01', 1000, 500),
        _rev('2026-05-15', 800, 700),
      ];
      final expenses = [
        _exp('2026-05-03', 1000, 'Kira'),
      ];

      final r = calculateMonthlyReport(
        shop: shop,
        revenues: revenues,
        expenses: expenses,
        year: 2026,
        month: 5,
      );

      expect(r.totalCash, 1800);
      expect(r.totalCard, 1200);
      expect(r.totalRevenue, 3000);
      expect(r.totalExpense, 1000);
      expect(r.netProfit, 2000);
      expect(r.shares.length, 2);
      expect(r.shares[0].amount, 1000);
      expect(r.shares[1].amount, 1000);
      expect(r.isLoss, false);
    });

    test('üç ortak 40/35/25 — kâr dağılımı', () {
      final shop = _shopWith([
        const Partner(id: 'p1', name: 'A', percentage: 40),
        const Partner(id: 'p2', name: 'B', percentage: 35),
        const Partner(id: 'p3', name: 'C', percentage: 25),
      ]);
      final revenues = [_rev('2026-05-01', 5000, 5000)];
      final expenses = [_exp('2026-05-10', 2000)];

      final r = calculateMonthlyReport(
        shop: shop,
        revenues: revenues,
        expenses: expenses,
        year: 2026,
        month: 5,
      );

      expect(r.netProfit, 8000);
      expect(r.shares[0].amount, 3200);
      expect(r.shares[1].amount, 2800);
      expect(r.shares[2].amount, 2000);
    });

    test('zarar senaryosu — payların negatif olması', () {
      final shop = _shopWith([
        const Partner(id: 'p1', name: 'A', percentage: 50),
        const Partner(id: 'p2', name: 'B', percentage: 50),
      ]);
      final revenues = [_rev('2026-05-01', 500, 0)];
      final expenses = [_exp('2026-05-01', 1500)];

      final r = calculateMonthlyReport(
        shop: shop,
        revenues: revenues,
        expenses: expenses,
        year: 2026,
        month: 5,
      );

      expect(r.netProfit, -1000);
      expect(r.isLoss, true);
      expect(r.shares[0].amount, -500);
      expect(r.shares[1].amount, -500);
    });

    test('ay filtresi — diğer aylar dışlanır', () {
      final shop = _shopWith([
        const Partner(id: 'p1', name: 'A', percentage: 100),
      ]);
      final revenues = [
        _rev('2026-04-30', 999, 0), // önceki ay
        _rev('2026-05-01', 1000, 0), // hedef
        _rev('2026-05-31', 2000, 0), // hedef
        _rev('2026-06-01', 999, 0), // sonraki ay
      ];
      final expenses = [
        _exp('2026-04-15', 5000, 'eski'), // dışarıda
        _exp('2026-05-10', 500, 'mayıs'),
      ];

      final r = calculateMonthlyReport(
        shop: shop,
        revenues: revenues,
        expenses: expenses,
        year: 2026,
        month: 5,
      );

      expect(r.totalRevenue, 3000);
      expect(r.totalExpense, 500);
      expect(r.netProfit, 2500);
      expect(r.revenues.length, 2);
      expect(r.expenses.length, 1);
    });

    test('boş veri — sıfır net kâr, paylar 0', () {
      final shop = _shopWith([
        const Partner(id: 'p1', name: 'A', percentage: 100),
      ]);
      final r = calculateMonthlyReport(
        shop: shop,
        revenues: const [],
        expenses: const [],
        year: 2026,
        month: 5,
      );

      expect(r.totalRevenue, 0);
      expect(r.totalExpense, 0);
      expect(r.netProfit, 0);
      expect(r.shares.first.amount, 0);
      expect(r.isEmpty, true);
    });

    test('ortak yoksa shares boş, ama ciro/gider hesaplanır', () {
      final shop = _shopWith(const []);
      final revenues = [_rev('2026-05-01', 1000, 0)];

      final r = calculateMonthlyReport(
        shop: shop,
        revenues: revenues,
        expenses: const [],
        year: 2026,
        month: 5,
      );

      expect(r.totalRevenue, 1000);
      expect(r.netProfit, 1000);
      expect(r.shares, isEmpty);
    });

    test('geçersiz dateKey formatı dışlanır', () {
      final shop = _shopWith([
        const Partner(id: 'p1', name: 'A', percentage: 100),
      ]);
      final revenues = [
        _rev('2026-05-01', 500, 0),
        _rev('bozuk', 9999, 0),
        _rev('', 8888, 0),
      ];

      final r = calculateMonthlyReport(
        shop: shop,
        revenues: revenues,
        expenses: const [],
        year: 2026,
        month: 5,
      );

      expect(r.totalRevenue, 500);
      expect(r.revenues.length, 1);
    });

    test('ortak personelin borcu paydan düşülür', () {
      final shop = _shopWith([
        const Partner(id: 'p1', name: 'Ahmet', percentage: 50),
        const Partner(id: 'p2', name: 'Mehmet', percentage: 50),
      ]);
      final revenues = [_rev('2026-05-01', 5000, 5000)];
      final expenses = [_exp('2026-05-10', 2000)];

      final empA = Employee(
        id: 'e1',
        shopId: 's1',
        name: 'Ahmet',
        phone: '',
        startDate: DateTime(2026, 1, 1),
        createdBy: 'u1',
        partnerId: 'p1',
      );

      final ledgers = {
        'e1': [
          EmployeeLedgerEntry(
            id: 'l1',
            shopId: 's1',
            employeeId: 'e1',
            type: LedgerEntryType.borc,
            amount: 1000,
            dateKey: '2026-05-05',
            date: DateTime(2026, 5, 5),
            createdBy: 'u1',
          ),
          EmployeeLedgerEntry(
            id: 'l2',
            shopId: 's1',
            employeeId: 'e1',
            type: LedgerEntryType.avans,
            amount: 500,
            dateKey: '2026-05-20',
            date: DateTime(2026, 5, 20),
            createdBy: 'u1',
          ),
          EmployeeLedgerEntry(
            id: 'l3',
            shopId: 's1',
            employeeId: 'e1',
            type: LedgerEntryType.odeme,
            amount: 200,
            dateKey: '2026-05-25',
            date: DateTime(2026, 5, 25),
            createdBy: 'u1',
          ),
        ],
      };

      final r = calculateMonthlyReport(
        shop: shop,
        revenues: revenues,
        expenses: expenses,
        year: 2026,
        month: 5,
        employees: [empA],
        ledgersByEmployee: ledgers,
      );

      // netProfit = 8000, her ortağın payı = 4000
      expect(r.netProfit, 8000);
      expect(r.shares[0].amount, 4000);
      // Ahmet'in net borcu: 1000 + 500 - 200 = 1300
      expect(r.shares[0].deductions, 1300);
      expect(r.shares[0].netAmount, 2700);
      // Mehmet'in personeli yok
      expect(r.shares[1].deductions, 0);
      expect(r.shares[1].netAmount, 4000);
    });

    test('ay sonundan sonraki hareketler kesintiye girmez', () {
      final shop = _shopWith([
        const Partner(id: 'p1', name: 'A', percentage: 100),
      ]);
      final revenues = [_rev('2026-05-01', 1000, 0)];

      final emp = Employee(
        id: 'e1',
        shopId: 's1',
        name: 'A',
        phone: '',
        startDate: DateTime(2026, 1, 1),
        createdBy: 'u1',
        partnerId: 'p1',
      );

      final ledgers = {
        'e1': [
          EmployeeLedgerEntry(
            id: 'l1',
            shopId: 's1',
            employeeId: 'e1',
            type: LedgerEntryType.borc,
            amount: 300,
            dateKey: '2026-05-31',
            date: DateTime(2026, 5, 31),
            createdBy: 'u1',
          ),
          EmployeeLedgerEntry(
            id: 'l2',
            shopId: 's1',
            employeeId: 'e1',
            type: LedgerEntryType.borc,
            amount: 700,
            dateKey: '2026-06-01',
            date: DateTime(2026, 6, 1),
            createdBy: 'u1',
          ),
        ],
      };

      final r = calculateMonthlyReport(
        shop: shop,
        revenues: revenues,
        expenses: const [],
        year: 2026,
        month: 5,
        employees: [emp],
        ledgersByEmployee: ledgers,
      );

      // Sadece Mayıs içindeki 300 sayılır
      expect(r.shares[0].deductions, 300);
      expect(r.shares[0].netAmount, 700);
    });

    test('fazla ödeme (negatif bakiye) kesinti olmaz', () {
      final shop = _shopWith([
        const Partner(id: 'p1', name: 'A', percentage: 100),
      ]);
      final revenues = [_rev('2026-05-01', 1000, 0)];

      final emp = Employee(
        id: 'e1',
        shopId: 's1',
        name: 'A',
        phone: '',
        startDate: DateTime(2026, 1, 1),
        createdBy: 'u1',
        partnerId: 'p1',
      );

      // Ödeme borçtan fazla → bakiye negatif (firma personele borçlu).
      // Bu durumda kesinti uygulanmaz; pay aynen kalır.
      final ledgers = {
        'e1': [
          EmployeeLedgerEntry(
            id: 'l1',
            shopId: 's1',
            employeeId: 'e1',
            type: LedgerEntryType.borc,
            amount: 300,
            dateKey: '2026-05-05',
            date: DateTime(2026, 5, 5),
            createdBy: 'u1',
          ),
          EmployeeLedgerEntry(
            id: 'l2',
            shopId: 's1',
            employeeId: 'e1',
            type: LedgerEntryType.odeme,
            amount: 500,
            dateKey: '2026-05-10',
            date: DateTime(2026, 5, 10),
            createdBy: 'u1',
          ),
        ],
      };

      final r = calculateMonthlyReport(
        shop: shop,
        revenues: revenues,
        expenses: const [],
        year: 2026,
        month: 5,
        employees: [emp],
        ledgersByEmployee: ledgers,
      );

      expect(r.shares[0].deductions, 0);
      expect(r.shares[0].netAmount, 1000);
    });

    test('revenues sıralaması tarih artan olmalı', () {
      final shop = _shopWith([
        const Partner(id: 'p1', name: 'A', percentage: 100),
      ]);
      final revenues = [
        _rev('2026-05-15', 100, 0),
        _rev('2026-05-01', 100, 0),
        _rev('2026-05-10', 100, 0),
      ];

      final r = calculateMonthlyReport(
        shop: shop,
        revenues: revenues,
        expenses: const [],
        year: 2026,
        month: 5,
      );

      expect(r.revenues.map((e) => e.dateKey).toList(), [
        '2026-05-01',
        '2026-05-10',
        '2026-05-15',
      ]);
    });
  });
}
