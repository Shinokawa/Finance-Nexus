import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/local/app_database.dart';
import '../../../providers/repository_providers.dart';

/// Provider for watching holdings in a specific portfolio
final portfolioHoldingsProvider = StreamProvider.family<List<Holding>, String>((ref, portfolioId) {
  final holdingRepository = ref.watch(holdingRepositoryProvider);
  return holdingRepository.watchHoldingsByPortfolio(portfolioId);
});

/// Provider for watching holdings in a specific account
final accountHoldingsProvider = StreamProvider.family<List<Holding>, String>((ref, accountId) {
  final holdingRepository = ref.watch(holdingRepositoryProvider);
  return holdingRepository.watchHoldingsByAccount(accountId);
});