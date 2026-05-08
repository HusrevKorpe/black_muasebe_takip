# Ortaklık Sistemi + Excel Raporu Planı

**Hedef:** Firebase'den çıkmadan, mevcut yapıya:
1. **Ortaklık sistemi** — Her dükkana ortaklar ve yüzdelik payları
2. **Aylık kâr dağılım hesabı** — Ciro - gider = net kâr → ortaklara böl
3. **Excel raporu** — Aylık raporu `.xlsx` olarak dışa aktar

**Backend gerektirmez. Tüm hesaplama client-side. Firebase rahat kaldırır.**

---

## 1. Veri Modeli Değişiklikleri

### 1.1 Shop modeline `partners` alanı

**Karar:** Ortakları ayrı subcollection yerine `Shop` dokümanına gömülü liste olarak tut.
- Sebep: Dükkan başına max 5-10 ortak. Subcollection fazla karmaşıklık.
- Avantaj: Tek okumayla tüm ortaklar gelir, yüzde toplamı %100 mü kontrolü kolay.

**Yeni `Shop` yapısı:**
```dart
class Shop {
  final String id;
  final String name;
  final String ownerId;
  final DateTime? createdAt;
  final List<Partner> partners;  // YENİ
}

class Partner {
  final String id;          // uuid (Firestore tarafında üretilen)
  final String name;        // "Ahmet Yılmaz"
  final double percentage;  // 0-100 arası
  final String? note;       // opsiyonel: "kurucu ortak", "sessiz ortak" vb.
}
```

**Firestore şeması:**
```
shops/{shopId}
  - name: "Merkez Şube"
  - ownerId: "..."
  - createdAt: ...
  - partners: [
      { id: "p1", name: "Ahmet", percentage: 40, note: "kurucu" },
      { id: "p2", name: "Mehmet", percentage: 35, note: null },
      { id: "p3", name: "Ali", percentage: 25, note: null }
    ]
```

**Doğrulama kuralı:**
- Yüzdelerin toplamı = 100 olmalı (UI'da uyarı, kayıt sırasında validate)
- En az 1 ortak (genelde dükkan sahibi tek ortak olabilir → %100)

### 1.2 Migration / mevcut dükkanlar

Mevcut dükkanlarda `partners` alanı yok. Çözüm:
- `Shop.fromDoc` içinde `partners` null/eksikse boş liste dön
- UI: Ortak yoksa "Ortak ekleyin" uyarısı göster, rapor üretmeyi engelle

---

## 2. UI Eklemeleri

### 2.1 Ortaklık yönetim ekranı

**Yeni dosya:** `lib/features/shop/presentation/shop_partners_screen.dart`

**İşlevler:**
- Ortak listesini göster (isim + yüzde + not)
- Ortak ekle / sil / düzenle (bottom sheet)
- Yüzde toplamı %100 değilse kırmızı uyarı + kaydetme butonu pasif
- "Eşit böl" butonu (3 ortak varsa otomatik %33.33 / %33.33 / %33.34)

**Erişim:** Sadece `boss` rolü. `owner` görüntüleyebilir ama düzenleyemez.

**Navigasyon:** `boss_home_screen` → dükkan detayında "Ortakları Yönet" butonu.

### 2.2 Aylık rapor ekranı

**Yeni dosya:** `lib/features/reports/presentation/monthly_report_screen.dart`

**İçerik:**
- Ay seçici (önceki/sonraki ay)
- Dükkan seçici (tek dükkan veya "Tüm dükkanlar")
- Özet kart:
  - Toplam ciro (nakit + kart ayrı)
  - Toplam gider
  - Net kâr
- Ortaklık tablosu:
  | Ortak | Yüzde | Pay |
  |-------|-------|-----|
  | Ahmet | %40 | 12.000 ₺ |
  | Mehmet | %35 | 10.500 ₺ |
  | Ali | %25 | 7.500 ₺ |
- "Excel olarak indir" butonu (sağ üst)
- "Paylaş" butonu (WhatsApp, mail vb.)

**Erişim:** Sadece `boss`. Owner'lar yalnız kendi dükkanını görür.

---

## 3. Hesaplama Mantığı

**Yeni dosya:** `lib/features/reports/logic/monthly_report_calculator.dart`

```dart
class MonthlyReport {
  final String shopId;
  final String shopName;
  final int year;
  final int month;
  final double totalCash;
  final double totalCard;
  final double totalRevenue;     // cash + card
  final double totalExpense;
  final double netProfit;        // revenue - expense
  final List<PartnerShare> shares;
}

class PartnerShare {
  final String partnerName;
  final double percentage;
  final double amount;           // netProfit * percentage / 100
}

MonthlyReport calculateMonthlyReport({
  required Shop shop,
  required List<Revenue> revenues,
  required List<Expense> expenses,
  required int year,
  required int month,
}) {
  final monthRevenues = revenues.where((r) =>
      _isInMonth(r.dateKey, year, month)).toList();
  final monthExpenses = expenses.where((e) =>
      _isInMonth(e.dateKey, year, month)).toList();

  final totalCash = monthRevenues.fold(0.0, (s, r) => s + r.cash);
  final totalCard = monthRevenues.fold(0.0, (s, r) => s + r.card);
  final totalRevenue = totalCash + totalCard;
  final totalExpense = monthExpenses.fold(0.0, (s, e) => s + e.amount);
  final netProfit = totalRevenue - totalExpense;

  final shares = shop.partners.map((p) => PartnerShare(
    partnerName: p.name,
    percentage: p.percentage,
    amount: netProfit * (p.percentage / 100),
  )).toList();

  return MonthlyReport(...);
}
```

**Önemli detay:** `dateKey` formatı `YYYY-MM-DD` olmalı (mevcut kodda öyle). `_isInMonth` bunu parse eder.

**Negatif kâr senaryosu:** Net kâr negatifse (zarar), her ortağın payı da negatif olur. UI'da "Bu ay zararda" şeklinde göster.

---

## 4. Excel Export

### 4.1 Paket seçimi

**`excel: ^4.0.6`** paketini kullanacağız.
- Pure Dart, ücretsiz, harici bağımlılık yok
- `.xlsx` üretir, çoğu görsel formatlamayı destekler
- iOS'ta sorunsuz çalışır

**`share_plus: ^10.0.0`** dosya paylaşımı için.
**`path_provider: ^2.1.4`** geçici dosya yolu için.

`pubspec.yaml`'a eklenecek:
```yaml
dependencies:
  excel: ^4.0.6
  share_plus: ^10.0.0
  path_provider: ^2.1.4
```

### 4.2 Excel servisi

**Yeni dosya:** `lib/features/reports/services/excel_export_service.dart`

**İşlevler:**
- `Future<File> generateMonthlyReportExcel(MonthlyReport report)` — dosya üretir
- `Future<void> shareReport(File file)` — `share_plus` ile paylaş

**Excel sayfa yapısı:**

**Sayfa 1: "Özet"**
| | A | B |
|---|---|---|
| 1 | **Aylık Rapor** | |
| 2 | Dükkan | Merkez Şube |
| 3 | Ay | 2026 Mayıs |
| 4 | | |
| 5 | **Gelir** | |
| 6 | Toplam Nakit | 18.500 ₺ |
| 7 | Toplam Kart | 14.000 ₺ |
| 8 | Toplam Ciro | 32.500 ₺ |
| 9 | | |
| 10 | **Gider** | |
| 11 | Toplam Gider | 12.500 ₺ |
| 12 | | |
| 13 | **Net Kâr** | 20.000 ₺ |

**Sayfa 2: "Ortaklık Dağılımı"**
| | A | B | C |
|---|---|---|---|
| 1 | Ortak | Yüzde | Pay |
| 2 | Ahmet | %40 | 8.000 ₺ |
| 3 | Mehmet | %35 | 7.000 ₺ |
| 4 | Ali | %25 | 5.000 ₺ |

**Sayfa 3: "Günlük Ciro Detayı"**
| Tarih | Nakit | Kart | Toplam | Not |
|-------|-------|------|--------|-----|
| 01.05.2026 | 800 | 600 | 1.400 | - |
| 02.05.2026 | 1.200 | 400 | 1.600 | - |
| ... | ... | ... | ... | ... |

**Sayfa 4: "Gider Detayı"**
| Tarih | Açıklama | Tutar |
|-------|----------|-------|
| 03.05.2026 | Kira | 8.000 |
| 10.05.2026 | Elektrik | 1.500 |

**Formatlama:**
- Başlıklar bold + arka plan rengi
- Para hücreleri: `#,##0.00` formatı (₺ sembolü yok, sade rakam)
- Tarih hücreleri: `dd.MM.yyyy`
- Sütun genişlikleri otomatik ayarlı, okunabilir

### 4.3 Dosya isimlendirme

`Muasebe_MerkezSube_2026-05.xlsx` formatında.

---

## 5. Implementasyon Sıralaması

Her adım sonunda **dur, kullanıcıyla test**.

### Adım 1: Ortaklık modeli (Backend olmadan veri katmanı)
- [ ] `Partner` modelini oluştur (`lib/models/partner.dart`)
- [ ] `Shop` modelini güncelle, `partners` alanı ekle
- [ ] `ShopRepository`'ye `updatePartners` metodu ekle
- [ ] **Test:** Firestore Console'dan manuel ortak ekle, app okuyor mu?

### Adım 2: Ortaklık yönetim ekranı UI
- [ ] `shop_partners_screen.dart` ekranını yaz
- [ ] Ekleme/silme/düzenleme bottom sheet
- [ ] Yüzde toplam validasyonu
- [ ] `boss_home_screen`'e "Ortakları Yönet" butonu
- [ ] **Test:** UI'dan 3 ortak ekle, %100 olmazsa kayıt engelleniyor mu?

### Adım 3: Aylık rapor hesaplaması
- [ ] `monthly_report_calculator.dart` mantığını yaz
- [ ] Unit test (örnek veri ile)
- [ ] **Test:** Bilinen sayılarla doğrulama

### Adım 4: Aylık rapor ekranı UI
- [ ] `monthly_report_screen.dart` ekranını yaz
- [ ] Ay seçici, dükkan seçici
- [ ] Özet kart + ortaklık tablosu
- [ ] **Test:** Gerçek verilerle hesap doğru mu?

### Adım 5: Excel export
- [ ] `pubspec.yaml`'a paketleri ekle, `flutter pub get`
- [ ] `excel_export_service.dart` servisini yaz
- [ ] Rapor ekranına "Excel İndir" butonu
- [ ] **Test:** iOS cihazda dosya üretiliyor + paylaşılıyor mu?

### Adım 6: Cila
- [ ] Negatif kâr (zarar) senaryosu UI'da düzgün gösterimi
- [ ] Yükleniyor/hata durumları
- [ ] Boş veri durumu (o ay hiç ciro yok)
- [ ] Excel'de Türkçe karakter testi

---

## 6. Firestore Rules Güncellemeleri

`firestore.rules` içinde `partners` alanı yazma izni:
- Sadece `boss` rolü `partners` alanını güncelleyebilir
- `owner` rolü kendi dükkanının `partners` alanını sadece okuyabilir

---

## 7. Kararlar (Onaylandı)

1. **Çalışan maaşı:** Maaşlar normal gider olarak `Expense` koleksiyonuna girilecek. `Employee` modeline maaş alanı eklenmeyecek, hesaplamada özel davranış yok.
2. **Vergi:** Düşülmeyecek. Net kâr = ciro − gider (vergi yok, brüt mantığı).
3. **Ortaklık geçmişi:** Şu anki yüzdeler kullanılacak. Geçmiş ay raporları da güncel ortaklık yüzdeleriyle hesaplanır. (Snapshot/tarihçe yok — basit kalsın.)
4. **Para birimi:** Excel'de ₺ sembolü yok. Sadece düzgün biçimlendirilmiş rakam: `12.500,00`. Okunabilirlik için sütun genişlikleri ayarlı.

---

## 8. Toplam Tahmini Süre

- Adım 1-2 (Ortaklık altyapı + UI): ~4-6 saat
- Adım 3-4 (Hesaplama + rapor ekranı): ~3-4 saat
- Adım 5 (Excel): ~2-3 saat
- Adım 6 (Cila + test): ~2 saat

**Toplam: ~12-15 saat. 2-3 günde tamamlanır.**

---

## 9. Backend Yazma İhtiyacı?

**Yok.** Yukarıdaki tüm özellikler Firebase + Flutter ile çalışır. Aylık 10-15 dükkan, ~500 ciro girişi senaryosunda Firestore ücretsiz katmanın %1'inden azını kullanır. Backend yazma kararı, ancak şunlar gerçekleşirse anlamlı olur:

- Aylık 100.000+ veri girişi
- Karmaşık SQL-tipi raporlar (cross-shop join, trend analizi)
- Üçüncü parti entegrasyon (e-fatura, banka API'si)

Şu anki ihtiyaçların hiçbiri bu sınırlara yakın değil.
