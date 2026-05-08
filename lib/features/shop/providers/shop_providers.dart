import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/shop.dart';
import '../../auth/providers/auth_providers.dart';
import '../data/shop_repository.dart';

final shopRepositoryProvider = Provider<ShopRepository>(
  (ref) => ShopRepository(ref.watch(firestoreProvider)),
);

final allShopsProvider = StreamProvider<List<Shop>>((ref) {
  return ref.watch(shopRepositoryProvider).watchAll();
});

final shopByIdProvider = StreamProvider.family<Shop?, String>((ref, shopId) {
  return ref.watch(shopRepositoryProvider).watchOne(shopId);
});
