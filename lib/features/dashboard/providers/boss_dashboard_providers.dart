import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/date_keys.dart';
import '../../../models/revenue.dart';
import '../../revenue/providers/revenue_providers.dart';

/// Boss dashboard'ında bir dükkanın bugünkü cirosu için kullanılan provider.
/// Her dükkan satırı bunu kendi shopId'siyle izler — Riverpod cache'leri otomatik yönetir.
final shopTodayRevenueProvider =
    StreamProvider.family<Revenue?, String>((ref, shopId) {
  return ref.watch(revenueRepositoryProvider).watchByDate(
        shopId: shopId,
        date: DateKeys.today(),
      );
});
